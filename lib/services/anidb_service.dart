import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

/// Service for interacting with AniDB HTTP API
/// AniDB is focused on anime content
/// Note: Requires client registration at https://wiki.anidb.net/API
class AnidbService {
  final String clientId;
  final String clientVersion;

  AnidbService(this.clientId, {this.clientVersion = '1'});

  static const String baseUrl = 'http://api.anidb.net:9001/httpapi';

  /// Search for anime by title
  /// Note: AniDB search is case-sensitive and doesn't support wildcards well
  Future<List<Map<String, dynamic>>> searchAnimeAll(String query) async {
    if (clientId.isEmpty) {
      throw Exception('AniDB client ID is required');
    }

    try {
      // AniDB HTTP API doesn't have a direct search endpoint
      // We'd need to use the anime title lookup which requires exact matches
      // For now, return empty list with helpful message
      debugPrint('🔍 AniDB search: $query');
      debugPrint('⚠️ AniDB HTTP API requires exact title matches');
      debugPrint('   Consider implementing UDP API for better search');

      return [];
    } catch (e) {
      debugPrint('❌ AniDB search error: $e');
      return [];
    }
  }

  /// Get anime details by AID (AniDB ID)
  Future<Map<String, dynamic>?> getAnimeDetails(int aid) async {
    if (clientId.isEmpty) {
      throw Exception('AniDB client ID is required');
    }

    try {
      final url = Uri.parse(
          '$baseUrl?request=anime&client=$clientId&clientver=$clientVersion&protover=1&aid=$aid');

      debugPrint('📡 Fetching AniDB anime details: $aid');

      // Add delay to respect rate limiting (2 requests per second max)
      await Future.delayed(const Duration(milliseconds: 500));

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('⚠️ AniDB API error: ${response.statusCode}');
        return null;
      }

      // Parse XML response
      final document = XmlDocument.parse(response.body);
      final animeElement = document.findElements('anime').firstOrNull;

      if (animeElement == null) {
        debugPrint('⚠️ No anime data in response');
        return null;
      }

      // Extract data from XML
      final Map<String, dynamic> data = {};

      // Basic info
      final titles = animeElement.findElements('titles').firstOrNull;
      if (titles != null) {
        final mainTitle = titles
            .findElements('title')
            .where((t) => t.getAttribute('type') == 'main')
            .firstOrNull
            ?.innerText;
        data['title'] = mainTitle;
      }

      data['aid'] = aid;
      data['type'] = animeElement.findElements('type').firstOrNull?.innerText;
      data['episodecount'] =
          animeElement.findElements('episodecount').firstOrNull?.innerText;
      data['startdate'] =
          animeElement.findElements('startdate').firstOrNull?.innerText;
      data['description'] =
          animeElement.findElements('description').firstOrNull?.innerText;

      // Ratings
      final ratings = animeElement.findElements('ratings').firstOrNull;
      if (ratings != null) {
        final permanent = ratings.findElements('permanent').firstOrNull;
        if (permanent != null) {
          data['rating'] = permanent.innerText;
        }
      }

      // Tags (used as genres)
      final tags = animeElement.findElements('tags').firstOrNull;
      if (tags != null) {
        final tagList = tags
            .findElements('tag')
            .map((t) => t.findElements('name').firstOrNull?.innerText)
            .where((name) => name != null)
            .take(5) // Limit to top 5 tags
            .toList();
        data['tags'] = tagList;
      }

      debugPrint('✅ Fetched AniDB anime: ${data['title']}');
      return data;
    } catch (e) {
      debugPrint('❌ AniDB details error: $e');
      return null;
    }
  }

  /// Extract genres from AniDB anime data (using tags)
  static List<String>? extractGenres(Map<String, dynamic> data) {
    final tags = data['tags'];
    if (tags is List) {
      return tags.cast<String>();
    }
    return null;
  }

  /// Extract rating from AniDB anime data
  /// AniDB uses a 10-point scale
  static double? extractRating(Map<String, dynamic> data) {
    final rating = data['rating'];
    if (rating != null) {
      return double.tryParse(rating.toString());
    }
    return null;
  }

  /// Extract episode count
  static int? extractEpisodeCount(Map<String, dynamic> data) {
    final count = data['episodecount'];
    if (count != null) {
      return int.tryParse(count.toString());
    }
    return null;
  }

  /// Extract year from start date
  static int? extractYear(Map<String, dynamic> data) {
    final startDate = data['startdate'];
    if (startDate != null && startDate.toString().length >= 4) {
      return int.tryParse(startDate.toString().substring(0, 4));
    }
    return null;
  }

  /// Get episode titles for an anime
  /// Note: This would require additional API calls
  Future<Map<String, String>> getEpisodeLookup(
      int aid, List<int> seasons) async {
    // AniDB doesn't use seasons the same way
    // Would need to call the episode list endpoint
    // For now, return empty map
    return {};
  }
}
