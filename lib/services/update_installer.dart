import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Strategy for installing a downloaded update.
///
/// MyMeta self-installs on Windows (PowerShell + robocopy, all run hidden).
/// On Linux and macOS, packaging conventions vary too widely for an in-app
/// installer to be reliable across distros / .app bundles / Homebrew /
/// AppImage / etc., so on those platforms we point the user at the GitHub
/// release page and let them update by hand. The check-for-update flow
/// itself is identical on every platform.
///
/// `canSelfInstall` is the single switch the UI keys off to choose between
/// "Update Now" (download + restart) and "Open Download Page".
abstract class UpdateInstaller {
  /// Returns `true` when this installer can fully apply the update without
  /// the user leaving the app.
  bool get canSelfInstall;

  /// Substring matched against GitHub release asset names. Only consulted
  /// when [canSelfInstall] is true.
  String get platformAssetKey;

  /// Archive file extension we expect for the release. Only consulted
  /// when [canSelfInstall] is true.
  String get archiveExtension;

  /// Human-readable platform label for diagnostics and UI strings.
  String get label;

  /// Generate the install script. Only called when [canSelfInstall] is true.
  Future<String> createScript({
    required String sourcePath,
    required String targetPath,
    required String exeBaseName,
    required String scriptDir,
    required int appPid,
  });

  /// Launch the install script as a detached process. Only called when
  /// [canSelfInstall] is true. Returns `null` on success, or an error string
  /// on failure.
  Future<String?> launchScript(String scriptPath);

  factory UpdateInstaller.forCurrentPlatform() {
    if (Platform.isWindows) return WindowsInstaller();
    return RedirectInstaller();
  }
}

// =============================================================================
// Windows — full self-install
// =============================================================================

/// PowerShell-based installer, designed to leave **no visible window** at
/// any stage of the update.
///
/// Three layers of hide-the-window:
///   1. `cmd.exe` is spawned with `ProcessStartMode.detached`, which on
///      Windows sets `CREATE_NO_WINDOW`. cmd cannot allocate a console.
///   2. `start "" /b` runs the child in the same (non-existent) console and
///      sets `CREATE_BREAKAWAY_FROM_JOB`, so the script survives our
///      `exit(0)` even when MyMeta is running under VS Code or Explorer
///      (both set a Job Object with `KILL_ON_JOB_CLOSE`).
///   3. PowerShell is invoked with `-WindowStyle Hidden -NonInteractive
///      -NoProfile`, so even if a console somehow appeared, the PS window
///      would be `SW_HIDE` from the first instruction.
///
/// We use `-File <script>` rather than `-EncodedCommand <base64>` because:
///   - it has no length limit (encoded-command tops out around 32 KB),
///   - `-ExecutionPolicy Bypass` makes it safe against any execution policy,
///   - there's no UTF-16LE / base64 dance to get wrong.
class WindowsInstaller implements UpdateInstaller {
  @override
  bool get canSelfInstall => true;

  @override
  String get platformAssetKey => 'windows';

  @override
  String get archiveExtension => '.zip';

  @override
  String get label => 'Windows';

  @override
  Future<String> createScript({
    required String sourcePath,
    required String targetPath,
    required String exeBaseName,
    required String scriptDir,
    required int appPid,
  }) async {
    final scriptPath = p.join(scriptDir, 'update_mymeta.ps1');
    final logPath = p.join(scriptDir, 'update_mymeta.log');

    // Single-quoted PowerShell strings are literal — backslash paths inside
    // them never need escaping. `$ErrorActionPreference = 'Stop'` turns
    // every non-terminating error into a terminating one, so the `catch`
    // block sees real problems instead of a silent half-update.
    final script = '''
\$ErrorActionPreference = 'Stop'

function Log(\$msg) {
    "[\$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] \$msg" |
        Out-File -Append -Encoding utf8 -FilePath '$logPath'
}

try {
    Log "=== MyMeta Update Started (PID $appPid) ==="
    Log "Source: $sourcePath"
    Log "Target: $targetPath"

    # Wait for the SPECIFIC running process to exit. Targeting by PID
    # avoids the false-positive where a stale or duplicate same-named
    # process would make us wait/skip indefinitely.
    try {
        Wait-Process -Id $appPid -Timeout 60 -ErrorAction Stop
        Log "Process $appPid exited."
    } catch [System.TimeoutException] {
        Log "WARNING: Timed out after 60s waiting for PID $appPid; proceeding."
    } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        Log "Process $appPid was already gone."
    }
    Start-Sleep -Milliseconds 500

    # Copy everything except UserData/. /R:5 /W:2 retries five times with a
    # 2-second wait, which covers the common case of an antivirus briefly
    # locking the new EXE. /NP /NJH /NJS suppress robocopy's chatter so the
    # log file stays readable.
    Log "Copying files..."
    \$output = & robocopy '$sourcePath' '$targetPath' /E /XD UserData /R:5 /W:2 /NP /NJH /NJS 2>&1
    \$rc = \$LASTEXITCODE
    \$output | Out-File -Append -Encoding utf8 -FilePath '$logPath'
    Log "Robocopy exit code: \$rc"

    # robocopy: 0..7 = success (no files copied / files copied / mismatches
    # handled gracefully). 8+ = at least one file failed.
    if (\$rc -ge 8) {
        Log "ERROR: File copy failed (robocopy exit \$rc)"
        exit 1
    }

    Log "Restarting app..."
    Start-Sleep -Seconds 1
    Start-Process -FilePath '$targetPath\\$exeBaseName' -WorkingDirectory '$targetPath'
    Log "=== Update Complete ==="
} catch {
    Log "FATAL: \$(\$_.Exception.Message)"
    Log \$_.ScriptStackTrace
    exit 1
}
''';

    await File(scriptPath).writeAsString(script);
    debugPrint('📜 Update script: $scriptPath');
    debugPrint('📜 Update log:    $logPath');
    return scriptPath;
  }

  @override
  Future<String?> launchScript(String scriptPath) async {
    try {
      // Argument list for `cmd /c`. `start ""` requires the empty-string
      // title because the next token would otherwise be parsed as the title.
      // `/b` keeps the child in the same (non-existent) console session.
      final args = <String>[
        '/c',
        'start',
        '""',
        '/b',
        'powershell.exe',
        '-ExecutionPolicy', 'Bypass',
        '-WindowStyle', 'Hidden',
        '-NonInteractive',
        '-NoProfile',
        '-File', scriptPath,
      ];

      await Process.start(
        'cmd.exe',
        args,
        mode: ProcessStartMode.detached,
      );
      return null;
    } catch (e) {
      debugPrint('❌ Failed to launch Windows update script: $e');
      return 'Could not start installer. Download manually from GitHub.';
    }
  }
}

// =============================================================================
// Linux + macOS — redirect to GitHub releases
// =============================================================================

/// No-self-install installer used on Linux and macOS.
///
/// The check-for-update flow runs normally (we still hit the GitHub API,
/// still compare versions, still parse release notes), but instead of
/// downloading an archive and running a script, the UI offers the user a
/// button that opens the GitHub releases page. They install by hand.
///
/// Rationale: a reliable cross-distro Linux installer would have to handle
/// AppImage, Flatpak, Snap, .deb, .rpm, Pacman, and tarball installs — each
/// with their own filesystem layout and update conventions. On macOS, code
/// signing and Gatekeeper make in-place .app bundle replacement fragile.
/// Both ecosystems already have well-understood manual update flows, so we
/// don't try to second-guess them.
class RedirectInstaller implements UpdateInstaller {
  @override
  bool get canSelfInstall => false;

  // The asset-matching fields are unused by the orchestrator when
  // [canSelfInstall] is false, but interfaces don't allow nullable getters
  // here. Empty strings are fine.
  @override
  String get platformAssetKey => '';

  @override
  String get archiveExtension => '';

  @override
  String get label => Platform.isMacOS ? 'macOS' : 'Linux';

  @override
  Future<String> createScript({
    required String sourcePath,
    required String targetPath,
    required String exeBaseName,
    required String scriptDir,
    required int appPid,
  }) =>
      throw UnsupportedError(
        'RedirectInstaller does not self-install — open the releases page instead.',
      );

  @override
  Future<String?> launchScript(String scriptPath) =>
      throw UnsupportedError(
        'RedirectInstaller does not self-install — open the releases page instead.',
      );
}
