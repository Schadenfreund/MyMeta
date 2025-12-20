import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService with ChangeNotifier {
  static const String _themeKey = 'theme';
  static const String _seriesFormatKey = 'series_format';
  static const String _movieFormatKey = 'movie_format';
  static const String _excludedFoldersKey = 'excluded_folders';
  static const String _filenameAnalysisOnlyKey = 'filename_analysis_only';
  static const String _tmdbApiKeyKey = 'tmdb_api_key'; // NEW
  static const String _omdbApiKeyKey = 'omdb_api_key';
  static const String _metadataSourceKey =
      'metadata_source'; // 'tmdb' or 'omdb'
  static const String _accentColorKey = 'accent_color';

  late SharedPreferences _prefs;

  // Defaults
  ThemeMode _themeMode = ThemeMode.dark;
  String _seriesFormat =
      "{series_name} - S{season_number}E{episode_number} - {episode_title}";
  String _movieFormat = "{movie_name} ({year})";
  List<String> _excludedFolders = [];
  bool _filenameAnalysisOnly = false;
  String _tmdbApiKey = ""; // NEW
  String _omdbApiKey = "";
  String _metadataSource = "tmdb";
  Color _accentColor = const Color(0xFF6366F1); // Indigo default

  ThemeMode get themeMode => _themeMode;
  String get seriesFormat => _seriesFormat;
  String get movieFormat => _movieFormat;
  List<String> get excludedFolders => _excludedFolders;
  bool get filenameAnalysisOnly => _filenameAnalysisOnly;
  String get tmdbApiKey => _tmdbApiKey; // NEW
  String get omdbApiKey => _omdbApiKey;
  String get metadataSource => _metadataSource;
  Color get accentColor => _accentColor;

  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    // Theme
    String? themeStr = _prefs.getString(_themeKey);
    if (themeStr == 'Light')
      _themeMode = ThemeMode.light;
    else
      _themeMode = ThemeMode.dark;

    // Formats
    _seriesFormat = _prefs.getString(_seriesFormatKey) ?? _seriesFormat;
    _movieFormat = _prefs.getString(_movieFormatKey) ?? _movieFormat;

    // Excluded Folders
    _excludedFolders = _prefs.getStringList(_excludedFoldersKey) ?? [];

    // Filename Analysis Only
    _filenameAnalysisOnly = _prefs.getBool(_filenameAnalysisOnlyKey) ?? false;

    // API Key
    _tmdbApiKey = _prefs.getString(_tmdbApiKeyKey) ?? "";
    _omdbApiKey = _prefs.getString(_omdbApiKeyKey) ?? "";
    _metadataSource = _prefs.getString(_metadataSourceKey) ?? "tmdb";

    // Accent Color
    int? colorValue = _prefs.getInt(_accentColorKey);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(
        _themeKey, mode == ThemeMode.light ? 'Light' : 'Dark');
    notifyListeners();
  }

  Future<void> setSeriesFormat(String format) async {
    _seriesFormat = format;
    await _prefs.setString(_seriesFormatKey, format);
    notifyListeners();
  }

  Future<void> setMovieFormat(String format) async {
    _movieFormat = format;
    await _prefs.setString(_movieFormatKey, format);
    notifyListeners();
  }

  Future<void> addExcludedFolder(String path) async {
    if (!_excludedFolders.contains(path)) {
      _excludedFolders.add(path);
      await _prefs.setStringList(_excludedFoldersKey, _excludedFolders);
      notifyListeners();
    }
  }

  Future<void> removeExcludedFolder(String path) async {
    _excludedFolders.remove(path);
    await _prefs.setStringList(_excludedFoldersKey, _excludedFolders);
    notifyListeners();
  }

  Future<void> setFilenameAnalysisOnly(bool value) async {
    _filenameAnalysisOnly = value;
    await _prefs.setBool(_filenameAnalysisOnlyKey, value);
    notifyListeners();
  }

  Future<void> setTmdbApiKey(String key) async {
    _tmdbApiKey = key;
    await _prefs.setString(_tmdbApiKeyKey, key);
    notifyListeners();
  }

  Future<void> setOmdbApiKey(String key) async {
    _omdbApiKey = key;
    await _prefs.setString(_omdbApiKeyKey, key);
    notifyListeners();
  }

  Future<void> setMetadataSource(String source) async {
    _metadataSource = source;
    await _prefs.setString(_metadataSourceKey, source);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _prefs.setInt(_accentColorKey, color.value);
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await _prefs.clear();
    await loadSettings();
  }
}
