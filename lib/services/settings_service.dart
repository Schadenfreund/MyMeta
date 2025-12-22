import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class SettingsService with ChangeNotifier {
  // Defaults
  ThemeMode _themeMode = ThemeMode.dark;
  String _seriesFormat =
      "{series_name} - S{season_number}E{episode_number} - {episode_title}";
  String _movieFormat = "{movie_name}";
  List<String> _excludedFolders = [];
  bool _filenameAnalysisOnly = false;
  String _tmdbApiKey = "";
  String _omdbApiKey = "";
  String _metadataSource = "tmdb";
  Color _accentColor = const Color(0xFFEC4899); // Pink default
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

  ThemeMode get themeMode => _themeMode;
  String get seriesFormat => _seriesFormat;
  String get movieFormat => _movieFormat;
  List<String> get excludedFolders => _excludedFolders;
  bool get filenameAnalysisOnly => _filenameAnalysisOnly;
  String get tmdbApiKey => _tmdbApiKey;
  String get omdbApiKey => _omdbApiKey;
  String get metadataSource => _metadataSource;
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

      // API Keys
      _tmdbApiKey = data['tmdb_api_key'] ?? "";
      _omdbApiKey = data['omdb_api_key'] ?? "";
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

      await checkToolAvailability();
      notifyListeners();
      debugPrint('✅ Settings loaded from UserData folder');
    } catch (e) {
      debugPrint('⚠️  Error loading settings: $e');
      notifyListeners();
    }
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
        'tmdb_api_key': _tmdbApiKey,
        'omdb_api_key': _omdbApiKey,
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
    await _saveSettings();
    await checkToolAvailability();
    notifyListeners();
  }

  Future<void> setMkvpropeditPath(String path) async {
    _mkvpropeditPath = path;
    await _saveSettings();
    await checkToolAvailability();
    notifyListeners();
  }

  Future<void> setAtomicParsleyPath(String path) async {
    _atomicparsleyPath = path;
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
    _tmdbApiKey = "";
    _omdbApiKey = "";
    _metadataSource = "tmdb";
    _accentColor = const Color(0xFFEC4899); // Pink default
    _ffmpegPath = "";
    _mkvpropeditPath = "";
    _atomicparsleyPath = "";
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
    try {
      final userDataPath = await _getUserDataPath();
      final toolsDir = p.join(userDataPath, 'tools');

      String subDir = '';
      if (toolName == 'ffmpeg')
        subDir = 'ffmpeg';
      else if (toolName == 'mkvpropedit')
        subDir = 'mkvtoolnix';
      else if (toolName == 'AtomicParsley') subDir = 'atomicparsley';

      final subDirPath = p.join(toolsDir, subDir);
      final subDirectory = Directory(subDirPath);

      if (!subDirectory.existsSync()) return;

      // Find the executable
      String? foundPath;

      // 1. Direct
      if (File(p.join(subDirPath, '$toolName.exe')).existsSync()) {
        foundPath = subDirPath;
      }
      // 2. Bin
      else if (File(p.join(subDirPath, 'bin', '$toolName.exe')).existsSync()) {
        foundPath = p.join(subDirPath, 'bin');
      }
      // 3. Recursive
      else {
        try {
          final entities = subDirectory.listSync(recursive: true);
          for (var entity in entities) {
            if (entity is File &&
                p.basename(entity.path).toLowerCase() ==
                    '$toolName.exe'.toLowerCase()) {
              foundPath = p.dirname(entity.path);
              break;
            }
          }
        } catch (_) {}
      }

      if (foundPath != null) {
        debugPrint('✅ Auto-fixed path for $toolName: $foundPath');
        if (toolName == 'ffmpeg') {
          _ffmpegPath = foundPath;
          _isFFmpegAvailable = true;
        } else if (toolName == 'mkvpropedit') {
          _mkvpropeditPath = foundPath;
          _isMkvpropeditAvailable = true;
        } else if (toolName == 'AtomicParsley') {
          _atomicparsleyPath = foundPath;
          _isAtomicParsleyAvailable = true;
        }
        await _saveSettings();
      }
    } catch (e) {
      debugPrint('Auto-fix failed for $toolName: $e');
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
}
