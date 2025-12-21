#ifndef THUMBNAIL_PLUGIN_H_
#define THUMBNAIL_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <vector>

class ThumbnailPlugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  ThumbnailPlugin();
  virtual ~ThumbnailPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::vector<uint8_t> GetThumbnail(const std::wstring& file_path, int thumbnail_size);
};

#endif  // THUMBNAIL_PLUGIN_H_
