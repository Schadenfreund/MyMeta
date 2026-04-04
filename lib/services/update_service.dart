import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// A pending update that has been downloaded and is ready to install
class PendingUpdate {
  final String version;
  final String scriptPath;
  PendingUpdate({required this.version, required this.scriptPath});
}

/// Service for checking and installing updates from GitHub Releases
class UpdateService {
  static const String repoOwner = 'Schadenfreund';
  static const String repoName = 'MyMeta';

  String? _updateScriptPath;

  /// Get the path to the update script (if update was downloaded)
  String? get updateScriptPath => _updateScriptPath;

  /// Get the updates directory path (AppDir/UserData/Updates/)
  static String getUpdatesDir() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return p.join(exeDir, 'UserData', 'Updates');
  }

  /// Check if there's a pending update ready to install.
  /// Returns null if no valid pending update exists.
  /// Automatically cleans up if the update was already applied.
  Future<PendingUpdate?> checkPendingUpdate() async {
    try {
      final updatesDir = getUpdatesDir();
      final pendingFile = File(p.join(updatesDir, 'pending.json'));
      if (!pendingFile.existsSync()) return null;

      final content = await pendingFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final version = data['version'] as String;
      final scriptPath = data['scriptPath'] as String;

      // Check if we're already on this version (update already completed)
      final packageInfo = await PackageInfo.fromPlatform();
      if (!_isNewerVersion(packageInfo.version, version)) {
        debugPrint('✅ Pending update v$version already applied, cleaning up');
        await cleanupPendingUpdate();
        return null;
      }

      // Check if the script still exists
      if (!File(scriptPath).existsSync()) {
        debugPrint('⚠️ Pending update script missing, cleaning up');
        await cleanupPendingUpdate();
        return null;
      }

      debugPrint('📦 Found pending update: v$version');
      _updateScriptPath = scriptPath;
      return PendingUpdate(version: version, scriptPath: scriptPath);
    } catch (e) {
      debugPrint('⚠️ Error checking pending update: $e');
      return null;
    }
  }

  /// Clean up the updates directory
  Future<void> cleanupPendingUpdate() async {
    try {
      final updatesDir = Directory(getUpdatesDir());
      if (await updatesDir.exists()) {
        await updatesDir.delete(recursive: true);
        debugPrint('🧹 Cleaned up updates directory');
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up updates: $e');
    }
  }

  /// Check if a newer version is available on GitHub
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('🔍 Checking for updates (current: v$currentVersion)');

      // Fetch latest release from GitHub API
      final dio = _createDio();
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

  /// Download and install update into AppDir/UserData/Updates/.
  /// The update persists so the user can restart later.
  /// Returns true if successful, false otherwise.
  Future<bool> downloadAndInstall(
    UpdateInfo updateInfo,
    Function(double progress, String status) onProgress,
  ) async {
    try {
      onProgress(0.0, 'Preparing download...');

      // Use AppDir/UserData/Updates/ so the download persists across sessions
      final updatesDir = Directory(getUpdatesDir());
      if (await updatesDir.exists()) {
        await updatesDir.delete(recursive: true);
      }
      await updatesDir.create(recursive: true);

      final dio = _createDio(receiveTimeout: const Duration(minutes: 5));
      final zipPath = p.join(updatesDir.path, 'update.zip');

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
      // Normalize path separators — Compress-Archive on Windows may use backslashes
      final firstEntry = archive.first.name.replaceAll('\\', '/');
      final rootFolder = firstEntry.split('/').first;
      final extractPath = p.join(updatesDir.path, 'extracted');

      // Extract all files
      for (final file in archive) {
        final normalizedName = file.name.replaceAll('\\', '/');
        if (file.isFile && normalizedName.startsWith('$rootFolder/')) {
          final data = file.content as List<int>;
          // Remove root folder from path
          final relativePath = normalizedName.substring(rootFolder.length + 1);
          if (relativePath.isEmpty) continue;
          final filePath = p.join(extractPath, relativePath);
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }

      // Delete the ZIP after extraction to save space
      await File(zipPath).delete();

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
        updatesDir.path,
      );

      // Write pending.json so the update survives "Restart Later"
      final pendingFile = File(p.join(updatesDir.path, 'pending.json'));
      await pendingFile.writeAsString(jsonEncode({
        'version': updateInfo.version,
        'scriptPath': batchScriptPath,
      }));

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

  /// Create a CMD batch script that will perform the update after the app closes.
  /// Uses robocopy for reliable file copying with retry logic.
  /// [scriptDir] should be the temp directory so the script is always writable.
  Future<String> _createUpdateScript(
    String sourcePath,
    String targetPath,
    String exeName,
    String scriptDir,
  ) async {
    final scriptPath = p.join(scriptDir, 'update_mymeta.cmd');
    final logPath = p.join(scriptDir, 'update_mymeta.log');

    final script = '''
@echo off
setlocal enabledelayedexpansion

set "LOG=$logPath"
echo [%date% %time%] === MyMeta Update Started === >> "%LOG%"

set "EXE=$exeName"
set "SRC=$sourcePath"
set "DST=$targetPath"

echo [%date% %time%] Source: %SRC% >> "%LOG%"
echo [%date% %time%] Target: %DST% >> "%LOG%"
echo [%date% %time%] Waiting for %EXE% to exit... >> "%LOG%"

timeout /t 2 /nobreak >nul 2>&1

:WAIT
tasklist /fi "imagename eq %EXE%" 2>nul | find /i "%EXE%" >nul 2>&1
if not errorlevel 1 (
    timeout /t 1 /nobreak >nul 2>&1
    goto WAIT
)

echo [%date% %time%] Process exited. Copying files... >> "%LOG%"

:: Use robocopy to copy all files, excluding UserData (preserves settings and tools)
robocopy "%SRC%" "%DST%" /E /XD UserData /R:5 /W:2 /NP >> "%LOG%" 2>&1
set RC=%errorlevel%
echo [%date% %time%] Robocopy exit code: %RC% >> "%LOG%"

:: robocopy returns 0-7 for various success states, 8+ for errors
if %RC% GEQ 8 (
    echo [%date% %time%] ERROR: File copy failed with code %RC% >> "%LOG%"
    goto END
)

echo [%date% %time%] Files copied successfully. Restarting app... >> "%LOG%"
timeout /t 1 /nobreak >nul 2>&1
start "" "%DST%\\%EXE%"

:END
echo [%date% %time%] === Update Script Finished === >> "%LOG%"
''';

    await File(scriptPath).writeAsString(script);
    debugPrint('📜 Update script created at: $scriptPath');
    debugPrint('📜 Update log will be at: $logPath');
    return scriptPath;
  }

  /// Create a Dio instance with standard connection timeout
  Dio _createDio({Duration? receiveTimeout}) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
    ),
  );

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
