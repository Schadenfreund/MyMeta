import 'dart:convert';
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

  /// Search for anime by title using hybrid approach:
  /// 1. Try exact match via AniDB HTTP API (aname parameter)
  /// 2. Fall back to Jikan API (unofficial MAL API) for fuzzy search
  /// Jikan provides MAL IDs which can be cross-referenced to AniDB
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
      // Jikan is free, requires no API key, and has good search
      try {
        final jikanResults = await _searchViaJikan(query);

        // Add Jikan results (they'll have MAL IDs, not AniDB IDs)
        // We store them as-is and note they're from MAL
        for (var result in jikanResults) {
          // Avoid duplicates based on title
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
      return results; // Return whatever we found
    }
  }

  /// Try to find anime via exact title match using AniDB aname parameter
  Future<Map<String, dynamic>?> _searchByExactTitle(String title) async {
    final url = Uri.parse(
      '$baseUrl?request=anime&client=$clientId&clientver=$clientVersion&protover=1&aname=${Uri.encodeComponent(title)}',
    );

    // Respect rate limiting
    await Future.delayed(const Duration(milliseconds: 500));

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    // Parse XML response
    final document = XmlDocument.parse(response.body);
    final animeElement = document.findElements('anime').firstOrNull;

    if (animeElement == null) {
      return null;
    }

    // Extract basic info for search result
    final Map<String, dynamic> data = {};

    final titles = animeElement.findElements('titles').firstOrNull;
    if (titles != null) {
      final mainTitle = titles
          .findElements('title')
          .where((t) => t.getAttribute('type') == 'main')
          .firstOrNull
          ?.innerText;
      data['title'] = mainTitle;

      // Also get English title if available
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
      data['aid'] = int.tryParse(aid);
    }

    data['type'] = animeElement.findElements('type').firstOrNull?.innerText;
    data['episodecount'] = animeElement
        .findElements('episodecount')
        .firstOrNull
        ?.innerText;
    data['startdate'] = animeElement
        .findElements('startdate')
        .firstOrNull
        ?.innerText;
    data['description'] = animeElement
        .findElements('description')
        .firstOrNull
        ?.innerText;

    // Get poster/image URL
    final picture = animeElement.findElements('picture').firstOrNull?.innerText;
    if (picture != null) {
      data['poster_url'] = 'https://cdn-eu.anidb.net/images/main/$picture';
    }

    data['source'] = 'anidb'; // Mark as coming from AniDB

    return data;
  }

  /// Search via Jikan API (unofficial MyAnimeList API)
  /// This provides better fuzzy search than AniDB HTTP API
  Future<List<Map<String, dynamic>>> _searchViaJikan(String query) async {
    final url = Uri.parse(
      'https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(query)}&limit=10',
    );

    // Respect Jikan rate limiting (3 requests/second, 60/minute)
    await Future.delayed(const Duration(milliseconds: 350));

    final response = await http.get(url);

    if (response.statusCode != 200) {
      debugPrint('⚠️ Jikan API error: ${response.statusCode}');
      return [];
    }

    final jsonData = json.decode(response.body);
    final dataList = jsonData['data'] as List?;

    if (dataList == null || dataList.isEmpty) {
      return [];
    }

    List<Map<String, dynamic>> results = [];

    for (var anime in dataList.take(10)) {
      // Convert Jikan/MAL data to our format
      Map<String, dynamic> data = {
        'title': anime['title'],
        'english_title': anime['title_english'],
        'mal_id': anime['mal_id'], // MAL ID, not AniDB ID
        'type': anime['type'],
        'episodecount': anime['episodes']?.toString(),
        'startdate': anime['aired']?['from']?.toString().substring(0, 10),
        'description': anime['synopsis'],
        'poster_url': anime['images']?['jpg']?['large_image_url'],
        'rating': anime['score']?.toString(),
        'source': 'mal', // Mark as coming from MAL/Jikan
      };

      results.add(data);
    }

    return results;
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
      data['episodecount'] = animeElement
          .findElements('episodecount')
          .firstOrNull
          ?.innerText;
      data['startdate'] = animeElement
          .findElements('startdate')
          .firstOrNull
          ?.innerText;
      data['description'] = animeElement
          .findElements('description')
          .firstOrNull
          ?.innerText;

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
  /// AniDB doesn't use traditional "seasons" like Western TV shows
  /// Episodes are numbered sequentially (1, 2, 3...) regardless of season
  /// We'll map them to S01E01, S01E02, etc. format
  Future<Map<String, String>> getEpisodeLookup(
    int aid,
    List<int> seasons,
  ) async {
    if (clientId.isEmpty) {
      throw Exception('AniDB client ID is required');
    }

    Map<String, String> episodeMap = {};

    try {
      // Fetch full anime details with episodes
      final details = await getAnimeDetails(aid);

      if (details == null) {
        return episodeMap;
      }

      // Note: The current getAnimeDetails doesn't fetch episodes
      // We need to enhance it or make a separate call
      // For now, we'll make a fresh call with episode data

      final url = Uri.parse(
        '$baseUrl?request=anime&client=$clientId&clientver=$clientVersion&protover=1&aid=$aid',
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return episodeMap;
      }

      final document = XmlDocument.parse(response.body);
      final animeElement = document.findElements('anime').firstOrNull;

      if (animeElement == null) {
        return episodeMap;
      }

      // Extract episodes
      final episodesElement = animeElement.findElements('episodes').firstOrNull;

      if (episodesElement != null) {
        final episodes = episodesElement.findElements('episode');

        for (var ep in episodes) {
          // Get episode number
          final epnoElement = ep.findElements('epno').firstOrNull;
          if (epnoElement == null) continue;

          final epnoText = epnoElement.innerText;
          final epType = epnoElement.getAttribute('type') ?? '1';

          // Type 1 = regular episodes, 2 = special, 3 = credit, etc.
          // We only want regular episodes for now
          if (epType != '1') continue;

          // Parse episode number
          final epNum = int.tryParse(epnoText);
          if (epNum == null) continue;

          // Get episode title (prefer English, fallback to main)
          final titles = ep.findElements('title');
          String? episodeTitle;

          // Try English first
          for (var title in titles) {
            if (title.getAttribute('xml:lang') == 'en') {
              episodeTitle = title.innerText;
              break;
            }
          }

          // Fallback to any title
          if (episodeTitle == null && titles.isNotEmpty) {
            episodeTitle = titles.first.innerText;
          }

          if (episodeTitle != null) {
            // AniDB uses sequential numbering, map to S01E##
            String key = "S01E$epNum";
            episodeMap[key] = episodeTitle;
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
}
