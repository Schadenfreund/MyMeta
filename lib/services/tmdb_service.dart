import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  final String apiKey;

  TmdbService(this.apiKey);

  Future<Map<String, dynamic>?> searchMovie(String query, int? year) async {
    // 1. Search for the movie
    var uri = Uri.parse('$_baseUrl/search/movie?api_key=$apiKey&query=$query');
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;

    var data = jsonDecode(response.body);
    List results = data['results'];

    if (results.isEmpty) return null;

    // 2. Filter by year if provided
    if (year != null) {
      // Find best match within +/- 1 year
      var bestMatch = results.firstWhere((r) {
        String? date = r['release_date'];
        if (date == null || date.length < 4) return false;
        int? rYear = int.tryParse(date.substring(0, 4));
        return rYear != null && (rYear - year).abs() <= 1;
      }, orElse: () => results[0]);

      return bestMatch;
    }

    return results[0];
  }

  // Get multiple search results for re-matching
  Future<List<Map<String, dynamic>>> searchMovieAll(String query, int? year,
      {int limit = 10}) async {
    var uri = Uri.parse('$_baseUrl/search/movie?api_key=$apiKey&query=$query');
    var response = await http.get(uri);

    if (response.statusCode != 200) return [];

    var data = jsonDecode(response.body);
    List results = (data['results'] as List).take(limit).toList();

    return results.cast<Map<String, dynamic>>();
  }

  // Get multiple alternative posters for the same movie
  Future<List<String>> getMoviePosters(int movieId) async {
    var uri = Uri.parse(
        '$_baseUrl/movie/$movieId/images?api_key=$apiKey&language=en');
    var response = await http.get(uri);

    if (response.statusCode != 200) return [];

    var data = jsonDecode(response.body);
    List posters = data['posters'] ?? [];

    // Return top 5 posters sorted by vote count
    final sortedPosters = posters.where((p) => p['file_path'] != null).toList()
      ..sort((a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));

    return sortedPosters
        .take(5)
        .map((p) => 'https://image.tmdb.org/t/p/w500${p['file_path']}')
        .toList();
  }

  Future<Map<String, dynamic>?> getMovieDetails(int movieId) async {
    var uri = Uri.parse(
        '$_baseUrl/movie/$movieId?api_key=$apiKey&append_to_response=credits,release_dates');
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>?> searchTV(String query) async {
    var uri = Uri.parse('$_baseUrl/search/tv?api_key=$apiKey&query=$query');
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;

    var data = jsonDecode(response.body);
    List results = data['results'];

    if (results.isEmpty) return null;

    return results[0];
  }

  // Get multiple search results for TV shows
  Future<List<Map<String, dynamic>>> searchTVAll(String query,
      {int limit = 10}) async {
    var uri = Uri.parse('$_baseUrl/search/tv?api_key=$apiKey&query=$query');
    var response = await http.get(uri);

    if (response.statusCode != 200) return [];

    var data = jsonDecode(response.body);
    List results = (data['results'] as List).take(limit).toList();

    return results.cast<Map<String, dynamic>>();
  }

  // Get multiple alternative posters for the same TV show
  Future<List<String>> getTVPosters(int tvId) async {
    var uri =
        Uri.parse('$_baseUrl/tv/$tvId/images?api_key=$apiKey&language=en');
    var response = await http.get(uri);

    if (response.statusCode != 200) return [];

    var data = jsonDecode(response.body);
    List posters = data['posters'] ?? [];

    // Return top 5 posters sorted by vote count
    final sortedPosters = posters.where((p) => p['file_path'] != null).toList()
      ..sort((a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));

    return sortedPosters
        .take(5)
        .map((p) => 'https://image.tmdb.org/t/p/w500${p['file_path']}')
        .toList();
  }

  Future<Map<String, dynamic>?> getTVDetails(int tvId) async {
    var uri = Uri.parse(
        '$_baseUrl/tv/$tvId?api_key=$apiKey&append_to_response=credits,content_ratings');
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  }

  Future<Map<String, String>> getEpisodeLookup(
      int seriesId, List<int> seasons) async {
    Map<String, String> lookup = {}; // Key: "SxxExx", Value: Title

    for (int season in seasons) {
      var uri =
          Uri.parse('$_baseUrl/tv/$seriesId/season/$season?api_key=$apiKey');
      var response = await http.get(uri);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        List episodes = data['episodes'] ?? [];

        for (var ep in episodes) {
          int epNum = ep['episode_number'];
          String name = ep['name'];
          // Key format: "S{season}E{episode}" using integers for lookup
          lookup['S${season}E$epNum'] = name;
        }
      }
    }

    return lookup;
  }

  /// Get specific episode details including description
  Future<Map<String, dynamic>?> getEpisodeDetails(
    int seriesId,
    int season,
    int episode,
  ) async {
    var uri = Uri.parse(
      '$_baseUrl/tv/$seriesId/season/$season/episode/$episode?api_key=$apiKey',
    );
    var response = await http.get(uri);

    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  }

  // Helper method to extract genres
  static List<String> extractGenres(Map<String, dynamic>? data) {
    if (data == null || data['genres'] == null) return [];
    List genres = data['genres'];
    return genres.map((g) => g['name'].toString()).toList();
  }

  // Helper method to extract cast (top 5 actors)
  static List<String> extractCast(Map<String, dynamic>? data, {int limit = 5}) {
    if (data == null || data['credits'] == null) return [];
    var credits = data['credits'];
    if (credits['cast'] == null) return [];
    List cast = credits['cast'];
    return cast.take(limit).map((c) => c['name'].toString()).toList();
  }

  // Helper method to extract director
  static String? extractDirector(Map<String, dynamic>? data) {
    if (data == null || data['credits'] == null) return null;
    var credits = data['credits'];
    if (credits['crew'] == null) return null;
    List crew = credits['crew'];
    var director = crew.firstWhere(
      (c) => c['job'] == 'Director',
      orElse: () => null,
    );
    return director?['name'];
  }

  // Helper method to extract US content rating
  static String? extractContentRating(Map<String, dynamic>? data, bool isTv) {
    if (data == null) return null;

    if (isTv) {
      // For TV shows
      if (data['content_ratings'] == null) return null;
      var ratings = data['content_ratings']['results'] as List?;
      if (ratings == null) return null;

      var usRating = ratings.firstWhere(
        (r) => r['iso_3166_1'] == 'US',
        orElse: () => null,
      );
      return usRating?['rating'];
    } else {
      // For movies
      if (data['release_dates'] == null) return null;
      var releases = data['release_dates']['results'] as List?;
      if (releases == null) return null;

      var usRelease = releases.firstWhere(
        (r) => r['iso_3166_1'] == 'US',
        orElse: () => null,
      );

      if (usRelease == null) return null;
      var releaseDates = usRelease['release_dates'] as List?;
      if (releaseDates == null || releaseDates.isEmpty) return null;

      return releaseDates.first['certification'];
    }
  }
}
