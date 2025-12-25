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

  String? _updateScriptPath;

  /// Get the path to the update script (if update was downloaded)
  String? get updateScriptPath => _updateScriptPath;

  /// Check if a newer version is available on GitHub
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('🔍 Checking for updates (current: v$currentVersion)');

      // Fetch latest release from GitHub API
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final response = await dio.get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = (data['tag_name'] as String).replaceFirst(
          'v',
          '',
        );

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

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
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
            onProgress(
              progress * 0.5,
              'Downloading... ${(progress * 100).toStringAsFixed(0)}%',
            );
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

      onProgress(0.7, 'Preparing update...');
      debugPrint('🔧 Preparing update installation...');

      // Get current app directory from executable path (works for portable apps)
      final exePath = Platform.resolvedExecutable;
      final currentDir = p.dirname(exePath);
      debugPrint('📁 App directory: $currentDir');

      // Create update batch script
      final batchScriptPath = await _createUpdateScript(
        extractPath,
        currentDir,
        p.basename(exePath),
      );

      onProgress(0.9, 'Update ready!');
      debugPrint('✅ Update staged successfully!');
      debugPrint('📜 Update script: $batchScriptPath');

      // Store the script path for the UI to execute after user confirmation
      _updateScriptPath = batchScriptPath;

      return true;
    } catch (e) {
      debugPrint('❌ Error installing update: $e');
      return false;
    }
  }

  /// Create a PowerShell script that will perform the update silently after the app closes
  Future<String> _createUpdateScript(
    String sourcePath,
    String targetPath,
    String exeName,
  ) async {
    final scriptPath = p.join(targetPath, 'update_mymeta.ps1');

    // Escape backslashes for PowerShell
    final sourcePathEscaped = sourcePath.replaceAll('\\', '\\\\');
    final targetPathEscaped = targetPath.replaceAll('\\', '\\\\');

    // Create PowerShell script content (runs silently)
    final script =
        '''
# MyMeta Auto-Update Script (Silent)
\$ErrorActionPreference = "SilentlyContinue"

# Wait for MyMeta to close
\$exeName = "$exeName"
\$processName = \$exeName -replace '\\.exe\$', ''

Start-Sleep -Seconds 2

while (Get-Process -Name \$processName -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 1
}

# Source and target paths
\$sourcePath = "$sourcePathEscaped"
\$targetPath = "$targetPathEscaped"

# Perform update (copy files silently)
try {
    # Copy new EXE
    Copy-Item -Path "\$sourcePath\\\$exeName" -Destination "\$targetPath\\\$exeName" -Force -ErrorAction Stop

    # Copy all DLLs
    Copy-Item -Path "\$sourcePath\\*.dll" -Destination "\$targetPath\\" -Force -ErrorAction SilentlyContinue

    # Remove old data folder and copy new one
    if (Test-Path "\$targetPath\\data") {
        Remove-Item -Path "\$targetPath\\data" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "\$sourcePath\\data") {
        Copy-Item -Path "\$sourcePath\\data" -Destination "\$targetPath\\data" -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    # Log error silently
}

# Wait a moment then restart the app
Start-Sleep -Seconds 1
Start-Process -FilePath "\$targetPath\\\$exeName" -WorkingDirectory "\$targetPath"

# Clean up: delete this script
Start-Sleep -Seconds 2
Remove-Item -Path \$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
''';

    // Write script to file
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsString(script);

    debugPrint('📜 Update script created at: $scriptPath');
    return scriptPath;
  }

  /// Compare version strings (semantic versioning)
  /// Handles version strings with suffixes like "1.0.2-release" or "1.0.2-beta"
  bool _isNewerVersion(String current, String latest) {
    try {
      // Extract only the numeric parts (strip any suffix like "-release", "-beta", etc.)
      final currentClean = _extractSemanticVersion(current);
      final latestClean = _extractSemanticVersion(latest);

      final currentParts = currentClean.split('.').map(int.parse).toList();
      final latestParts = latestClean.split('.').map(int.parse).toList();

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

  /// Extract the semantic version (X.Y.Z) from a version string
  /// Handles: "1.0.2", "1.0.2-release", "1.0.2-beta.1", etc.
  String _extractSemanticVersion(String version) {
    // Match pattern like "1.0.2" at the start (optionally followed by dash and suffix)
    final regex = RegExp(r'^(\d+\.\d+\.\d+)');
    final match = regex.firstMatch(version);
    if (match != null) {
      return match.group(1)!;
    }
    return version; // Fallback to original if no match
  }

  /// Extract Windows asset URL from GitHub release assets
  String _getWindowsAssetUrl(List assets) {
    debugPrint('🔍 Searching for Windows asset in ${assets.length} assets');

    for (final asset in assets) {
      final name = asset['name'] as String;
      debugPrint('  - Found asset: $name');
      if (name.contains('windows') && name.endsWith('.zip')) {
        debugPrint('✅ Using Windows asset: $name');
        return asset['browser_download_url'] as String;
      }
    }

    debugPrint('❌ No Windows release found in assets');
    throw Exception(
      'No Windows release found. Available assets: ${assets.map((a) => a['name']).join(', ')}',
    );
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
