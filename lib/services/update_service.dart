import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'update_installer.dart';

/// A pending update that has been downloaded and is ready to install.
class PendingUpdate {
  final String version;
  final String scriptPath;
  PendingUpdate({required this.version, required this.scriptPath});
}

/// Information about a release available on GitHub.
class UpdateInfo {
  final String version;
  final String downloadUrl;

  /// Optional URL to a `SHA256SUMS` (or `*.sha256`) asset in the same release.
  /// When present, [UpdateService.downloadAndInstall] verifies the archive
  /// digest before extracting; when absent, the download proceeds without
  /// verification and a warning is logged.
  final String? sha256Url;
  final String releaseNotes;
  final DateTime publishedAt;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.sha256Url,
    required this.releaseNotes,
    required this.publishedAt,
  });
}

/// Outcome categories for a check-for-updates call. Lets the UI distinguish
/// "no update" from "couldn't check" (rate limit, no network, etc.) so the
/// user isn't told they're up-to-date when we never actually reached GitHub.
enum UpdateCheckStatus { upToDate, available, checkFailed }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateInfo? info;
  final String? errorMessage;

  const UpdateCheckResult._(this.status, this.info, this.errorMessage);

  factory UpdateCheckResult.upToDate() =>
      const UpdateCheckResult._(UpdateCheckStatus.upToDate, null, null);
  factory UpdateCheckResult.available(UpdateInfo info) =>
      UpdateCheckResult._(UpdateCheckStatus.available, info, null);
  factory UpdateCheckResult.failed(String message) =>
      UpdateCheckResult._(UpdateCheckStatus.checkFailed, null, message);
}

/// Service for checking and installing updates from GitHub Releases.
///
/// Update flow:
///   1. [checkForUpdates]    — queries the GitHub API for a newer release
///   2. [downloadAndInstall] — downloads the archive (with retry), verifies
///       SHA256 if a sums asset is present, extracts to `UserData/Updates/`,
///       writes `pending.json`, generates a platform-appropriate install
///       script via [UpdateInstaller]
///   3. [launchUpdateScript] — starts the script as a detached process; the
///       caller is responsible for calling `exit(0)` afterwards
///   4. The script waits for the running PID to exit, copies new files in
///       place (preserving `UserData/`), and relaunches
///   5. On next launch, [checkPendingUpdate] reconciles state:
///       - version matches      → success, clean up
///       - version still old    → install failed; surface log via
///         [readLastInstallLog] for the UI banner
class UpdateService {
  static const String repoOwner = 'Schadenfreund';
  static const String repoName = 'MyMeta';

  static String get releasesUrl =>
      'https://github.com/$repoOwner/$repoName/releases';
  static String get latestReleaseUrl => '$releasesUrl/latest';

  final UpdateInstaller _installer = UpdateInstaller.forCurrentPlatform();

  String? _updateScriptPath;
  String? _stagedVersion;

  /// `true` if the current OS supports a fully automated in-app update; on
  /// platforms where the answer is `false` (Linux / macOS) the UI should
  /// open the GitHub releases page instead of calling [downloadAndInstall].
  bool get canSelfInstall => _installer.canSelfInstall;

  /// Human-readable platform label, e.g. "Windows", used in user-facing
  /// error messages.
  String get platformLabel => _installer.label;

  /// Path to the staged install script (only set after a successful
  /// [downloadAndInstall] or [checkPendingUpdate] hit).
  String? get updateScriptPath => _updateScriptPath;

  /// Version number staged for install, if any.
  String? get stagedVersion => _stagedVersion;

  // ---------------------------------------------------------------------------
  // Paths
  // ---------------------------------------------------------------------------

  /// `<appDir>/UserData/Updates/` — staging dir for downloads, scripts, logs.
  static String getUpdatesDir() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return p.join(exeDir, 'UserData', 'Updates');
  }

  /// Path to the install log written by the script on the last update run,
  /// or `null` if no log was found.
  static String? get _installLogPath {
    for (final name in ['update_mymeta.log']) {
      final f = File(p.join(getUpdatesDir(), name));
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  /// Read the last install log if it exists. Used to show diagnostics in the
  /// UI when an update reports as failed.
  static String? readLastInstallLog() {
    final path = _installLogPath;
    if (path == null) return null;
    try {
      return File(path).readAsStringSync();
    } catch (e) {
      debugPrint('⚠️ Failed to read install log: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Pending update lifecycle
  // ---------------------------------------------------------------------------

  /// Possible outcomes after an install attempt, computed from on-disk state.
  /// - `succeeded`: pending.json existed, current version now matches its
  ///   target → clean up and tell the UI to celebrate.
  /// - `failed`: pending.json existed but the version on disk didn't change
  ///   → install script likely errored; keep the log around for diagnostics.
  /// - `pending`: pending.json exists and matches a still-newer version → an
  ///   update is downloaded but the user hasn't installed it yet.
  /// - `none`: no pending.json.
  Future<PendingUpdateState> checkPendingUpdateState() async {
    try {
      final pendingFile = File(p.join(getUpdatesDir(), 'pending.json'));
      if (!pendingFile.existsSync()) return PendingUpdateState.none();

      final data = jsonDecode(await pendingFile.readAsString());
      final version = data['version'] as String?;
      final scriptPath = data['scriptPath'] as String?;

      if (version == null || scriptPath == null) {
        debugPrint('⚠️ Invalid pending.json, cleaning up');
        await cleanupPendingUpdate();
        return PendingUpdateState.none();
      }

      final current = (await PackageInfo.fromPlatform()).version;

      if (!_isNewerVersion(current, version)) {
        // We're running the staged version (or newer) — the install worked.
        debugPrint('✅ Update to v$version succeeded; cleaning up');
        _stagedVersion = version;
        await cleanupPendingUpdate();
        return PendingUpdateState.succeeded(version);
      }

      if (!File(scriptPath).existsSync()) {
        debugPrint('⚠️ Pending update script missing — install likely failed');
        // Keep the log if it's there; surface as failure.
        return PendingUpdateState.failed(version);
      }

      debugPrint('📦 Found pending update: v$version (not yet installed)');
      _updateScriptPath = scriptPath;
      _stagedVersion = version;
      return PendingUpdateState.pending(
        PendingUpdate(version: version, scriptPath: scriptPath),
      );
    } catch (e) {
      debugPrint('⚠️ Error checking pending update: $e');
      return PendingUpdateState.none();
    }
  }

  /// Backwards-compatible wrapper returning the staged-but-not-installed
  /// pending update. Callers wanting success/failure detection should use
  /// [checkPendingUpdateState] directly.
  Future<PendingUpdate?> checkPendingUpdate() async {
    final state = await checkPendingUpdateState();
    return state.pending;
  }

  /// Remove `UserData/Updates/` (downloads, scripts, logs, pending.json).
  Future<void> cleanupPendingUpdate() async {
    try {
      final dir = Directory(getUpdatesDir());
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('🧹 Cleaned up updates directory');
      }
      _updateScriptPath = null;
    } catch (e) {
      debugPrint('⚠️ Error cleaning up updates: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Check for updates
  // ---------------------------------------------------------------------------

  /// Query GitHub for the latest release. Distinguishes "up to date" from
  /// "couldn't check" so the UI can show a meaningful message.
  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      debugPrint('🔍 Checking for updates (current: v$current)');

      final response = await _createDio().get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );

      if (response.statusCode == 403) {
        return UpdateCheckResult.failed(
          'GitHub API rate limit hit. Try again later.',
        );
      }
      if (response.statusCode != 200) {
        return UpdateCheckResult.failed(
          'GitHub returned HTTP ${response.statusCode}.',
        );
      }

      final data = response.data;
      final latest = (data['tag_name'] as String).replaceFirst('v', '');
      debugPrint('📦 Latest version on GitHub: v$latest');

      if (!_isNewerVersion(current, latest)) {
        debugPrint('✅ Already running latest version');
        return UpdateCheckResult.upToDate();
      }

      // On platforms where we don't self-install we only need the release
      // metadata for the UI banner — the user will open the GitHub page.
      if (!_installer.canSelfInstall) {
        debugPrint('✨ Update available (redirect-only): v$current → v$latest');
        return UpdateCheckResult.available(
          UpdateInfo(
            version: latest,
            downloadUrl: '',
            sha256Url: null,
            releaseNotes: data['body'] ?? 'No release notes available.',
            publishedAt: DateTime.parse(data['published_at']),
          ),
        );
      }

      final assets = (data['assets'] as List?) ?? const [];
      final archiveAsset = _findAsset(
        assets,
        keyContains: _installer.platformAssetKey,
        endsWith: _installer.archiveExtension,
      );
      if (archiveAsset == null) {
        return UpdateCheckResult.failed(
          'No ${_installer.label} release asset found for v$latest.',
        );
      }

      // Optional SHA256 sums file. Two conventions are supported:
      //   1. A `SHA256SUMS` (or `*.sha256sums`) asset listing all archives
      //   2. A per-archive `<archive>.sha256` asset
      final sha256Asset = _findAsset(
            assets,
            keyContains: archiveAsset['name'] as String,
            endsWith: '.sha256',
          ) ??
          _findAsset(assets, keyContains: 'SHA256SUMS') ??
          _findAsset(assets, keyContains: '.sha256sums');

      debugPrint('✨ Update available: v$current → v$latest');
      return UpdateCheckResult.available(
        UpdateInfo(
          version: latest,
          downloadUrl: archiveAsset['browser_download_url'] as String,
          sha256Url: sha256Asset?['browser_download_url'] as String?,
          releaseNotes: data['body'] ?? 'No release notes available.',
          publishedAt: DateTime.parse(data['published_at']),
        ),
      );
    } on DioException catch (e) {
      debugPrint('❌ DioException during update check: ${e.message}');
      return UpdateCheckResult.failed(
        e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError
            ? 'No network connection.'
            : 'Network error: ${e.message ?? e.type.name}.',
      );
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
      return UpdateCheckResult.failed('Unexpected error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Download & stage
  // ---------------------------------------------------------------------------

  /// Download the release archive, verify its SHA256 if available, extract,
  /// generate the platform install script, write `pending.json`.
  ///
  /// [onProgress] receives values in `[0.0, 1.0]` over the full pipeline:
  /// 0.0–0.5 download, 0.5–0.7 extract, 0.7–0.9 script staging.
  Future<bool> downloadAndInstall(
    UpdateInfo updateInfo,
    void Function(double progress, String status) onProgress,
  ) async {
    if (!_installer.canSelfInstall) {
      onProgress(0, 'Self-install not supported on $platformLabel.');
      return false;
    }
    try {
      onProgress(0.0, 'Preparing download...');

      // Pre-flight: verify we can actually write into the app folder.
      // Fail fast and explicitly rather than midway through the install
      // (typical cause: app installed under `C:\Program Files\` without
      // admin rights, or on a read-only mount).
      final appDir = p.dirname(Platform.resolvedExecutable);
      if (!_isWritable(appDir)) {
        onProgress(
          0,
          'Cannot write to app folder. Move MyMeta to a writable location '
          '(e.g. your user profile) and try again.',
        );
        return false;
      }

      final updatesDir = Directory(getUpdatesDir());
      if (await updatesDir.exists()) await updatesDir.delete(recursive: true);
      await updatesDir.create(recursive: true);

      // 1. Download with one retry on transient failures.
      final archiveName = p.basename(Uri.parse(updateInfo.downloadUrl).path);
      final archivePath = p.join(updatesDir.path, archiveName);
      final downloadOk = await _downloadWithRetry(
        updateInfo.downloadUrl,
        archivePath,
        (received, total) {
          if (total > 0) {
            onProgress(
              (received / total) * 0.45,
              'Downloading... ${((received / total) * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );
      if (!downloadOk) {
        onProgress(0, 'Download failed.');
        return false;
      }
      onProgress(0.45, 'Verifying download...');

      // 2. SHA256 verification (graceful if the sums asset is missing).
      final verified =
          await _verifyDigest(archivePath, updateInfo.sha256Url, archiveName);
      if (verified == _VerifyResult.mismatch) {
        debugPrint('❌ SHA256 mismatch — refusing to install');
        onProgress(0, 'Checksum mismatch. Aborted for safety.');
        return false;
      }
      if (verified == _VerifyResult.absent) {
        debugPrint('⚠️ No SHA256 sums asset on the release — proceeding without verification');
      }

      // 3. Extract.
      onProgress(0.55, 'Extracting files...');
      final extractPath = p.join(updatesDir.path, 'extracted');
      await _extractArchive(archivePath, extractPath);
      await File(archivePath).delete();

      // 4. Generate install script for this OS.
      onProgress(0.75, 'Preparing update...');
      final exePath = Platform.resolvedExecutable;
      final scriptPath = await _installer.createScript(
        sourcePath: extractPath,
        targetPath: p.dirname(exePath),
        exeBaseName: p.basename(exePath),
        scriptDir: updatesDir.path,
        appPid: pid,
      );

      // 5. Record what's pending so the next launch can reconcile.
      await File(p.join(updatesDir.path, 'pending.json')).writeAsString(
        jsonEncode({
          'version': updateInfo.version,
          'scriptPath': scriptPath,
          'stagedAt': DateTime.now().toIso8601String(),
        }),
      );

      _updateScriptPath = scriptPath;
      _stagedVersion = updateInfo.version;
      onProgress(0.9, 'Update ready!');
      debugPrint('✅ Update staged: $scriptPath');
      return true;
    } catch (e) {
      debugPrint('❌ Error installing update: $e');
      onProgress(0, 'Install preparation failed.');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Launch
  // ---------------------------------------------------------------------------

  /// Start the install script in a detached process. Returns `null` on
  /// success; the caller must `exit(0)` shortly after to release file locks.
  /// Returns an error message on failure.
  Future<String?> launchUpdateScript() async {
    final scriptPath = _updateScriptPath;
    if (scriptPath == null || !File(scriptPath).existsSync()) {
      return 'Update script not found. Please try again.';
    }
    return _installer.launchScript(scriptPath);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Probe writability of [dir] by creating, then deleting, a marker file.
  /// Cheaper and more reliable than parsing ACLs.
  static bool _isWritable(String dir) {
    try {
      final probe = File(p.join(
        dir,
        '.mymeta_write_probe_${DateTime.now().microsecondsSinceEpoch}',
      ));
      probe.writeAsStringSync('ok');
      probe.deleteSync();
      return true;
    } catch (e) {
      debugPrint('⚠️ App dir is not writable: $e');
      return false;
    }
  }

  /// Download with one retry. Most update-time failures are flaky wifi /
  /// laptop sleep; a single retry catches the common case without turning
  /// into an infinite reconnect loop.
  Future<bool> _downloadWithRetry(
    String url,
    String savePath,
    void Function(int, int) onProgress, {
    int attempts = 2,
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        debugPrint('📥 Downloading (attempt $attempt/$attempts) from $url');
        await _createDio(receiveTimeout: const Duration(minutes: 5)).download(
          url,
          savePath,
          onReceiveProgress: onProgress,
        );
        return true;
      } catch (e) {
        debugPrint('⚠️ Download attempt $attempt failed: $e');
        // Clean any partial file before retrying.
        try {
          final partial = File(savePath);
          if (partial.existsSync()) partial.deleteSync();
        } catch (_) {}
        if (attempt >= attempts) return false;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }

  /// Verify the downloaded archive against a SHA256SUMS or per-file `.sha256`
  /// asset. Returns:
  ///   - `match`    when verification succeeded
  ///   - `mismatch` when the digest didn't match — abort the install
  ///   - `absent`   when no sums asset was published — proceed unverified
  Future<_VerifyResult> _verifyDigest(
    String archivePath,
    String? sumsUrl,
    String archiveName,
  ) async {
    if (sumsUrl == null) return _VerifyResult.absent;
    try {
      final response = await _createDio().get<String>(
        sumsUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) return _VerifyResult.absent;

      final expected = _expectedDigestFor(body, archiveName);
      if (expected == null) {
        debugPrint('⚠️ SHA256 sums asset present but no entry for $archiveName');
        return _VerifyResult.absent;
      }

      final actualHex = sha256
          .convert(await File(archivePath).readAsBytes())
          .toString()
          .toLowerCase();
      if (actualHex == expected.toLowerCase()) {
        debugPrint('✅ SHA256 verified: $actualHex');
        return _VerifyResult.match;
      }
      debugPrint('❌ SHA256 mismatch: expected $expected, got $actualHex');
      return _VerifyResult.mismatch;
    } catch (e) {
      debugPrint('⚠️ Failed to fetch/verify SHA256: $e — proceeding unverified');
      return _VerifyResult.absent;
    }
  }

  /// Parse a `SHA256SUMS`-style body (one `<digest>  <filename>` per line)
  /// and return the digest for [archiveName]. Also handles a single-line
  /// `<digest>` file (per-archive `.sha256` convention).
  static String? _expectedDigestFor(String body, String archiveName) {
    final trimmed = body.trim();
    final lines = trimmed.split(RegExp(r'\r?\n'));

    // Single-line "<digest>" or "<digest>  <name>"
    if (lines.length == 1) {
      final parts = lines.first.trim().split(RegExp(r'\s+'));
      if (parts.length == 1 && _looksLikeSha256(parts.first)) {
        return parts.first;
      }
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final digest = parts.first;
      // Allow either "name" or "*name" (binary mode in GNU coreutils).
      final name = parts.sublist(1).join(' ').replaceFirst(RegExp(r'^\*'), '');
      if (name == archiveName && _looksLikeSha256(digest)) return digest;
    }
    return null;
  }

  static bool _looksLikeSha256(String s) =>
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(s);

  /// Extract a `.zip` or `.tar.gz` archive into [extractPath], stripping the
  /// common root folder if all entries share one.
  Future<void> _extractArchive(String archivePath, String extractPath) async {
    debugPrint('📦 Extracting update...');
    final bytes = await File(archivePath).readAsBytes();
    final lower = archivePath.toLowerCase();
    final Archive archive;
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      final tarBytes = GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(tarBytes);
    } else if (lower.endsWith('.tar')) {
      archive = TarDecoder().decodeBytes(bytes);
    } else {
      archive = ZipDecoder().decodeBytes(bytes);
    }
    if (archive.isEmpty) throw Exception('Archive is empty');

    // Detect a single common root folder so we extract `MyMeta-v1.2.3-linux/*`
    // as bare files. If entries don't share a root, extract them as-is.
    final paths = archive
        .where((e) => e.isFile)
        .map((e) => e.name.replaceAll('\\', '/'))
        .toList();
    String? rootFolder;
    if (paths.isNotEmpty) {
      final firstSegment = paths.first.split('/').first;
      final everyoneShares =
          paths.every((path) => path.startsWith('$firstSegment/'));
      if (everyoneShares && firstSegment.isNotEmpty) rootFolder = firstSegment;
    }

    for (final file in archive) {
      if (!file.isFile) continue;
      var name = file.name.replaceAll('\\', '/');
      if (rootFolder != null && name.startsWith('$rootFolder/')) {
        name = name.substring(rootFolder.length + 1);
      }
      if (name.isEmpty) continue;

      final outPath = p.join(extractPath, name);
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content as List<int>);
    }
  }

  /// Find the first asset whose `name` contains [keyContains] (case-insensitive)
  /// and optionally ends with [endsWith].
  Map<String, dynamic>? _findAsset(
    List assets, {
    required String keyContains,
    String? endsWith,
  }) {
    final key = keyContains.toLowerCase();
    final suffix = endsWith?.toLowerCase();
    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (!name.contains(key)) continue;
      if (suffix != null && !name.endsWith(suffix)) continue;
      return asset as Map<String, dynamic>;
    }
    return null;
  }

  Dio _createDio({Duration? receiveTimeout}) => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
          headers: const {
            // GitHub recommends a User-Agent on every API call.
            'User-Agent': 'MyMeta-Updater',
          },
        ),
      );

  /// Semantic version comparison. Returns true if [latest] > [current].
  /// Pre-release suffixes are ignored — `1.2.3-beta` and `1.2.3` compare
  /// equal at the numeric level.
  bool _isNewerVersion(String current, String latest) {
    try {
      final c = _parseVersion(current);
      final l = _parseVersion(latest);
      for (var i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error comparing versions: $e');
      return false;
    }
  }

  /// Parse `1.2.3` or `1.2.3-beta` into `[1, 2, 3]`.
  static List<int> _parseVersion(String version) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version);
    if (match == null) throw FormatException('Invalid version: $version');
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }
}

enum _VerifyResult { match, mismatch, absent }

/// Outcome of reconciling on-disk state against the running version on launch.
class PendingUpdateState {
  /// Update was applied since last launch — celebrate.
  final String? succeededVersion;

  /// Update was attempted but the running version is unchanged — show
  /// diagnostics from [UpdateService.readLastInstallLog].
  final String? failedVersion;

  /// Update is downloaded and waiting for the user to restart.
  final PendingUpdate? pending;

  const PendingUpdateState._({
    this.succeededVersion,
    this.failedVersion,
    this.pending,
  });

  factory PendingUpdateState.none() => const PendingUpdateState._();
  factory PendingUpdateState.succeeded(String version) =>
      PendingUpdateState._(succeededVersion: version);
  factory PendingUpdateState.failed(String version) =>
      PendingUpdateState._(failedVersion: version);
  factory PendingUpdateState.pending(PendingUpdate u) =>
      PendingUpdateState._(pending: u);

  bool get hasSucceeded => succeededVersion != null;
  bool get hasFailed => failedVersion != null;
  bool get hasPending => pending != null;
}
