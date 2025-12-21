import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class SettingsService with ChangeNotifier {
  // Defaults
  ThemeMode _themeMode = ThemeMode.dark;
  String _seriesFormat =
      "{series_name} - S{season_number}E{episode_number} - {episode_title}";
  String _movieFormat = "{movie_name} ({year})";
  List<String> _excludedFolders = [];
  bool _filenameAnalysisOnly = false;
  String _tmdbApiKey = "";
  String _omdbApiKey = "";
  String _metadataSource = "tmdb";
  Color _accentColor = const Color(0xFF6366F1); // Indigo default
  String _ffmpegPath = ""; // Stores the folder path
  String _mkvpropeditPath = "";
  String _atomicparsleyPath = "";

  ThemeMode get themeMode => _themeMode;
  String get seriesFormat => _seriesFormat;
  String get movieFormat => _movieFormat;
  List<String> get excludedFolders => _excludedFolders;
  bool get filenameAnalysisOnly => _filenameAnalysisOnly;
  String get tmdbApiKey => _tmdbApiKey;
  String get omdbApiKey => _omdbApiKey;
  String get metadataSource => _metadataSource;
  Color get accentColor => _accentColor;
  String get ffmpegPath => _ffmpegPath; // Returns folder path
  String get mkvpropeditPath => _mkvpropeditPath;
  String get atomicparsleyPath => _atomicparsleyPath;

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
    notifyListeners();
  }

  Future<void> setMkvpropeditPath(String path) async {
    _mkvpropeditPath = path;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAtomicParsleyPath(String path) async {
    _atomicparsleyPath = path;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> resetSettings() async {
    _themeMode = ThemeMode.dark;
    _seriesFormat = "{series_name} - S{season_number}E{episode_number} - {episode_title}";
    _movieFormat = "{movie_name} ({year})";
    _excludedFolders = [];
    _filenameAnalysisOnly = false;
    _tmdbApiKey = "";
    _omdbApiKey = "";
    _metadataSource = "tmdb";
    _accentColor = const Color(0xFF6366F1);
    _ffmpegPath = "";
    _mkvpropeditPath = "";
    _atomicparsleyPath = "";

    await _saveSettings();
    notifyListeners();
  }
}
