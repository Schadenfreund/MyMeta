#include "thumbnail_plugin.h"

#include <windows.h>
#include <shobjidl.h>
#include <gdiplus.h>
#include <atlbase.h>
#include <memory>
#include <vector>

#pragma comment(lib, "gdiplus.lib")

using namespace Gdiplus;

void ThumbnailPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  // Use static storage to keep plugin and channel alive for app lifetime
  static auto plugin = std::make_unique<ThumbnailPlugin>();
  static auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.mymeta/thumbnail",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        plugin->HandleMethodCall(call, std::move(result));
      });
}

ThumbnailPlugin::ThumbnailPlugin() {
  // Initialize GDI+ for image encoding
  GdiplusStartupInput gdiplusStartupInput;
  ULONG_PTR gdiplusToken;
  GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
}

ThumbnailPlugin::~ThumbnailPlugin() {}

void ThumbnailPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "getThumbnail") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGS", "Arguments must be a map");
      return;
    }

    auto path_it = arguments->find(flutter::EncodableValue("path"));
    auto size_it = arguments->find(flutter::EncodableValue("size"));

    if (path_it == arguments->end() || size_it == arguments->end()) {
      result->Error("INVALID_ARGS", "Missing path or size argument");
      return;
    }

    std::string path_str = std::get<std::string>(path_it->second);
    int size = std::get<int>(size_it->second);

    // Convert UTF-8 path to wide string
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, path_str.c_str(), -1, NULL, 0);
    std::wstring path_wide(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, path_str.c_str(), -1, &path_wide[0], size_needed);

    auto thumbnail_data = GetThumbnail(path_wide, size);

    if (!thumbnail_data.empty()) {
      result->Success(flutter::EncodableValue(thumbnail_data));
    } else {
      result->Error("EXTRACTION_FAILED", "Failed to extract thumbnail");
    }
  } else {
    result->NotImplemented();
  }
}

std::vector<uint8_t> ThumbnailPlugin::GetThumbnail(const std::wstring& file_path, int thumbnail_size) {
  std::vector<uint8_t> result;

  CoInitialize(NULL);

  // Create IShellItem from path
  CComPtr<IShellItem> pShellItem;
  HRESULT hr = SHCreateItemFromParsingName(file_path.c_str(), NULL, IID_PPV_ARGS(&pShellItem));
  if (FAILED(hr)) {
    CoUninitialize();
    return result;
  }

  // Get IShellItemImageFactory interface
  CComPtr<IShellItemImageFactory> pImageFactory;
  hr = pShellItem->QueryInterface(IID_PPV_ARGS(&pImageFactory));
  if (FAILED(hr)) {
    CoUninitialize();
    return result;
  }

  // Request thumbnail - this uses Windows thumbnail cache (instant!)
  SIZE thumbnailSize = {thumbnail_size, thumbnail_size};
  HBITMAP hBitmap = NULL;
  hr = pImageFactory->GetImage(thumbnailSize, SIIGBF_THUMBNAILONLY, &hBitmap);

  if (FAILED(hr)) {
    CoUninitialize();
    return result;
  }

  // Convert HBITMAP to JPEG bytes using GDI+
  Bitmap* bitmap = Bitmap::FromHBITMAP(hBitmap, NULL);
  if (bitmap) {
    // Create memory stream
    IStream* stream = NULL;
    CreateStreamOnHGlobal(NULL, TRUE, &stream);

    // Get JPEG encoder CLSID
    CLSID jpegClsid;
    UINT num = 0, size = 0;
    GetImageEncodersSize(&num, &size);
    ImageCodecInfo* pImageCodecInfo = (ImageCodecInfo*)(malloc(size));
    GetImageEncoders(num, size, pImageCodecInfo);

    for (UINT j = 0; j < num; ++j) {
      if (wcscmp(pImageCodecInfo[j].MimeType, L"image/jpeg") == 0) {
        jpegClsid = pImageCodecInfo[j].Clsid;
        break;
      }
    }
    free(pImageCodecInfo);

    // Save bitmap to stream as JPEG
    bitmap->Save(stream, &jpegClsid, NULL);

    // Read stream to vector
    STATSTG statstg;
    stream->Stat(&statstg, STATFLAG_DEFAULT);
    ULONG bytesRead;
    result.resize(statstg.cbSize.LowPart);

    LARGE_INTEGER liZero = {0};
    stream->Seek(liZero, STREAM_SEEK_SET, NULL);
    stream->Read(result.data(), statstg.cbSize.LowPart, &bytesRead);

    stream->Release();
    delete bitmap;
  }

  DeleteObject(hBitmap);
  CoUninitialize();

  return result;
}
