import 'dart:convert';
import 'package:http/http.dart' as http;

class OmdbService {
  static const String _baseUrl = 'https://www.omdbapi.com';
  final String apiKey;

  OmdbService(this.apiKey);

  Future<Map<String, dynamic>?> searchMovie(String query, int? year) async {
    // 1. Search for the movie
    // OMDb supports by-title search using 't=' or search using 's='
    // 's=' returns a list, 't=' returns a single match.
    // Let's use 's=' to get a list and filter, similar to TMDB logic, but OMDb search is often less fuzzy.

    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=movie');
    if (year != null) {
      uri = uri.replace(
          queryParameters: {...uri.queryParameters, 'y': year.toString()});
    }

    var response = await http.get(uri);

    if (response.statusCode != 200) return null;

    var data = jsonDecode(response.body);
    if (data['Response'] == 'False') return null;

    List results = data['Search'];

    if (results.isEmpty) return null;

    // Return first match details (we need full details for poster, etc. - search results are partial)
    // Actually search results have Poster and Title and Year and imdbID.
    return results[0];
  }

  Future<Map<String, dynamic>?> getMovieDetails(String imdbId) async {
    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&i=$imdbId&plot=full');
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;

    var data = jsonDecode(response.body);
    if (data['Response'] == 'False') return null;

    return data;
  }

  Future<List<Map<String, dynamic>>> searchMovieAll(String query, int? year,
      {int limit = 10}) async {
    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=movie');
    if (year != null) {
      uri = uri.replace(
          queryParameters: {...uri.queryParameters, 'y': year.toString()});
    }

    var response = await http.get(uri);

    if (response.statusCode != 200) return [];

    var data = jsonDecode(response.body);
    if (data['Response'] == 'False') return [];

    List results = (data['Search'] as List).take(limit).toList();

    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> searchSeries(String query) async {
    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=series');
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;

    var data = jsonDecode(response.body);
    if (data['Response'] == 'False') return null;

    List results = data['Search'];

    if (results.isEmpty) return null;

    return results[0];
  }

  Future<List<Map<String, dynamic>>> searchSeriesAll(String query,
      {int limit = 10}) async {
    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&s=$query&type=series');
    var response = await http.get(uri);

    if (response.statusCode != 200) return [];

    var data = jsonDecode(response.body);
    if (data['Response'] == 'False') return [];

    List results = (data['Search'] as List).take(limit).toList();

    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getSeriesDetails(String imdbId) async {
    var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&i=$imdbId&plot=full');
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;

    var data = jsonDecode(response.body);
    if (data['Response'] == 'False') return null;

    return data;
  }

  Future<Map<String, String>> getEpisodeLookup(
      String imdbId, List<int> seasons) async {
    Map<String, String> lookup = {}; // Key: "SxxExx", Value: Title

    for (int season in seasons) {
      var uri = Uri.parse('$_baseUrl/?apikey=$apiKey&i=$imdbId&Season=$season');
      var response = await http.get(uri);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['Response'] == 'False') continue;

        List episodes = data['Episodes'] ?? [];

        for (var ep in episodes) {
          int? epNum = int.tryParse(ep['Episode']);
          String name = ep['Title'];

          if (epNum != null) {
            lookup['S${season}E$epNum'] = name;
          }
        }
      }
    }

    return lookup;
  }

  // Helper method to extract genres from OMDb response
  static List<String> extractGenres(Map<String, dynamic>? data) {
    if (data == null || data['Genre'] == null) return [];
    String genreString = data['Genre'];
    // OMDb returns comma-separated genres like "Action, Drama, Sci-Fi"
    return genreString.split(',').map((g) => g.trim()).toList();
  }

  // Helper method to extract actors from OMDb response
  static List<String> extractActors(Map<String, dynamic>? data) {
    if (data == null || data['Actors'] == null) return [];
    String actorsString = data['Actors'];
    // OMDb returns comma-separated actors
    return actorsString.split(',').map((a) => a.trim()).toList();
  }

  // Helper method to extract director from OMDb response
  static String? extractDirector(Map<String, dynamic>? data) {
    if (data == null || data['Director'] == null || data['Director'] == 'N/A') {
      return null;
    }
    return data['Director'];
  }

  // Helper method to extract runtime from OMDb response (returns minutes)
  static int? extractRuntime(Map<String, dynamic>? data) {
    if (data == null || data['Runtime'] == null || data['Runtime'] == 'N/A') {
      return null;
    }
    // OMDb returns runtime like "142 min"
    String runtime = data['Runtime'];
    var match = RegExp(r'(\d+)').firstMatch(runtime);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  // Helper method to extract IMDb rating from OMDb response
  static double? extractRating(Map<String, dynamic>? data) {
    if (data == null ||
        data['imdbRating'] == null ||
        data['imdbRating'] == 'N/A') {
      return null;
    }
    return double.tryParse(data['imdbRating']);
  }

  // Helper method to extract content rating from OMDb response
  static String? extractContentRating(Map<String, dynamic>? data) {
    if (data == null || data['Rated'] == null || data['Rated'] == 'N/A') {
      return null;
    }
    return data['Rated'];
  }
}
