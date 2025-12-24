import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import '../utils/http_client.dart';
import '../utils/safe_parser.dart';
import '../constants/app_constants.dart';

/// Service for interacting with AniDB HTTP API
/// AniDB is focused on anime content
/// Note: Requires client registration at https://wiki.anidb.net/API
class AnidbService {
  final String clientId;
  final String clientVersion;

  AnidbService(this.clientId, {this.clientVersion = '1'});

  static const String baseUrl = 'http://api.anidb.net:9001/httpapi';
  static const Duration _anidbDelay = Duration(milliseconds: 500);
  static const Duration _jikanDelay = Duration(milliseconds: 350);

  /// Search for anime by title using hybrid approach:
  /// 1. Try exact match via AniDB HTTP API (aname parameter)
  /// 2. Fall back to Jikan API (unofficial MAL API) for fuzzy search
  Future<List<Map<String, dynamic>>> searchAnimeAll(String query) async {
    if (clientId.isEmpty) {
      throw Exception('AniDB client ID is required');
    }

    List<Map<String, dynamic>> results = [];

    try {
      debugPrint('🔍 AniDB search: $query');

      // Method 1: Try exact title match via AniDB aname parameter
      try {
        final exactMatch = await _searchByExactTitle(query);
        if (exactMatch != null) {
          results.add(exactMatch);
          debugPrint('✅ Found exact match via AniDB');
        }
      } catch (e) {
        debugPrint('⚠️ AniDB exact match failed: $e');
      }

      // Method 2: Use Jikan API (unofficial MAL API) for fuzzy search
      try {
        final jikanResults = await _searchViaJikan(query);

        // Add Jikan results avoiding duplicates
        for (var result in jikanResults) {
          bool isDuplicate = results.any(
            (r) =>
                r['title']?.toString().toLowerCase() ==
                result['title']?.toString().toLowerCase(),
          );

          if (!isDuplicate) {
            results.add(result);
          }
        }

        debugPrint('✅ Found ${jikanResults.length} results via Jikan/MAL');
      } catch (e) {
        debugPrint('⚠️ Jikan search failed: $e');
      }

      debugPrint('📊 Total AniDB/MAL results: ${results.length}');
      return results;
    } catch (e) {
      debugPrint('❌ AniDB search error: $e');
      return results;
    }
  }

  /// Try to find anime via exact title match using AniDB aname parameter
  Future<Map<String, dynamic>?> _searchByExactTitle(String title) async {
    final url = Uri.parse(
      '$baseUrl?request=anime&client=$clientId&clientver=$clientVersion&protover=1&aname=${Uri.encodeComponent(title)}',
    );

    // Respect rate limiting
    await Future.delayed(_anidbDelay);

    final body = await ApiClient.getString(url);
    if (body == null) return null;

    // Parse XML response
    final document = XmlDocument.parse(body);
    final animeElement = document.findElements('anime').firstOrNull;

    if (animeElement == null) return null;

    return _parseAnimeElement(animeElement);
  }

  /// Parse anime element from XML to Map
  Map<String, dynamic> _parseAnimeElement(XmlElement animeElement) {
    final Map<String, dynamic> data = {};

    // Extract titles
    final titles = animeElement.findElements('titles').firstOrNull;
    if (titles != null) {
      final mainTitle = titles
          .findElements('title')
          .where((t) => t.getAttribute('type') == 'main')
          .firstOrNull
          ?.innerText;
      data['title'] = mainTitle;

      final engTitle = titles
          .findElements('title')
          .where((t) => t.getAttribute('xml:lang') == 'en')
          .firstOrNull
          ?.innerText;
      data['english_title'] = engTitle;
    }

    // Get AID from attribute
    final aid = animeElement.getAttribute('id');
    if (aid != null) {
      data['aid'] = SafeParser.parseInt(aid);
    }

    data['type'] = animeElement.findElements('type').firstOrNull?.innerText;
    data['episodecount'] =
        animeElement.findElements('episodecount').firstOrNull?.innerText;
    data['startdate'] =
        animeElement.findElements('startdate').firstOrNull?.innerText;
    data['description'] =
        animeElement.findElements('description').firstOrNull?.innerText;

    // Get poster/image URL
    final picture =
        animeElement.findElements('picture').firstOrNull?.innerText;
    if (picture != null) {
      data['poster_url'] = 'https://cdn-eu.anidb.net/images/main/$picture';
    }

    data['source'] = 'anidb';

    // Extract ratings
    final ratings = animeElement.findElements('ratings').firstOrNull;
    if (ratings != null) {
      final permanent = ratings.findElements('permanent').firstOrNull;
      final temporary = ratings.findElements('temporary').firstOrNull;

      if (permanent != null && permanent.innerText.isNotEmpty) {
        data['rating'] = permanent.innerText;
      } else if (temporary != null && temporary.innerText.isNotEmpty) {
        data['rating'] = temporary.innerText;
      }
    }

    // Extract tags (used as genres)
    final tags = animeElement.findElements('tags').firstOrNull;
    if (tags != null) {
      final tagList = tags
          .findElements('tag')
          .map((t) => t.findElements('name').firstOrNull?.innerText)
          .where((name) => name != null)
          .cast<String>()
          .take(5)
          .toList();
      if (tagList.isNotEmpty) {
        data['tags'] = tagList;
      }
    }

    return data;
  }

  /// Search via Jikan API (unofficial MyAnimeList API)
  Future<List<Map<String, dynamic>>> _searchViaJikan(String query) async {
    final url = Uri.parse(
      'https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(query)}&limit=${SearchConfig.maxSearchResults}',
    );

    // Respect Jikan rate limiting
    await Future.delayed(_jikanDelay);

    final data = await ApiClient.getJson(url);
    if (data == null) return [];

    final dataList = data['data'] as List?;
    if (dataList == null || dataList.isEmpty) return [];

    return dataList.take(SearchConfig.maxSearchResults).map((anime) {
      // Extract genres
      final genres = (anime['genres'] as List?)
          ?.map((g) => g['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // Extract studios
      final studios = (anime['studios'] as List?)
          ?.map((s) => s['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // Extract and clean age rating
      String? ageRating = anime['rating']?.toString();
      if (ageRating != null && ageRating.contains(' - ')) {
        ageRating = ageRating.split(' - ').first.trim();
      }

      return {
        'title': anime['title'],
        'english_title': anime['title_english'],
        'mal_id': anime['mal_id'],
        'type': anime['type'],
        'episodecount': anime['episodes']?.toString(),
        'startdate': SafeParser.safeSubstring(
            anime['aired']?['from']?.toString(), 0, 10),
        'description': anime['synopsis'],
        'poster_url': anime['images']?['jpg']?['large_image_url'],
        'rating': anime['score']?.toString(),
        'age_rating': ageRating,
        'tags': genres,
        'studios': studios,
        'source': 'mal',
      };
    }).toList();
  }

  /// Get anime details by AID (AniDB ID)
  Future<Map<String, dynamic>?> getAnimeDetails(int aid) async {
    if (clientId.isEmpty) {
      throw Exception('AniDB client ID is required');
    }

    try {
      final url = Uri.parse(
        '$baseUrl?request=anime&client=$clientId&clientver=$clientVersion&protover=1&aid=$aid',
      );

      debugPrint('📡 Fetching AniDB anime details: $aid');
      await Future.delayed(_anidbDelay);

      final body = await ApiClient.getString(url);
      if (body == null) return null;

      final document = XmlDocument.parse(body);
      final animeElement = document.findElements('anime').firstOrNull;

      if (animeElement == null) {
        debugPrint('⚠️ No anime data in response');
        return null;
      }

      final data = _parseAnimeElement(animeElement);
      data['aid'] = aid;

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
  static double? extractRating(Map<String, dynamic> data) {
    return SafeParser.parseDouble(data['rating']);
  }

  /// Extract episode count
  static int? extractEpisodeCount(Map<String, dynamic> data) {
    return SafeParser.parseInt(data['episodecount']);
  }

  /// Extract year from start date
  static int? extractYear(Map<String, dynamic> data) {
    return SafeParser.parseYear(data['startdate']);
  }

  /// Get episode titles for an anime
  Future<Map<String, String>> getEpisodeLookup(
    int aid,
    List<int> seasons,
  ) async {
    if (clientId.isEmpty) {
      throw Exception('AniDB client ID is required');
    }

    final Map<String, String> episodeMap = {};

    try {
      final url = Uri.parse(
        '$baseUrl?request=anime&client=$clientId&clientver=$clientVersion&protover=1&aid=$aid',
      );

      await Future.delayed(_anidbDelay);

      final body = await ApiClient.getString(url);
      if (body == null) return episodeMap;

      final document = XmlDocument.parse(body);
      final animeElement = document.findElements('anime').firstOrNull;

      if (animeElement == null) return episodeMap;

      final episodesElement = animeElement.findElements('episodes').firstOrNull;

      if (episodesElement != null) {
        for (var ep in episodesElement.findElements('episode')) {
          final epnoElement = ep.findElements('epno').firstOrNull;
          if (epnoElement == null) continue;

          final epnoText = epnoElement.innerText;
          final epType = epnoElement.getAttribute('type') ?? '1';

          // Type 1 = regular episodes only
          if (epType != '1') continue;

          final epNum = SafeParser.parseInt(epnoText);
          if (epNum == null) continue;

          // Get episode title (prefer English)
          final titles = ep.findElements('title');
          String? episodeTitle;

          for (var title in titles) {
            if (title.getAttribute('xml:lang') == 'en') {
              episodeTitle = title.innerText;
              break;
            }
          }

          episodeTitle ??= titles.firstOrNull?.innerText;

          if (episodeTitle != null) {
            episodeMap["S01E$epNum"] = episodeTitle;
          }
        }
      }

      debugPrint('✅ Fetched ${episodeMap.length} episode titles for AID $aid');
      return episodeMap;
    } catch (e) {
      debugPrint('❌ Error fetching episode list: $e');
      return episodeMap;
    }
  }

  /// Get episode lookup map from MAL using Jikan API
  Future<Map<String, String>> getEpisodeLookupFromMAL(
      int malId, List<int> seasons) async {
    final Map<String, String> episodeMap = {};

    try {
      final url = Uri.parse('https://api.jikan.moe/v4/anime/$malId/episodes');

      debugPrint('📡 Fetching episode list from MAL ID: $malId');
      await Future.delayed(const Duration(milliseconds: 1000));

      final data = await ApiClient.getJson(url);
      if (data == null) return episodeMap;

      final episodes = data['data'] as List?;
      if (episodes == null || episodes.isEmpty) {
        debugPrint('⚠️ No episodes found for MAL ID: $malId');
        return episodeMap;
      }

      for (var ep in episodes) {
        final epNum = ep['mal_id'];
        final title = ep['title']?.toString();

        if (epNum != null && title != null && title.isNotEmpty) {
          episodeMap["S01E$epNum"] = title;
        }
      }

      debugPrint(
          '✅ Fetched ${episodeMap.length} episode titles for MAL ID $malId');
      return episodeMap;
    } catch (e) {
      debugPrint('❌ Error fetching MAL episode list: $e');
      return episodeMap;
    }
  }

  /// Get specific episode details including description from MAL
  Future<Map<String, String>?> getEpisodeDetailsFromMAL(
    int malId,
    int episode,
  ) async {
    try {
      final url = Uri.parse('https://api.jikan.moe/v4/anime/$malId/episodes');

      debugPrint(
          '📡 Fetching episode details for MAL ID: $malId, Episode: $episode');
      await Future.delayed(const Duration(milliseconds: 1000));

      final data = await ApiClient.getJson(url);
      if (data == null) return null;

      final episodes = data['data'] as List?;
      if (episodes == null || episodes.isEmpty) {
        debugPrint('⚠️ No episodes found for MAL ID: $malId');
        return null;
      }

      for (var ep in episodes) {
        if (ep['mal_id'] == episode) {
          return {
            'title': ep['title']?.toString() ?? '',
            'description': ep['synopsis']?.toString() ?? '',
          };
        }
      }

      debugPrint('⚠️ Episode $episode not found in MAL ID $malId');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching MAL episode details: $e');
      return null;
    }
  }
}
