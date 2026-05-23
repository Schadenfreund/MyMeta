import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/tool_resolver.dart';

/// Image processing utilities using FFmpeg
class ImageUtils {
  /// Resize poster to max 512px using FFmpeg in one pass
  /// Preserves aspect ratio, never upscales
  /// Returns true if successful, false otherwise
  static Future<bool> resizePosterWithFFmpeg(
    String inputPath,
    String outputPath,
    int maxDimension,
  ) async {
    if (!File(inputPath).existsSync()) {
      debugPrint('❌ ImageUtils: Input file not found: $inputPath');
      return false;
    }

    try {
      final ffmpegPath = await ToolResolver.resolveExe(
        'ffmpeg',
        usePathFallback: true,
      );
      if (ffmpegPath == null || ffmpegPath.isEmpty) {
        debugPrint('❌ ImageUtils: FFmpeg not available');
        return false;
      }

      // Build scale filter: preserves aspect ratio, no upscaling
      // if(gt(iw,ih),min(512,iw),-2) - width: take min of 512 and actual width, -2 means calculate from height
      // if(gt(iw,ih),-2,min(512,ih)) - height: calculate from width, or min of 512 and actual height
      final scaleFilter = "scale='if(gt(iw,ih),min($maxDimension,iw),-2)':'if(gt(iw,ih),-2,min($maxDimension,ih))'";

      final args = [
        '-i',
        inputPath,
        '-vf',
        scaleFilter,
        '-q:v',
        '2', // High quality JPEG
        '-y', // Overwrite output
        outputPath,
      ];

      debugPrint('⏳ ImageUtils: Resizing with filter: $scaleFilter');
      final result = await Process.run(ffmpegPath, args, runInShell: false);

      if (result.exitCode == 0 && File(outputPath).existsSync()) {
        final inputSize = File(inputPath).lengthSync();
        final outputSize = File(outputPath).lengthSync();
        final reduction = ((1 - outputSize / inputSize) * 100).toStringAsFixed(1);
        debugPrint('✅ ImageUtils: Resized successfully ($reduction% smaller)');
        return true;
      } else {
        debugPrint('❌ ImageUtils: FFmpeg resize failed: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ ImageUtils: Exception during resize: $e');
      return false;
    }
  }

}
