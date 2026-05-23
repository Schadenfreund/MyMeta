import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';
import 'settings_service.dart';

/// Single source of truth for locating external CLI tools used by MyMeta
/// (`ffmpeg`, `ffprobe`, `mkvpropedit`, `AtomicParsley`).
///
/// Resolution order, stopping at the first hit:
///   1. `UserData/tools/<subdir>/` — direct → `bin/` → recursive scan
///   2. Custom user-configured folder ([SettingsService] field for that tool)
///       — direct → `bin/` → recursive scan
///   3. Bundled next to the application executable (legacy install layout)
///   4. The bare tool name (relies on the system PATH at exec time)
///      — only when [usePathFallback] is `true`
///
/// Resolved paths are cached for the lifetime of the process. Callers that
/// mutate tool paths (i.e. [SettingsService.setFFmpegPath] et al.) must call
/// [invalidate] so the next lookup is fresh.
///
/// All public methods are platform-agnostic: on Windows the executables carry
/// a `.exe` extension, on Linux/macOS they do not.
class ToolResolver {
  static final Map<String, String> _cache = {};

  /// Drop every cached entry. Call when settings are reset wholesale.
  static void clearCache() => _cache.clear();

  /// Drop the cached entry for a single tool. Call after the user changes the
  /// configured folder for that tool.
  static void invalidate(String toolName) =>
      _cache.remove(toolName.toLowerCase());

  /// Locate the executable for [toolName]. Returns the absolute path, or the
  /// bare tool name when [usePathFallback] is true and nothing else matched,
  /// or `null` when the tool cannot be found.
  ///
  /// [toolName] is case-insensitive at the cache layer but is preserved for
  /// the executable filename so we can run `AtomicParsley.exe` correctly on
  /// case-sensitive filesystems.
  static Future<String?> resolveExe(
    String toolName, {
    SettingsService? settings,
    bool usePathFallback = false,
  }) async {
    final key = toolName.toLowerCase();
    final cached = _cache[key];
    if (cached != null) return cached;

    final exeName = _exeNameFor(toolName);

    final fromUserData = _searchUserData(toolName, exeName);
    if (fromUserData != null) return _cache[key] = fromUserData;

    final customRoot = _customPathFor(toolName, settings);
    if (customRoot != null && customRoot.isNotEmpty) {
      final fromCustom = _searchFolder(customRoot, exeName);
      if (fromCustom != null) return _cache[key] = fromCustom;
    }

    try {
      final bundled =
          p.join(p.dirname(Platform.resolvedExecutable), exeName);
      if (File(bundled).existsSync()) return _cache[key] = bundled;
    } catch (e) {
      debugPrint('ToolResolver: bundled lookup failed for $toolName: $e');
    }

    if (usePathFallback) {
      // Don't cache the PATH fallback — if the user later configures a real
      // path we want the next call to pick it up.
      return toolName;
    }

    return null;
  }

  /// Folder that contains the resolved executable, or `null` if the tool
  /// could not be located. Used by [SettingsService] auto-fix, which stores
  /// directories rather than full executable paths.
  static Future<String?> resolveContainingDir(
    String toolName, {
    SettingsService? settings,
  }) async {
    final exe = await resolveExe(toolName, settings: settings);
    if (exe == null || exe == toolName) return null; // not a real path
    return p.dirname(exe);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Look for the tool under `UserData/tools/<subdir>/`.
  static String? _searchUserData(String toolName, String exeName) {
    try {
      final base = p.join(
        p.dirname(Platform.resolvedExecutable),
        'UserData',
        'tools',
        ToolConfig.getSubdirectory(toolName),
      );
      return _searchFolder(base, exeName);
    } catch (e) {
      debugPrint('ToolResolver: UserData search failed for $toolName: $e');
      return null;
    }
  }

  /// Search [folder]: direct → `bin/` → recursive.
  static String? _searchFolder(String folder, String exeName) {
    final dir = Directory(folder);
    if (!dir.existsSync()) return null;

    final direct = p.join(folder, exeName);
    if (File(direct).existsSync()) return direct;

    final bin = p.join(folder, 'bin', exeName);
    if (File(bin).existsSync()) return bin;

    try {
      final wanted = exeName.toLowerCase();
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File &&
            p.basename(entity.path).toLowerCase() == wanted) {
          return entity.path;
        }
      }
    } catch (e) {
      debugPrint('ToolResolver: recursive scan failed in $folder: $e');
    }
    return null;
  }

  /// Map a tool name to the user-configured folder from [SettingsService].
  /// `ffprobe` shares a folder with `ffmpeg`.
  static String? _customPathFor(String toolName, SettingsService? s) {
    if (s == null) return null;
    switch (toolName.toLowerCase()) {
      case 'ffmpeg':
      case 'ffprobe':
        return s.ffmpegPath;
      case 'mkvpropedit':
        return s.mkvpropeditPath;
      case 'atomicparsley':
        return s.atomicparsleyPath;
    }
    return null;
  }

  /// Append `.exe` on Windows; leave bare on other platforms.
  static String _exeNameFor(String toolName) =>
      Platform.isWindows ? '$toolName.exe' : toolName;
}
