import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import '../utils/image_utils.dart';

/// Manages poster caching and resizing for efficient batch operations
/// Reduces redundant downloads and re-processing when handling multiple files
class PosterCacheService {
  static const String _cacheSubdir = 'CachedPosters';
  static const int _minCacheFileSize = 5000; // 5KB minimum

  /// Get path to cached poster, downloading and resizing if needed
  /// Returns the path to a resized 512px poster in cache, or null if unavailable
  static Future<String?> downloadAndCachePoster({
    required String? posterUrl,
    required String title,
    required int? year,
    required String mediaType, // 'movie' or 'tv'
    int? season,
  }) async {
    if (posterUrl == null || posterUrl.isEmpty) {
      debugPrint('⚠️  PosterCache: No poster URL provided');
      return null;
    }

    final cacheDir = await _getCacheDir();
    if (cacheDir == null) {
      debugPrint('❌ PosterCache: Failed to create cache directory');
      return null;
    }

    final cacheFileName = _generateCacheFileName(title, year, mediaType, season);
    final cachedPath = p.join(cacheDir.path, cacheFileName);

    // Check if valid cached version exists
    if (_isValidCacheFile(cachedPath)) {
      debugPrint('✅ PosterCache: Using cached poster: $cacheFileName');
      return cachedPath;
    }

    // Download and resize
    try {
      return await _downloadResizeAndCache(posterUrl, cachedPath);
    } catch (e) {
      debugPrint('❌ PosterCache: Error caching poster: $e');
      return null;
    }
  }

  /// Download poster, resize to 512px, and save to cache
  static Future<String?> _downloadResizeAndCache(
    String posterUrl,
    String cachePath,
  ) async {
    // Create temp file for download
    final cacheDir = File(cachePath).parent;
    final tempFile = File(p.join(cacheDir.path, '${p.basename(cachePath)}.tmp'));

    try {
      // Download to temp file
      debugPrint('⏳ PosterCache: Downloading poster...');
      final bytes = await _downloadFileBytes(posterUrl);
      if (bytes == null || bytes.isEmpty) {
        debugPrint('❌ PosterCache: Failed to download poster');
        return null;
      }

      tempFile.writeAsBytesSync(bytes);
      if (!tempFile.existsSync() || tempFile.lengthSync() < 1000) {
        debugPrint('❌ PosterCache: Downloaded file invalid');
        return null;
      }

      // Try resizing with FFmpeg for smaller file sizes
      debugPrint('⏳ PosterCache: Resizing poster to 512px...');
      final resizeSuccess = await ImageUtils.resizePosterWithFFmpeg(
        tempFile.path,
        cachePath,
        512,
      );

      if (resizeSuccess && File(cachePath).existsSync()) {
        debugPrint('✅ PosterCache: Cached resized poster');
        return cachePath;
      }

      // Resize failed (FFmpeg unavailable?) — cache the original download as-is
      debugPrint('⚠️  PosterCache: Resize unavailable, caching original poster');
      tempFile.copySync(cachePath);
      if (File(cachePath).existsSync() &&
          File(cachePath).lengthSync() >= _minCacheFileSize) {
        return cachePath;
      }
      return null;
    } catch (e) {
      debugPrint('❌ PosterCache: Exception during download/resize: $e');
      return null;
    } finally {
      // Clean up temp file
      try {
        if (tempFile.existsSync()) tempFile.deleteSync();
      } catch (e) {
        debugPrint('⚠️  PosterCache: Failed to clean up temp file: $e');
      }
    }
  }

  /// Download file bytes from URL with timeout
  static Future<List<int>?> _downloadFileBytes(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      debugPrint('⚠️  HTTP ${response.statusCode}: $url');
      return null;
    } catch (e) {
      debugPrint('❌ HTTP error downloading $url: $e');
      return null;
    }
  }

  /// Generate consistent cache filename for a poster
  /// Movies: "Title_Year_512pixel.jpg"
  /// TV shows: "Title_Year_S##_512pixel.jpg"
  static String _generateCacheFileName(
    String title,
    int? year,
    String mediaType,
    int? season,
  ) {
    String sanitized = title
        .replaceAll(RegExp(r'[\\/*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(':', '')
        .trim();

    if (sanitized.isEmpty) sanitized = 'unknown';

    final yearStr = year?.toString() ?? 'unknown';

    if (mediaType == 'tv' && season != null) {
      final seasonStr = season.toString().padLeft(2, '0');
      return '${sanitized}_${yearStr}_S${seasonStr}_512pixel.jpg';
    }

    return '${sanitized}_${yearStr}_512pixel.jpg';
  }

  /// Check if cached file is valid (exists, correct size, readable)
  static bool _isValidCacheFile(String cachePath) {
    try {
      final file = File(cachePath);
      if (!file.existsSync()) return false;

      final size = file.lengthSync();
      if (size < _minCacheFileSize) {
        debugPrint('⚠️  PosterCache: Cache file too small: $size bytes');
        return false;
      }

      // Verify it's readable JPEG/PNG by checking magic bytes
      final header = file.readAsBytesSync().take(4).toList();
      final isJpeg = header.length >= 2 && header[0] == 0xFF && header[1] == 0xD8;
      final isPng = header.length >= 4 &&
          header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47;

      if (!isJpeg && !isPng) {
        debugPrint('⚠️  PosterCache: Cache file is not valid JPEG/PNG');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️  PosterCache: Error validating cache: $e');
      return false;
    }
  }

  /// Get or create cache directory
  static Future<Directory?> _getCacheDir() async {
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final userDataDir = p.join(exeDir, 'UserData', _cacheSubdir);
      final dir = Directory(userDataDir);

      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
        debugPrint('📁 PosterCache: Created cache directory: $userDataDir');
      }

      return dir;
    } catch (e) {
      debugPrint('❌ PosterCache: Failed to create cache dir: $e');
      return null;
    }
  }
}
