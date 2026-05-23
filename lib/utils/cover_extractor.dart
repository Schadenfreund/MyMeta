import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../services/settings_service.dart';
import '../services/tool_resolver.dart';
import 'windows_thumbnail.dart';

/// Helper class for extracting cover art from media files
/// Uses format-specific fast tools: mkvextract (MKV), AtomicParsley (MP4), FFmpeg (fallback)
class CoverExtractor {
  /// Extract cover art as bytes - format-specific fast extraction
  static Future<Uint8List?> extractCoverBytes(
    String filePath, {
    SettingsService? settings,
  }) async {
    final ext = p.extension(filePath).toLowerCase();

    debugPrint('🖼️  Extracting cover from: ${p.basename(filePath)} ($ext)');

    Uint8List? bytes;

    // First try Windows Shell thumbnail (instant - uses Windows cache)
    try {
      bytes = await WindowsThumbnail.getThumbnail(filePath, size: 256);
      if (bytes != null) {
        debugPrint('  ⚡ Got thumbnail from Windows Shell cache (instant)');
        return bytes;
      }
    } catch (e) {
      // Windows thumbnail not available, continue with other methods
    }

    // Try format-specific fast tools
    if (ext == '.mkv') {
      bytes = await _extractMkvCover(filePath, settings);
      if (bytes != null) return bytes;
    } else if (ext == '.mp4' || ext == '.m4v') {
      bytes = await _extractMp4Cover(filePath, settings);
      if (bytes != null) return bytes;
    }

    // Fall back to FFmpeg for all formats
    bytes = await _extractWithFFmpeg(filePath, settings);
    if (bytes != null) return bytes;

    debugPrint('⚠️  Unable to extract cover art from ${p.basename(filePath)}');
    return null;
  }

  /// Extract cover from MKV - tries mkvextract first, FFmpeg fallback
  static Future<Uint8List?> _extractMkvCover(
    String filePath,
    SettingsService? settings,
  ) async {
    // Try mkvextract for instant extraction of last video track (usually cover)
    final bytes = await _tryMkvextractTracks(filePath, settings);
    if (bytes != null) return bytes;

    // If mkvextract not available or failed, skip straight to FFmpeg first frame
    // (the attachment method doesn't work for most MKV covers)
    return null; // Will fall back to main FFmpeg extraction
  }

  /// Try extracting cover using FFmpeg directly to memory (fastest - no temp files)
  static Future<Uint8List?> _tryMkvextractTracks(
    String filePath,
    SettingsService? settings,
  ) async {
    // Use FFmpeg to extract attached pic stream directly to stdout (memory)
    // This is fastest - no temp files, no disk I/O
    String? ffmpegPath = await _getFFmpegPath(settings);
    if (ffmpegPath == null) return null;

    debugPrint('  ⚡ Extracting cover directly to memory (no temp files)...');

    try {
      // Extract attached picture stream directly to stdout
      var result = await Process.run(
        ffmpegPath,
        [
          '-i', filePath,
          '-map', '0:v',
          '-map', '-0:V', // Exclude main video, keep only attached pics
          '-c', 'copy',
          '-f', 'image2pipe',
          '-', // Output to stdout
        ],
        stdoutEncoding: null, // Get raw bytes
      );

      if (result.exitCode == 0) {
        return _validateImageBytes(result.stdout, 'direct memory (instant)');
      }
      return null;
    } catch (e) {
      debugPrint('  ⚠️  Direct-memory extraction failed: $e');
      return null;
    }
  }

  /// Extract cover from MP4 using AtomicParsley (fast)
  static Future<Uint8List?> _extractMp4Cover(
    String filePath,
    SettingsService? settings,
  ) async {
    try {
      debugPrint('  🔍 Resolving AtomicParsley...');
      String? atomicParsleyPath =
          await _resolveAtomicParsley(settings: settings);
      if (atomicParsleyPath == null) {
        debugPrint('  ⚠️  AtomicParsley not found (download from GitHub)');
        return null;
      }
      debugPrint('  ✅ Found AtomicParsley: $atomicParsleyPath');

      // AtomicParsley extracts to same directory with _artwork_1.jpg suffix
      final fileDir = p.dirname(filePath);
      final baseName = p.basenameWithoutExtension(filePath);
      final artworkPath = p.join(fileDir, '${baseName}_artwork_1.jpg');
      final artworkFile = File(artworkPath);

      try {
        // Extract artwork
        var result = await Process.run(
          atomicParsleyPath,
          [
            filePath,
            '--extractPix',
          ],
          runInShell: true,
        );

        if (result.exitCode == 0 && artworkFile.existsSync()) {
          final bytes = await artworkFile.readAsBytes();
          final validated = _validateImageBytes(bytes, 'AtomicParsley (fast)');
          return validated;
        }
      } finally {
        // Cleanup extracted file
        try {
          if (artworkFile.existsSync()) artworkFile.deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('  ⚠️  AtomicParsley failed: $e');
    }
    return null;
  }

  /// Extract cover using FFmpeg (fallback - slower but works for all formats)
  static Future<Uint8List?> _extractWithFFmpeg(
    String filePath,
    SettingsService? settings,
  ) async {
    String? ffmpegPath = await _getFFmpegPath(settings);
    if (ffmpegPath == null) {
      debugPrint('  ⚠️  FFmpeg not available');
      return null;
    }

    debugPrint('  ↪️  Using FFmpeg fallback...');
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

    return null;
  }

  /// Resolve AtomicParsley path (UserData → custom → bundled).
  static Future<String?> _resolveAtomicParsley({SettingsService? settings}) =>
      ToolResolver.resolveExe('AtomicParsley', settings: settings);

  /// FFmpeg method 1: Try extracting attached picture
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

      return _validateImageBytes(result.stdout, 'FFmpeg attachment');
    } catch (e) {
      debugPrint('  ⚠️  FFmpeg attachment extract failed: $e');
      return null;
    }
  }

  /// FFmpeg method 2: Try extracting from last video stream (often the cover)
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

        return _validateImageBytes(result.stdout, 'FFmpeg last stream');
      }
    } catch (e) {
      debugPrint('  ⚠️  FFmpeg last-stream extract failed: $e');
      return null;
    }
    return null;
  }

  /// FFmpeg method 3: Extract first frame of main video
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

      return _validateImageBytes(result.stdout, 'FFmpeg first frame');
    } catch (e) {
      debugPrint('  ⚠️  FFmpeg first-frame extract failed: $e');
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
          debugPrint('  ✅ Extracted $type cover via $method: $size KB');
          return bytes;
        }
      }
    }
    return null;
  }

  /// Resolve FFmpeg path (UserData → custom → bundled → PATH).
  static Future<String?> _getFFmpegPath(SettingsService? settings) =>
      ToolResolver.resolveExe(
        'ffmpeg',
        settings: settings,
        usePathFallback: true,
      );
}
