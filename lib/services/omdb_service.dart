import '../utils/http_client.dart';
import '../utils/safe_parser.dart';
import '../constants/app_constants.dart';

class OmdbService {
  static const String _baseUrl = 'https://www.omdbapi.com';
  final String apiKey;

  OmdbService(this.apiKey);

  Future<Map<String, dynamic>?> searchMovie(String query, int? year) async {
    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=movie');
    if (year != null) {
      uri = uri.replace(
          queryParameters: {...uri.queryParameters, 'y': year.toString()});
    }

    final data = await ApiClient.getJson(uri);

    if (data == null || data['Response'] == 'False') return null;

    final List results = data['Search'] ?? [];
    if (results.isEmpty) return null;

    return results[0];
  }

  Future<Map<String, dynamic>?> getMovieDetails(String imdbId) async {
    final uri = Uri.parse('$_baseUrl/?apikey=$apiKey&i=$imdbId&plot=full');
    final data = await ApiClient.getJson(uri);

    if (data == null || data['Response'] == 'False') return null;
    return data;
  }

  Future<List<Map<String, dynamic>>> searchMovieAll(String query, int? year,
      {int limit = SearchConfig.maxSearchResults}) async {
    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=movie');
    if (year != null) {
      uri = uri.replace(
          queryParameters: {...uri.queryParameters, 'y': year.toString()});
    }

    final data = await ApiClient.getJson(uri);

    if (data == null || data['Response'] == 'False') return [];

    final List results = (data['Search'] as List? ?? []).take(limit).toList();
    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> searchSeries(String query) async {
    final uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=series');
    final data = await ApiClient.getJson(uri);

    if (data == null || data['Response'] == 'False') return null;

    final List results = data['Search'] ?? [];
    if (results.isEmpty) return null;

    return results[0];
  }

  Future<List<Map<String, dynamic>>> searchSeriesAll(String query,
      {int limit = SearchConfig.maxSearchResults}) async {
    final uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=series');
    final data = await ApiClient.getJson(uri);

    if (data == null || data['Response'] == 'False') return [];

    final List results = (data['Search'] as List? ?? []).take(limit).toList();
    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getSeriesDetails(String imdbId) async {
    final uri = Uri.parse('$_baseUrl/?apikey=$apiKey&i=$imdbId&plot=full');
    final data = await ApiClient.getJson(uri);

    if (data == null || data['Response'] == 'False') return null;
    return data;
  }

  Future<Map<String, String>> getEpisodeLookup(
      String imdbId, List<int> seasons) async {
    final Map<String, String> lookup = {}; // Key: "SxxExx", Value: Title

    for (int season in seasons) {
      final uri =
          Uri.parse('$_baseUrl/?apikey=$apiKey&i=$imdbId&Season=$season');
      final data = await ApiClient.getJson(uri);

      if (data != null && data['Response'] != 'False') {
        final List episodes = data['Episodes'] ?? [];

        for (var ep in episodes) {
          final epNum = SafeParser.parseInt(ep['Episode']);
          final String name = ep['Title'] ?? '';

          if (epNum != null) {
            lookup['S${season}E$epNum'] = name;
          }
        }
      }
    }

    return lookup;
  }

  /// Helper method to extract genres from OMDb response
  static List<String> extractGenres(Map<String, dynamic>? data) {
    return SafeParser.parseCommaSeparated(data?['Genre']) ?? [];
  }

  /// Helper method to extract actors from OMDb response
  static List<String> extractActors(Map<String, dynamic>? data) {
    return SafeParser.parseCommaSeparated(data?['Actors']) ?? [];
  }

  /// Helper method to extract director from OMDb response
  static String? extractDirector(Map<String, dynamic>? data) {
    return SafeParser.cleanString(data?['Director']);
  }

  /// Helper method to extract runtime from OMDb response (returns minutes)
  static int? extractRuntime(Map<String, dynamic>? data) {
    return SafeParser.parseRuntime(data?['Runtime']);
  }

  /// Helper method to extract IMDb rating from OMDb response
  static double? extractRating(Map<String, dynamic>? data) {
    return SafeParser.parseDouble(data?['imdbRating']);
  }

  /// Helper method to extract content rating from OMDb response
  static String? extractContentRating(Map<String, dynamic>? data) {
    return SafeParser.cleanString(data?['Rated']);
  }
}
