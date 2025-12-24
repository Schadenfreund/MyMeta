import '../utils/http_client.dart';
import '../utils/safe_parser.dart';
import '../constants/app_constants.dart';

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  final String apiKey;

  TmdbService(this.apiKey);

  Future<Map<String, dynamic>?> searchMovie(String query, int? year) async {
    final uri =
        Uri.parse('$_baseUrl/search/movie?api_key=$apiKey&query=$query');
    final data = await ApiClient.getJson(uri);

    if (data == null) return null;

    final List results = data['results'] ?? [];
    if (results.isEmpty) return null;

    // Filter by year if provided
    if (year != null) {
      // Find best match within +/- 1 year
      final bestMatch = results.firstWhere((r) {
        final rYear = SafeParser.parseYear(r['release_date']);
        return rYear != null && (rYear - year).abs() <= 1;
      }, orElse: () => results[0]);

      return bestMatch;
    }

    return results[0];
  }

  /// Get multiple search results for re-matching
  Future<List<Map<String, dynamic>>> searchMovieAll(String query, int? year,
      {int limit = SearchConfig.maxSearchResults}) async {
    final uri =
        Uri.parse('$_baseUrl/search/movie?api_key=$apiKey&query=$query');
    final data = await ApiClient.getJson(uri);

    if (data == null) return [];

    final List results = (data['results'] as List? ?? []).take(limit).toList();
    return results.cast<Map<String, dynamic>>();
  }

  /// Get multiple alternative posters for the same movie
  Future<List<String>> getMoviePosters(int movieId) async {
    final uri = Uri.parse(
        '$_baseUrl/movie/$movieId/images?api_key=$apiKey&language=en');
    final data = await ApiClient.getJson(uri);

    if (data == null) return [];

    final List posters = data['posters'] ?? [];

    // Return top 5 posters sorted by vote count
    final sortedPosters = posters.where((p) => p['file_path'] != null).toList()
      ..sort((a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));

    return sortedPosters
        .take(5)
        .map((p) =>
            '${ImageConfig.tmdbImageBaseUrl}${ImageConfig.tmdbPosterSize}${p['file_path']}')
        .toList();
  }

  Future<Map<String, dynamic>?> getMovieDetails(int movieId) async {
    final uri = Uri.parse(
        '$_baseUrl/movie/$movieId?api_key=$apiKey&append_to_response=credits,release_dates');
    return await ApiClient.getJson(uri);
  }

  Future<Map<String, dynamic>?> searchTV(String query) async {
    final uri = Uri.parse('$_baseUrl/search/tv?api_key=$apiKey&query=$query');
    final data = await ApiClient.getJson(uri);

    if (data == null) return null;

    final List results = data['results'] ?? [];
    if (results.isEmpty) return null;

    return results[0];
  }

  /// Get multiple search results for TV shows
  Future<List<Map<String, dynamic>>> searchTVAll(String query,
      {int limit = SearchConfig.maxSearchResults}) async {
    final uri = Uri.parse('$_baseUrl/search/tv?api_key=$apiKey&query=$query');
    final data = await ApiClient.getJson(uri);

    if (data == null) return [];

    final List results = (data['results'] as List? ?? []).take(limit).toList();
    return results.cast<Map<String, dynamic>>();
  }

  /// Get multiple alternative posters for the same TV show
  Future<List<String>> getTVPosters(int tvId) async {
    final uri =
        Uri.parse('$_baseUrl/tv/$tvId/images?api_key=$apiKey&language=en');
    final data = await ApiClient.getJson(uri);

    if (data == null) return [];

    final List posters = data['posters'] ?? [];

    // Return top 5 posters sorted by vote count
    final sortedPosters = posters.where((p) => p['file_path'] != null).toList()
      ..sort((a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));

    return sortedPosters
        .take(5)
        .map((p) =>
            '${ImageConfig.tmdbImageBaseUrl}${ImageConfig.tmdbPosterSize}${p['file_path']}')
        .toList();
  }

  Future<Map<String, dynamic>?> getTVDetails(int tvId) async {
    final uri = Uri.parse(
        '$_baseUrl/tv/$tvId?api_key=$apiKey&append_to_response=credits,content_ratings');
    return await ApiClient.getJson(uri);
  }

  Future<Map<String, String>> getEpisodeLookup(
      int seriesId, List<int> seasons) async {
    final Map<String, String> lookup = {}; // Key: "SxxExx", Value: Title

    for (int season in seasons) {
      final uri =
          Uri.parse('$_baseUrl/tv/$seriesId/season/$season?api_key=$apiKey');
      final data = await ApiClient.getJson(uri);

      if (data != null) {
        final List episodes = data['episodes'] ?? [];

        for (var ep in episodes) {
          final epNum = ep['episode_number'];
          final String name = ep['name'] ?? '';
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
    final uri = Uri.parse(
      '$_baseUrl/tv/$seriesId/season/$season/episode/$episode?api_key=$apiKey',
    );
    return await ApiClient.getJson(uri);
  }

  /// Helper method to extract genres
  static List<String> extractGenres(Map<String, dynamic>? data) {
    if (data == null || data['genres'] == null) return [];
    final List genres = data['genres'];
    return genres.map((g) => g['name'].toString()).toList();
  }

  /// Helper method to extract cast (top 5 actors)
  static List<String> extractCast(Map<String, dynamic>? data,
      {int limit = 5}) {
    if (data == null || data['credits'] == null) return [];
    final credits = data['credits'];
    if (credits['cast'] == null) return [];
    final List cast = credits['cast'];
    return cast.take(limit).map((c) => c['name'].toString()).toList();
  }

  /// Helper method to extract director
  static String? extractDirector(Map<String, dynamic>? data) {
    if (data == null || data['credits'] == null) return null;
    final credits = data['credits'];
    if (credits['crew'] == null) return null;
    final List crew = credits['crew'];
    final director = crew.firstWhere(
      (c) => c['job'] == 'Director',
      orElse: () => null,
    );
    return director?['name'];
  }

  /// Helper method to extract US content rating
  static String? extractContentRating(Map<String, dynamic>? data, bool isTv) {
    if (data == null) return null;

    if (isTv) {
      // For TV shows
      if (data['content_ratings'] == null) return null;
      final ratings = data['content_ratings']['results'] as List?;
      if (ratings == null) return null;

      final usRating = ratings.firstWhere(
        (r) => r['iso_3166_1'] == 'US',
        orElse: () => null,
      );
      return usRating?['rating'];
    } else {
      // For movies
      if (data['release_dates'] == null) return null;
      final releases = data['release_dates']['results'] as List?;
      if (releases == null) return null;

      final usRelease = releases.firstWhere(
        (r) => r['iso_3166_1'] == 'US',
        orElse: () => null,
      );

      if (usRelease == null) return null;
      final releaseDates = usRelease['release_dates'] as List?;
      if (releaseDates == null || releaseDates.isEmpty) return null;

      return releaseDates.first['certification'];
    }
  }
}
