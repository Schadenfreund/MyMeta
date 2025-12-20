import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/settings_service.dart';

/// Helper class for extracting cover art from media files
class CoverExtractor {
  /// Extract cover art as bytes with multiple fallback methods
  static Future<Uint8List?> extractCoverBytes(
    String filePath, {
    SettingsService? settings,
  }) async {
    String? ffmpegPath = await _getFFmpegPath(settings);
    if (ffmpegPath == null) {
      print('⚠️  FFmpeg not available for cover extraction');
      return null;
    }

    // Try multiple methods in order of preference
    Uint8List? bytes;

    // Method 1: Extract attached picture (best quality, common in MKV)
    bytes = await _tryExtractAttachment(ffmpegPath, filePath);
    if (bytes != null) return bytes;

    // Method 2: Extract from last video stream (often attached pics)
    bytes = await _tryExtractLastVideoStream(ffmpegPath, filePath);
    if (bytes != null) return bytes;

    // Method 3: Extract first frame of main video (fallback)
    bytes = await _tryExtractFirstFrame(ffmpegPath, filePath);
    if (bytes != null) return bytes;

    print('⚠️  Unable to extract cover art using any method');
    return null;
  }

  /// Method 1: Try extracting attached picture
  static Future<Uint8List?> _tryExtractAttachment(
      String ffmpegPath, String filePath) async {
    try {
      var result = await Process.run(
        ffmpegPath,
        [
          '-i', filePath,
          '-map', '0:v',
          '-map', '-0:V', // Exclude main video, keep only attached pics
          '-c', 'copy',
          '-f', 'image2pipe',
          '-',
        ],
        stdoutEncoding: null,
      );

      return _validateImageBytes(result.stdout, 'Attachment');
    } catch (e) {
      print('Method 1 (attachment) failed: $e');
      return null;
    }
  }

  /// Method 2: Try extracting from last video stream (often the cover)
  static Future<Uint8List?> _tryExtractLastVideoStream(
      String ffmpegPath, String filePath) async {
    try {
      // First, count video streams
      var probe = await Process.run(
        ffmpegPath,
        ['-i', filePath, '-hide_banner'],
        runInShell: true,
      );

      // Look for "Stream #0:X: Video:" lines in stderr
      String output = probe.stderr.toString();
      final videoStreamMatches =
          RegExp(r'Stream #0:(\d+).*: Video:').allMatches(output);

      if (videoStreamMatches.length > 1) {
        // Get last video stream index
        final lastStreamIndex = videoStreamMatches.last.group(1);

        var result = await Process.run(
          ffmpegPath,
          [
            '-i',
            filePath,
            '-map',
            '0:$lastStreamIndex',
            '-c',
            'copy',
            '-f',
            'image2pipe',
            '-frames:v',
            '1',
            '-',
          ],
          stdoutEncoding: null,
        );

        return _validateImageBytes(result.stdout, 'Last stream');
      }
    } catch (e) {
      print('Method 2 (last stream) failed: $e');
    }
    return null;
  }

  /// Method 3: Extract first frame of main video
  static Future<Uint8List?> _tryExtractFirstFrame(
      String ffmpegPath, String filePath) async {
    try {
      var result = await Process.run(
        ffmpegPath,
        [
          '-i', filePath,
          '-vf', 'select=eq(n\\,0)', // Select first frame
          '-vframes', '1',
          '-q:v', '2', // High quality JPEG
          '-f', 'image2pipe',
          '-',
        ],
        stdoutEncoding: null,
      );

      return _validateImageBytes(result.stdout, 'First frame');
    } catch (e) {
      print('Method 3 (first frame) failed: $e');
      return null;
    }
  }

  /// Validate that bytes are a valid image
  static Uint8List? _validateImageBytes(dynamic stdout, String method) {
    if (stdout is List<int>) {
      final bytes = Uint8List.fromList(stdout);

      // Check for valid image headers
      if (bytes.length > 1000) {
        bool isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
        bool isPng = bytes[0] == 0x89 && bytes[1] == 0x50;

        if (isJpeg || isPng) {
          String type = isJpeg ? 'JPEG' : 'PNG';
          String size = (bytes.length / 1024).toStringAsFixed(1);
          print('✅ Extracted $type cover via $method: $size KB');
          return bytes;
        }
      }
    }
    return null;
  }

  /// Get FFmpeg executable path
  static Future<String?> _getFFmpegPath(SettingsService? settings) async {
    // 1. Custom folder
    if (settings != null && settings.ffmpegPath.isNotEmpty) {
      final binPath = p.join(settings.ffmpegPath, 'bin', 'ffmpeg.exe');
      if (File(binPath).existsSync()) return binPath;

      final directPath = p.join(settings.ffmpegPath, 'ffmpeg.exe');
      if (File(directPath).existsSync()) return directPath;
    }

    // 2. Bundled
    try {
      final exePath = Platform.resolvedExecutable;
      final bundled = p.join(p.dirname(exePath), 'ffmpeg.exe');
      if (File(bundled).existsSync()) return bundled;
    } catch (_) {}

    // 3. PATH
    try {
      var result = await Process.run('ffmpeg', ['-version']);
      if (result.exitCode == 0) return 'ffmpeg';
    } catch (_) {}

    return null;
  }
}
