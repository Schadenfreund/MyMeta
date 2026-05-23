import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';
import 'tool_resolver.dart';

class SettingsService with ChangeNotifier {
  // Defaults
  ThemeMode _themeMode = ThemeMode.dark;
  String _seriesFormat =
      "{series_name} - S{season_number}E{episode_number} - {episode_title}";
  String _movieFormat = "{movie_name}";
  List<String> _excludedFolders = [];
  bool _filenameAnalysisOnly = false;
  bool _useSeasonPoster = false;
  int _episodeDigits = 2; // Padding width for episode numbers (2 = E01, 3 = E001, 4 = E0001)
  int _seasonDigits = 2;  // Padding width for season numbers  (2 = S01, 3 = S001)
  bool _doRename = true;                  // Rename file on disk using the naming template
  bool _doCover = true;                   // Remove old cover and embed new one from TMDB
  bool _doEmbedFields = true;             // Write metadata fields (description, genre, actors, etc.)
  bool _removeAllCoversBeforeEmbed = false; // Remove ALL image attachments before embedding (vs. only "cover*" filenames)
  String _tmdbApiKey = "";
  String _omdbApiKey = "";
  String _anidbClientId = "";
  String _metadataSource = "tmdb";
  Color _accentColor = const Color(0xFFBE0AB4); // Custom Pink default
  String _ffmpegPath = ""; // Stores the folder path
  String _mkvpropeditPath = "";
  String _atomicparsleyPath = "";

  // Lifetime Statistics
  int _lifetimeTvShowsMatched = 0;
  int _lifetimeMoviesMatched = 0;

  // Configurable Download URLs
  String _ffmpegUrl =
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip';
  String _mkvtoolnixUrl =
      'https://mkvtoolnix.download/windows/releases/96.0/mkvtoolnix-64-bit-96.0.7z';
  String _atomicParsleyUrl =
      'https://github.com/wez/atomicparsley/releases/download/20240608.083822.1ed9031/AtomicParsleyWindows.zip';

  // Tool Availability State
  bool _isFFmpegAvailable = false;
  bool _isMkvpropeditAvailable = false;
  bool _isAtomicParsleyAvailable = false;
  bool _isCheckingTools = false;

  // Update flow state. Persisted so the banner survives app restarts.
  String _skippedUpdateVersion = '';
  DateTime? _lastUpdateCheckAt;

  ThemeMode get themeMode => _themeMode;
  String get seriesFormat => _seriesFormat;
  String get movieFormat => _movieFormat;
  List<String> get excludedFolders => _excludedFolders;
  bool get filenameAnalysisOnly => _filenameAnalysisOnly;
  bool get useSeasonPoster => _useSeasonPoster;
  int get episodeDigits => _episodeDigits;
  int get seasonDigits => _seasonDigits;
  bool get doRename => _doRename;
  bool get doCover => _doCover;
  bool get doEmbedFields => _doEmbedFields;
  bool get removeAllCoversBeforeEmbed => _removeAllCoversBeforeEmbed;
  String get tmdbApiKey => _tmdbApiKey;
  String get omdbApiKey => _omdbApiKey;
  String get anidbClientId => _anidbClientId;
  String get metadataSource => _metadataSource;
  bool get hasAnyMetadataKey =>
      _tmdbApiKey.isNotEmpty || _omdbApiKey.isNotEmpty || _anidbClientId.isNotEmpty;

  /// Returns [preferred] if it has a configured API key, otherwise returns
  /// the first provider that does. Falls back to [preferred] if none are set.
  static String resolveMetadataSource(String preferred, SettingsService s) {
    final keys = {'tmdb': s._tmdbApiKey, 'omdb': s._omdbApiKey, 'anidb': s._anidbClientId};
    if (keys[preferred]?.isNotEmpty == true) return preferred;
    for (final e in keys.entries) {
      if (e.value.isNotEmpty) return e.key;
    }
    return preferred;
  }
  Color get accentColor => _accentColor;
  String get ffmpegPath => _ffmpegPath;
  String get mkvpropeditPath => _mkvpropeditPath;
  String get atomicparsleyPath => _atomicparsleyPath;

  String get ffmpegUrl => _ffmpegUrl;
  String get mkvtoolnixUrl => _mkvtoolnixUrl;
  String get atomicParsleyUrl => _atomicParsleyUrl;

  bool get isFFmpegAvailable => _isFFmpegAvailable;
  bool get isMkvpropeditAvailable => _isMkvpropeditAvailable;
  bool get isAtomicParsleyAvailable => _isAtomicParsleyAvailable;
  bool get isCheckingTools => _isCheckingTools;

  int get lifetimeTvShowsMatched => _lifetimeTvShowsMatched;
  int get lifetimeMoviesMatched => _lifetimeMoviesMatched;

  String get skippedUpdateVersion => _skippedUpdateVersion;
  DateTime? get lastUpdateCheckAt => _lastUpdateCheckAt;

  /// Get the portable UserData folder path (next to executable)
  Future<String> _getUserDataPath() async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    final userDataDir = p.join(exeDir, 'UserData');

    // Create directory if it doesn't exist
    final dir = Directory(userDataDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    return userDataDir;
  }

  /// Get the settings file path
  Future<File> _getSettingsFile() async {
    final userDataPath = await _getUserDataPath();
    return File(p.join(userDataPath, 'settings.json'));
  }

  Future<void> loadSettings() async {
    try {
      final settingsFile = await _getSettingsFile();

      if (!settingsFile.existsSync()) {
        debugPrint('Settings file not found, using defaults');
        await checkToolAvailability();
        notifyListeners();
        return;
      }

      final jsonString = await settingsFile.readAsString();
      final Map<String, dynamic> data = json.decode(jsonString);

      // Theme
      if (data['theme'] == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }

      // Formats
      _seriesFormat = data['series_format'] ?? _seriesFormat;
      _movieFormat = data['movie_format'] ?? _movieFormat;

      // Excluded Folders
      if (data['excluded_folders'] != null) {
        _excludedFolders = List<String>.from(data['excluded_folders']);
      }

      // Filename Analysis Only
      _filenameAnalysisOnly = data['filename_analysis_only'] ?? false;
      _useSeasonPoster = data['use_season_poster'] ?? false;
      _episodeDigits = data['episode_digits'] ?? 2;
      _seasonDigits = data['season_digits'] ?? 2;
      // Migrate old single metadata_only flag: if it was true, doRename should be false.
      final legacyMetadataOnly = data['metadata_only'] as bool? ?? false;
      _doRename = data['do_rename'] as bool? ?? !legacyMetadataOnly;
      _doCover = data['do_cover'] as bool? ?? true;
      _doEmbedFields = data['do_embed_fields'] as bool? ?? true;
      _removeAllCoversBeforeEmbed = data['remove_all_covers_before_embed'] as bool? ?? false;

      // API Keys
      _tmdbApiKey = data['tmdb_api_key'] ?? "";
      _omdbApiKey = data['omdb_api_key'] ?? "";
      _anidbClientId = data['anidb_client_id'] ?? "";
      _metadataSource = data['metadata_source'] ?? "tmdb";

      // Accent Color
      if (data['accent_color'] != null) {
        _accentColor = Color(data['accent_color'] as int);
      }

      // Tool Paths
      _ffmpegPath = data['ffmpeg_path'] ?? "";
      _mkvpropeditPath = data['mkvpropedit_path'] ?? "";
      _atomicparsleyPath = data['atomicparsley_path'] ?? "";

      // Download URLs
      _ffmpegUrl = data['ffmpeg_url'] ?? _ffmpegUrl;
      _mkvtoolnixUrl = data['mkvtoolnix_url'] ?? _mkvtoolnixUrl;
      _atomicParsleyUrl = data['atomicparsley_url'] ?? _atomicParsleyUrl;

      // Lifetime Statistics
      _lifetimeTvShowsMatched = data['lifetime_tv_shows_matched'] ?? 0;
      _lifetimeMoviesMatched = data['lifetime_movies_matched'] ?? 0;

      // Update flow state
      _skippedUpdateVersion = data['skipped_update_version'] ?? '';
      final lastCheckIso = data['last_update_check_at'] as String?;
      if (lastCheckIso != null) {
        _lastUpdateCheckAt = DateTime.tryParse(lastCheckIso);
      }

      await checkToolAvailability();
      notifyListeners();
      debugPrint('✅ Settings loaded from UserData folder');
    } catch (e) {
      debugPrint('⚠️  Error loading settings: $e');
      notifyListeners();
    }
  }

  /// Clear the stored path and availability flag for [toolName].
  void _clearToolPath(String toolName) {
    switch (toolName.toLowerCase()) {
      case 'ffmpeg':
        _ffmpegPath = '';
        _isFFmpegAvailable = false;
        break;
      case 'mkvpropedit':
        _mkvpropeditPath = '';
        _isMkvpropeditAvailable = false;
        break;
      case 'atomicparsley':
        _atomicparsleyPath = '';
        _isAtomicParsleyAvailable = false;
        break;
    }
  }

  /// Validate and fix tool paths (for portable app - critical on startup).
  /// Ensures paths are still valid after the app folder is moved.
  Future<void> validateAndFixToolPaths() async {
    debugPrint('🔍 Validating tool paths...');

    final pathsToValidate = {
      'FFmpeg': _ffmpegPath,
      'mkvpropedit': _mkvpropeditPath,
      'AtomicParsley': _atomicparsleyPath,
    };

    final List<String> invalidTools = [];
    final List<String> fixedTools = [];

    for (final entry in pathsToValidate.entries) {
      final toolName = entry.key;
      final savedPath = entry.value;
      if (savedPath.isEmpty) continue;

      // A path is invalid if the directory is gone, or if the executable
      // isn't reachable directly or via a bin/ subdirectory.
      bool pathInvalid = !Directory(savedPath).existsSync();
      if (!pathInvalid) {
        final exeName = toolName == 'mkvpropedit'
            ? 'mkvpropedit.exe'
            : '${toolName.toLowerCase()}.exe';
        pathInvalid = !File(p.join(savedPath, exeName)).existsSync() &&
            !File(p.join(savedPath, 'bin', exeName)).existsSync();
        if (pathInvalid) {
          debugPrint('⚠️  Path exists but $exeName not found in: $savedPath');
        }
      } else {
        debugPrint('⚠️  Saved path for $toolName no longer exists: $savedPath');
      }

      if (!pathInvalid) continue;
      invalidTools.add(toolName);

      if (await _tryAutoFixInvalidPath(toolName.toLowerCase())) {
        fixedTools.add(toolName);
        debugPrint('✅ Auto-fixed $toolName path');
      } else {
        _clearToolPath(toolName);
        debugPrint('❌ Cleared invalid path for $toolName');
      }
    }

    if (invalidTools.isEmpty) {
      debugPrint('✅ All tool paths valid');
      return;
    }

    await _saveSettings();
    debugPrint('💾 Saved updated tool paths');
    if (fixedTools.isNotEmpty) {
      debugPrint('✅ Auto-fixed tools: ${fixedTools.join(", ")}');
    }
    final stillInvalid =
        invalidTools.where((t) => !fixedTools.contains(t)).toList();
    if (stillInvalid.isNotEmpty) {
      debugPrint('⚠️  Tools need reconfiguration: ${stillInvalid.join(", ")}');
    }
  }

  /// Search UserData/tools/<subdir> for `<toolName>.exe`, trying the install
  /// root, a `bin/` subdirectory, then a full recursive scan. Returns the
  /// directory containing the executable, or null.
  Future<String?> _findToolInUserData(String toolName) async {
    try {
      final userDataPath = await _getUserDataPath();
      final subDirPath = p.join(
        userDataPath,
        'tools',
        ToolConfig.getSubdirectory(toolName),
      );
      final subDirectory = Directory(subDirPath);
      if (!subDirectory.existsSync()) return null;

      final exeName = '$toolName.exe';
      if (File(p.join(subDirPath, exeName)).existsSync()) return subDirPath;
      if (File(p.join(subDirPath, 'bin', exeName)).existsSync()) {
        return p.join(subDirPath, 'bin');
      }

      try {
        for (final entity in subDirectory.listSync(recursive: true)) {
          if (entity is File &&
              p.basename(entity.path).toLowerCase() == exeName.toLowerCase()) {
            return p.dirname(entity.path);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error searching UserData for $toolName: $e');
    }
    return null;
  }

  /// Apply a discovered tool path to the matching settings field and mark it
  /// available. Returns false if [toolName] is not recognised.
  bool _applyFoundToolPath(String toolName, String foundPath) {
    switch (toolName.toLowerCase()) {
      case 'ffmpeg':
        _ffmpegPath = foundPath;
        _isFFmpegAvailable = true;
        return true;
      case 'mkvpropedit':
        _mkvpropeditPath = foundPath;
        _isMkvpropeditAvailable = true;
        return true;
      case 'atomicparsley':
        _atomicparsleyPath = foundPath;
        _isAtomicParsleyAvailable = true;
        return true;
    }
    return false;
  }

  /// Try to auto-fix an invalid tool path by searching UserData/tools.
  Future<bool> _tryAutoFixInvalidPath(String toolName) async {
    final foundPath = await _findToolInUserData(toolName);
    if (foundPath == null) return false;
    return _applyFoundToolPath(toolName, foundPath);
  }

  Future<void> _saveSettings() async {
    try {
      final settingsFile = await _getSettingsFile();

      final Map<String, dynamic> data = {
        'theme': _themeMode == ThemeMode.light ? 'light' : 'dark',
        'series_format': _seriesFormat,
        'movie_format': _movieFormat,
        'excluded_folders': _excludedFolders,
        'filename_analysis_only': _filenameAnalysisOnly,
        'use_season_poster': _useSeasonPoster,
        'episode_digits': _episodeDigits,
        'season_digits': _seasonDigits,
        'do_rename': _doRename,
        'do_cover': _doCover,
        'do_embed_fields': _doEmbedFields,
        'remove_all_covers_before_embed': _removeAllCoversBeforeEmbed,
        'tmdb_api_key': _tmdbApiKey,
        'omdb_api_key': _omdbApiKey,
        'anidb_client_id': _anidbClientId,
        'metadata_source': _metadataSource,
        'accent_color': _accentColor.toARGB32(),
        'ffmpeg_path': _ffmpegPath,
        'mkvpropedit_path': _mkvpropeditPath,
        'atomicparsley_path': _atomicparsleyPath,
        'ffmpeg_url': _ffmpegUrl,
        'mkvtoolnix_url': _mkvtoolnixUrl,
        'atomicparsley_url': _atomicParsleyUrl,
        'lifetime_tv_shows_matched': _lifetimeTvShowsMatched,
        'lifetime_movies_matched': _lifetimeMoviesMatched,
        'skipped_update_version': _skippedUpdateVersion,
        if (_lastUpdateCheckAt != null)
          'last_update_check_at': _lastUpdateCheckAt!.toIso8601String(),
      };

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final jsonString = jsonEncoder.convert(data);
      await settingsFile.writeAsString(jsonString);

      debugPrint('💾 Settings saved to UserData folder');
    } catch (e) {
      debugPrint('⚠️  Error saving settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setSeriesFormat(String format) async {
    _seriesFormat = format;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMovieFormat(String format) async {
    _movieFormat = format;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> addExcludedFolder(String path) async {
    if (!_excludedFolders.contains(path)) {
      _excludedFolders.add(path);
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> removeExcludedFolder(String path) async {
    _excludedFolders.remove(path);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setFilenameAnalysisOnly(bool value) async {
    _filenameAnalysisOnly = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDoRename(bool value) async {
    _doRename = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDoCover(bool value) async {
    _doCover = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDoEmbedFields(bool value) async {
    _doEmbedFields = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setRemoveAllCoversBeforeEmbed(bool value) async {
    _removeAllCoversBeforeEmbed = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setUseSeasonPoster(bool value) async {
    _useSeasonPoster = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEpisodeDigits(int digits) async {
    _episodeDigits = digits.clamp(2, 4);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setSeasonDigits(int digits) async {
    _seasonDigits = digits.clamp(2, 3);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setTmdbApiKey(String key) async {
    _tmdbApiKey = key;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setOmdbApiKey(String key) async {
    _omdbApiKey = key;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAnidbClientId(String id) async {
    _anidbClientId = id;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMetadataSource(String source) async {
    _metadataSource = source;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setFFmpegPath(String path) async {
    _ffmpegPath = path;
    ToolResolver.invalidate('ffmpeg');
    ToolResolver.invalidate('ffprobe');
    await _saveSettings();
    await checkToolAvailability();
    notifyListeners();
  }

  Future<void> setMkvpropeditPath(String path) async {
    _mkvpropeditPath = path;
    ToolResolver.invalidate('mkvpropedit');
    await _saveSettings();
    await checkToolAvailability();
    notifyListeners();
  }

  Future<void> setAtomicParsleyPath(String path) async {
    _atomicparsleyPath = path;
    ToolResolver.invalidate('AtomicParsley');
    await _saveSettings();
    await checkToolAvailability();
    notifyListeners();
  }

  Future<void> setFFmpegUrl(String url) async {
    _ffmpegUrl = url;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMkvtoolnixUrl(String url) async {
    _mkvtoolnixUrl = url;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAtomicParsleyUrl(String url) async {
    _atomicParsleyUrl = url;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> resetSettings() async {
    _themeMode = ThemeMode.dark;
    _seriesFormat =
        "{series_name} - S{season_number}E{episode_number} - {episode_title}";
    _movieFormat = "{movie_name}";
    _excludedFolders = [];
    _filenameAnalysisOnly = false;
    _useSeasonPoster = false;
    _doRename = true;
    _doCover = true;
    _doEmbedFields = true;
    _removeAllCoversBeforeEmbed = false;
    _tmdbApiKey = "";
    _omdbApiKey = "";
    _anidbClientId = "";
    _metadataSource = "tmdb";
    _accentColor = const Color(0xFFBE0AB4); // Custom Pink default
    _ffmpegPath = "";
    _mkvpropeditPath = "";
    _atomicparsleyPath = "";
    _skippedUpdateVersion = "";
    _lastUpdateCheckAt = null;
    ToolResolver.clearCache();
    _ffmpegUrl =
        'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip';
    _mkvtoolnixUrl =
        'https://mkvtoolnix.download/windows/releases/96.0/mkvtoolnix-64-bit-96.0.7z';
    _atomicParsleyUrl =
        'https://github.com/wez/atomicparsley/releases/download/20240608.083822.1ed9031/AtomicParsleyWindows.zip';

    await _saveSettings();
    await checkToolAvailability();
    notifyListeners();
  }

  /// Check availability of all tools
  Future<void> checkToolAvailability() async {
    if (_isCheckingTools) return;

    _isCheckingTools = true;
    notifyListeners();

    _isFFmpegAvailable = await _isToolAvailable('ffmpeg');
    _isMkvpropeditAvailable = await _isToolAvailable('mkvpropedit');
    _isAtomicParsleyAvailable = await _isToolAvailable('AtomicParsley');

    // Auto-fix logic: if tool is unavailable but found in default 'tools' dir, update path automatically
    if (!_isFFmpegAvailable) await _tryAutoFixPath('ffmpeg');
    if (!_isMkvpropeditAvailable) await _tryAutoFixPath('mkvpropedit');
    if (!_isAtomicParsleyAvailable) await _tryAutoFixPath('AtomicParsley');

    _isCheckingTools = false;
    notifyListeners();
  }

  Future<void> _tryAutoFixPath(String toolName) async {
    final foundPath = await _findToolInUserData(toolName);
    if (foundPath == null) return;
    if (_applyFoundToolPath(toolName, foundPath)) {
      debugPrint('✅ Auto-fixed path for $toolName: $foundPath');
      await _saveSettings();
    }
  }

  /// Internal check for a single tool
  Future<bool> _isToolAvailable(String toolName) async {
    String? customPath;

    // Get custom path based on tool name
    if (toolName == 'ffmpeg') {
      customPath = _ffmpegPath;
    } else if (toolName == 'mkvpropedit') {
      customPath = _mkvpropeditPath;
    } else if (toolName == 'AtomicParsley') {
      customPath = _atomicparsleyPath;
    }

    // Try custom path from settings (if configured)
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (dir.existsSync()) {
        // 1. Try finding the tool directly in the configured folder
        final directPath = p.join(customPath, '$toolName.exe');
        if (File(directPath).existsSync()) {
          return true;
        }

        // 2. Try finding it in a 'bin' subdirectory
        final binPath = p.join(customPath, 'bin', '$toolName.exe');
        if (File(binPath).existsSync()) {
          return true;
        }

        // 3. Recursive search (Robust fallback)
        try {
          final entities = dir.listSync(recursive: true, followLinks: false);
          for (final entity in entities) {
            if (entity is File) {
              if (p.basename(entity.path).toLowerCase() ==
                  '$toolName.exe'.toLowerCase()) {
                return true;
              }
            }
          }
        } catch (_) {}
      }
    }

    // 4. Try bundled in app directory (portable mode - UserData/tools)
    // This is essentially redundant with AutoFix but meant for detection of implicitly available tools
    // But since we want to populate the path field, AutoFix is better.
    // We leave this here just to return 'true' if the path IS empty but tool is present (e.g. fresh install)

    try {
      final userDataPath = await _getUserDataPath();
      final toolsDir = p.join(userDataPath, 'tools');

      // Standard subdirs
      String subDir = '';
      if (toolName == 'ffmpeg')
        subDir = 'ffmpeg';
      else if (toolName == 'mkvpropedit')
        subDir = 'mkvtoolnix';
      else if (toolName == 'AtomicParsley') subDir = 'atomicparsley';

      final subDirPath = p.join(toolsDir, subDir);
      final subDirectory = Directory(subDirPath);

      if (subDirectory.existsSync()) {
        if (File(p.join(subDirPath, '$toolName.exe')).existsSync()) return true;

        if (File(p.join(subDirPath, 'bin', '$toolName.exe')).existsSync())
          return true;

        try {
          final entities = subDirectory.listSync(recursive: true);
          for (var entity in entities) {
            if (entity is File &&
                p.basename(entity.path).toLowerCase() ==
                    '$toolName.exe'.toLowerCase()) {
              return true;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return false;
  }

  /// Increment lifetime TV show match count
  Future<void> incrementTvShowMatches(int count) async {
    _lifetimeTvShowsMatched += count;
    await _saveSettings();
    notifyListeners();
  }

  /// Increment lifetime movie match count
  Future<void> incrementMovieMatches(int count) async {
    _lifetimeMoviesMatched += count;
    await _saveSettings();
    notifyListeners();
  }

  /// Mark a specific update version as "do not pester me about this one
  /// again." The banner is suppressed until a strictly newer version ships.
  Future<void> setSkippedUpdateVersion(String version) async {
    _skippedUpdateVersion = version;
    await _saveSettings();
    notifyListeners();
  }

  /// Record the timestamp of the most recent update check. Used to throttle
  /// the silent background check on app startup.
  Future<void> setLastUpdateCheckAt(DateTime when) async {
    _lastUpdateCheckAt = when;
    await _saveSettings();
    // No notifyListeners — this is a background bookkeeping detail.
  }
}
