// Removed unused import
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Service for checking and installing updates from GitHub Releases
class UpdateService {
  static const String repoOwner = 'Schadenfreund';
  static const String repoName = 'MyMeta';

  /// Check if a newer version is available on GitHub
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('🔍 Checking for updates (current: v$currentVersion)');

      // Fetch latest release from GitHub API
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion =
            (data['tag_name'] as String).replaceFirst('v', '');

        debugPrint('📦 Latest version on GitHub: v$latestVersion');

        if (_isNewerVersion(currentVersion, latestVersion)) {
          debugPrint('✨ Update available: v$currentVersion → v$latestVersion');

          return UpdateInfo(
            version: latestVersion,
            downloadUrl: _getWindowsAssetUrl(data['assets']),
            releaseNotes: data['body'] ?? 'No release notes available',
            publishedAt: DateTime.parse(data['published_at']),
          );
        } else {
          debugPrint('✅ Already running latest version');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
    }
    return null;
  }

  /// Download and install update
  /// Returns true if successful, false otherwise
  Future<bool> downloadAndInstall(
    UpdateInfo updateInfo,
    Function(double progress, String status) onProgress,
  ) async {
    try {
      onProgress(0.0, 'Preparing download...');

      final dio = Dio();
      final tempDir = await Directory.systemTemp.createTemp('mymeta_update_');
      final zipPath = p.join(tempDir.path, 'update.zip');

      debugPrint('📥 Downloading update from: ${updateInfo.downloadUrl}');

      // Download with progress
      await dio.download(
        updateInfo.downloadUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress * 0.5,
                'Downloading... ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      onProgress(0.5, 'Extracting files...');
      debugPrint('📦 Extracting update...');

      // Extract ZIP
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the root folder in the archive (e.g., MyMeta-v1.0.1-windows/)
      final rootFolder = archive.first.name.split('/').first;
      final extractPath = p.join(tempDir.path, 'extracted');

      // Extract all files
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          // Remove root folder from path
          final relativePath = filename.substring(rootFolder.length + 1);
          final filePath = p.join(extractPath, relativePath);
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }

      onProgress(0.7, 'Installing update...');
      debugPrint('🔧 Replacing app files...');

      // Get current app directory
      final currentDir = Directory.current.path;

      // Replace files (preserving UserData)
      await _replaceAppFiles(extractPath, currentDir);

      onProgress(0.9, 'Cleaning up...');

      // Cleanup
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        debugPrint('⚠️  Could not delete temp files: $e');
      }

      onProgress(1.0, 'Update complete!');
      debugPrint('✅ Update installed successfully!');

      return true;
    } catch (e) {
      debugPrint('❌ Error installing update: $e');
      return false;
    }
  }

  /// Replace app files while preserving UserData
  Future<void> _replaceAppFiles(String sourcePath, String targetPath) async {
    // Files/folders to replace
    final toReplace = ['MyMeta.exe', 'data'];

    // Also copy all DLLs
    final sourceDir = Directory(sourcePath);
    await for (final file in sourceDir.list()) {
      if (file is File && file.path.endsWith('.dll')) {
        final targetFile = p.join(targetPath, p.basename(file.path));
        await file.copy(targetFile);
      }
    }

    // Copy main files and folders
    for (final item in toReplace) {
      final source = p.join(sourcePath, item);
      final target = p.join(targetPath, item);

      if (await FileSystemEntity.isDirectory(source)) {
        // Delete old directory and copy new one
        if (await Directory(target).exists()) {
          await Directory(target).delete(recursive: true);
        }
        await _copyDirectory(Directory(source), Directory(target));
      } else if (await File(source).exists()) {
        // Copy file
        await File(source).copy(target);
      }
    }

    debugPrint('✅ App files replaced (UserData preserved)');
  }

  /// Recursively copy directory
  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      if (entity is File) {
        await entity.copy(p.join(target.path, p.basename(entity.path)));
      } else if (entity is Directory) {
        await _copyDirectory(
          entity,
          Directory(p.join(target.path, p.basename(entity.path))),
        );
      }
    }
  }

  /// Compare version strings (semantic versioning)
  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false; // Versions are equal
    } catch (e) {
      debugPrint('⚠️  Error comparing versions: $e');
      return false;
    }
  }

  /// Extract Windows asset URL from GitHub release assets
  String _getWindowsAssetUrl(List assets) {
    for (final asset in assets) {
      final name = asset['name'] as String;
      if (name.contains('windows') && name.endsWith('.zip')) {
        return asset['browser_download_url'] as String;
      }
    }
    throw Exception('No Windows release found in assets');
  }
}

/// Information about an available update
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}
