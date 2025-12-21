import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Windows Shell thumbnail extractor using platform channel
/// This uses Windows' built-in thumbnail cache - same as Explorer
class WindowsThumbnail {
  static const platform = MethodChannel('com.mymeta/thumbnail');

  /// Get thumbnail from Windows Shell (instant - uses Windows cache)
  static Future<Uint8List?> getThumbnail(String filePath, {int size = 256}) async {
    try {
      final result = await platform.invokeMethod('getThumbnail', {
        'path': filePath,
        'size': size,
      });

      if (result != null && result is Uint8List) {
        return result;
      }
      return null;
    } catch (e) {
      print('Windows thumbnail failed: $e');
      return null;
    }
  }
}
