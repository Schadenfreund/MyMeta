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

/// Service for checking and installing updates from GitHub Releases.
///
/// Update flow:
///   1. [checkForUpdates] — queries GitHub API for a newer release
///   2. [downloadAndInstall] — downloads ZIP, extracts to UserData/Updates/, writes pending.json
///   3. [launchUpdateScript] — starts hidden PowerShell process, caller then calls exit(0)
///   4. PowerShell script waits for app to close, robocopy files (excluding UserData), restarts app
///   5. On next launch [checkPendingUpdate] detects version match → [cleanupPendingUpdate]
class UpdateService {
  static const String repoOwner = 'Schadenfreund';
  static const String repoName = 'MyMeta';
  static const int _processWaitTimeoutSeconds = 60;

  static String get releasesUrl =>
      'https://github.com/$repoOwner/$repoName/releases';
  static String get latestReleaseUrl => '$releasesUrl/latest';

  String? _updateScriptPath;

  /// Get the path to the update script (if update was downloaded)
  String? get updateScriptPath => _updateScriptPath;

  // ---------------------------------------------------------------------------
  // Paths
  // ---------------------------------------------------------------------------

  /// AppDir/UserData/Updates/
  static String getUpdatesDir() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return p.join(exeDir, 'UserData', 'Updates');
  }

  // ---------------------------------------------------------------------------
  // Pending update lifecycle
  // ---------------------------------------------------------------------------

  /// Check if there's a pending update ready to install.
  /// Automatically cleans up stale/completed updates.
  Future<PendingUpdate?> checkPendingUpdate() async {
    try {
      final pendingFile = File(p.join(getUpdatesDir(), 'pending.json'));
      if (!pendingFile.existsSync()) return null;

      final data = jsonDecode(await pendingFile.readAsString());
      final version = data['version'] as String?;
      final scriptPath = data['scriptPath'] as String?;

      if (version == null || scriptPath == null) {
        debugPrint('⚠️ Invalid pending.json, cleaning up');
        await cleanupPendingUpdate();
        return null;
      }

      // Already on this version → update succeeded
      final current = (await PackageInfo.fromPlatform()).version;
      if (!_isNewerVersion(current, version)) {
        debugPrint('✅ Pending update v$version already applied, cleaning up');
        await cleanupPendingUpdate();
        return null;
      }

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

  /// Remove the entire UserData/Updates/ directory.
  Future<void> cleanupPendingUpdate() async {
    try {
      final dir = Directory(getUpdatesDir());
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('🧹 Cleaned up updates directory');
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up updates: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Check for updates
  // ---------------------------------------------------------------------------

  /// Query GitHub API for a newer release. Returns null if up-to-date.
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      debugPrint('🔍 Checking for updates (current: v$current)');

      final response = await _createDio().get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );

      if (response.statusCode != 200) return null;

      final data = response.data;
      final latest =
          (data['tag_name'] as String).replaceFirst('v', '');

      debugPrint('📦 Latest version on GitHub: v$latest');

      if (!_isNewerVersion(current, latest)) {
        debugPrint('✅ Already running latest version');
        return null;
      }

      debugPrint('✨ Update available: v$current → v$latest');
      return UpdateInfo(
        version: latest,
        downloadUrl: _getWindowsAssetUrl(data['assets']),
        releaseNotes: data['body'] ?? 'No release notes available',
        publishedAt: DateTime.parse(data['published_at']),
      );
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Download & stage
  // ---------------------------------------------------------------------------

  /// Download release ZIP, extract to UserData/Updates/, write pending.json.
  /// Returns true on success.
  Future<bool> downloadAndInstall(
    UpdateInfo updateInfo,
    void Function(double progress, String status) onProgress,
  ) async {
    try {
      onProgress(0.0, 'Preparing download...');

      final updatesDir = Directory(getUpdatesDir());
      if (await updatesDir.exists()) await updatesDir.delete(recursive: true);
      await updatesDir.create(recursive: true);

      // Download
      final zipPath = p.join(updatesDir.path, 'update.zip');
      debugPrint('📥 Downloading update from: ${updateInfo.downloadUrl}');

      await _createDio(receiveTimeout: const Duration(minutes: 5)).download(
        updateInfo.downloadUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(
              (received / total) * 0.5,
              'Downloading... ${((received / total) * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      // Extract
      onProgress(0.5, 'Extracting files...');
      final extractPath = p.join(updatesDir.path, 'extracted');
      await _extractZip(zipPath, extractPath);
      await File(zipPath).delete(); // save space

      // Create update script
      onProgress(0.7, 'Preparing update...');
      final exePath = Platform.resolvedExecutable;
      final appDir = p.dirname(exePath);
      debugPrint('📁 App directory: $appDir');

      final scriptPath = await _createUpdateScript(
        sourcePath: extractPath,
        targetPath: appDir,
        exeName: p.basename(exePath),
        scriptDir: updatesDir.path,
      );

      // Persist for "Restart Later"
      await File(p.join(updatesDir.path, 'pending.json')).writeAsString(
        jsonEncode({'version': updateInfo.version, 'scriptPath': scriptPath}),
      );

      _updateScriptPath = scriptPath;
      onProgress(0.9, 'Update ready!');
      debugPrint('✅ Update staged: $scriptPath');
      return true;
    } catch (e) {
      debugPrint('❌ Error installing update: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Launch
  // ---------------------------------------------------------------------------

  /// Start the update script in a hidden PowerShell process.
  /// Returns null on success, or an error message on failure.
  /// The caller is responsible for calling exit(0) after a successful launch.
  Future<String?> launchUpdateScript() async {
    final scriptPath = _updateScriptPath;
    if (scriptPath == null || !File(scriptPath).existsSync()) {
      return 'Update script not found. Please try again.';
    }

    try {
      // -ExecutionPolicy Bypass is required — both -File and -Command respect execution policy
      // for .ps1 files. Without it the script is silently blocked on most Windows installs.
      // -NonInteractive prevents any prompts from hanging the detached process.
      await Process.start(
        'powershell.exe',
        [
          '-ExecutionPolicy', 'Bypass',
          '-NonInteractive',
          '-WindowStyle', 'Hidden',
          '-File', scriptPath,
        ],
        mode: ProcessStartMode.detached,
      );
      return null;
    } catch (e) {
      debugPrint('❌ Failed to launch update script: $e');
      return 'Could not start installer. Download manually from GitHub.';
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Extract a ZIP archive, stripping the root folder.
  Future<void> _extractZip(String zipPath, String extractPath) async {
    debugPrint('📦 Extracting update...');
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    if (archive.isEmpty) throw Exception('ZIP archive is empty');

    // Detect root folder (e.g. MyMeta-v1.1.0-windows/)
    // Normalize separators — Compress-Archive on Windows may use backslashes
    final rootFolder =
        archive.first.name.replaceAll('\\', '/').split('/').first;

    for (final file in archive) {
      if (!file.isFile) continue;
      final normalized = file.name.replaceAll('\\', '/');
      if (!normalized.startsWith('$rootFolder/')) continue;
      final relative = normalized.substring(rootFolder.length + 1);
      if (relative.isEmpty) continue;

      final outPath = p.join(extractPath, relative);
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content as List<int>);
    }
  }

  /// Create a hidden PowerShell update script.
  /// Uses Get-Process (no console windows) and robocopy for reliable copying.
  Future<String> _createUpdateScript({
    required String sourcePath,
    required String targetPath,
    required String exeName,
    required String scriptDir,
  }) async {
    final scriptPath = p.join(scriptDir, 'update_mymeta.ps1');
    final logPath = p.join(scriptDir, 'update_mymeta.log');
    final processName =
        exeName.replaceAll(RegExp(r'\.exe$', caseSensitive: false), '');

    // Single-quoted PS strings are literal — Windows backslash paths are safe.
    final script = '''
function Log(\$msg) {
    "[(\$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))] \$msg" |
        Out-File -Append -Encoding utf8 -FilePath '$logPath'
}

Log "=== MyMeta Update Started ==="
Log "Source: $sourcePath"
Log "Target: $targetPath"

# Wait for app to exit (with timeout)
Log "Waiting for $processName to exit..."
Start-Sleep -Seconds 2
\$waited = 0
while (Get-Process -Name '$processName' -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 1
    \$waited++
    if (\$waited -ge $_processWaitTimeoutSeconds) {
        Log "WARNING: Timeout after \$waited seconds, proceeding anyway"
        break
    }
}
Log "Process exited after \$waited seconds"

# Copy all files except UserData (preserves settings, tools, database)
Log "Copying files..."
\$output = & robocopy '$sourcePath' '$targetPath' /E /XD UserData /R:5 /W:2 /NP 2>&1
\$rc = \$LASTEXITCODE
\$output | Out-File -Append -Encoding utf8 -FilePath '$logPath'
Log "Robocopy exit code: \$rc"

# robocopy: 0-7 = success, 8+ = error
if (\$rc -ge 8) {
    Log "ERROR: File copy failed"
    exit 1
}

# Restart app
Log "Restarting app..."
Start-Sleep -Seconds 1
Start-Process -FilePath '$targetPath\\$exeName' -WorkingDirectory '$targetPath'
Log "=== Update Complete ==="
''';

    await File(scriptPath).writeAsString(script);
    debugPrint('📜 Update script: $scriptPath');
    debugPrint('📜 Update log: $logPath');
    return scriptPath;
  }

  Dio _createDio({Duration? receiveTimeout}) => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        ),
      );

  /// Semantic version comparison. Returns true if [latest] > [current].
  bool _isNewerVersion(String current, String latest) {
    try {
      final c = _parseVersion(current);
      final l = _parseVersion(latest);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error comparing versions: $e');
      return false;
    }
  }

  /// Parse "1.2.3" or "1.2.3-beta" into [1, 2, 3].
  static List<int> _parseVersion(String version) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version);
    if (match == null) throw FormatException('Invalid version: $version');
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  /// Find the Windows ZIP asset URL from a GitHub release.
  String _getWindowsAssetUrl(List assets) {
    for (final asset in assets) {
      final name = asset['name'] as String;
      if (name.contains('windows') && name.endsWith('.zip')) {
        debugPrint('✅ Using Windows asset: $name');
        return asset['browser_download_url'] as String;
      }
    }
    throw Exception(
      'No Windows release found. Assets: ${assets.map((a) => a['name']).join(', ')}',
    );
  }
}
