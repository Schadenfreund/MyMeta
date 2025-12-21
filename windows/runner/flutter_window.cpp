#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <shobjidl.h>
#include <gdiplus.h>
#include <atlbase.h>

#include "flutter/generated_plugin_registrant.h"

#pragma comment(lib, "gdiplus.lib")

using namespace Gdiplus;

// GDI+ token for cleanup
static ULONG_PTR gdiplusToken = 0;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  if (gdiplusToken != 0) {
    GdiplusShutdown(gdiplusToken);
  }
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  // Initialize GDI+ for image encoding
  GdiplusStartupInput gdiplusStartupInput;
  GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Create thumbnail method channel
  thumbnail_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.mymeta/thumbnail",
      &flutter::StandardMethodCodec::GetInstance());

  // Set up method call handler
  auto channel_ptr = thumbnail_channel_.get();
  thumbnail_channel_->SetMethodCallHandler(
      [this, channel_ptr](const auto& call, auto result) {
        if (call.method_name() == "getThumbnail") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
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

          auto thumbnail_data = GetWindowsThumbnail(path_wide, size);

          if (!thumbnail_data.empty()) {
            result->Success(flutter::EncodableValue(thumbnail_data));
          } else {
            result->Error("EXTRACTION_FAILED", "Failed to extract thumbnail");
          }
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

std::vector<uint8_t> FlutterWindow::GetWindowsThumbnail(const std::wstring& file_path, int thumbnail_size) {
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
