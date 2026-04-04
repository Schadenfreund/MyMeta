import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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
      // Get FFmpeg path (cached static from CoreBackend)
      final ffmpegPath = _getFFmpegPath();
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

  /// Get FFmpeg path from UserData/tools, bundled location, or system PATH
  /// Returns null if FFmpeg is not available
  static String? _getFFmpegPath() {
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);

      // Check UserData/tools/ffmpeg (portable location)
      for (final sub in ['bin/ffmpeg.exe', 'ffmpeg.exe']) {
        final toolPath = p.join(exeDir, 'UserData', 'tools', 'ffmpeg', sub);
        if (File(toolPath).existsSync()) return toolPath;
      }

      // Check bundled FFmpeg (app directory)
      final bundledFfmpeg = p.join(exeDir, 'ffmpeg.exe');
      if (File(bundledFfmpeg).existsSync()) return bundledFfmpeg;

      // Check PATH
      final pathResult = Process.runSync('where', ['ffmpeg.exe']);
      if (pathResult.exitCode == 0) {
        final pathOutput = pathResult.stdout.toString().trim();
        if (pathOutput.isNotEmpty) {
          return pathOutput.split('\n').first;
        }
      }

      return null;
    } catch (e) {
      debugPrint('⚠️  ImageUtils: Error locating FFmpeg: $e');
      return null;
    }
  }
}
