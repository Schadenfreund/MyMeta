import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'media_record.dart';
import 'match_result.dart';
import '../services/tmdb_service.dart';
import '../services/omdb_service.dart';
import '../services/anidb_service.dart';
import '../services/settings_service.dart';
import '../utils/cover_extractor.dart';
import 'package:http/http.dart' as http;

class CoreBackend {
  static String createFormattedTitle(
    String template,
    Map<String, dynamic> context,
  ) {
    // Basic substitution: {series_name}, {year}, {season_number}, {episode_number}, {episode_title}
    String result = template;
    context.forEach((key, value) {
      String replacement = value?.toString() ?? "{None}";
      result = result.replaceAll('{$key}', replacement);
    });
    return result;
  }

  /// Builds the formatted container title string used for the file title tag
  /// and video track name embedded into media files.
  /// Movies:   "Title (Year)"             e.g. Inception (2010)
  /// TV shows: "Show S##E##: Episode"     e.g. Breaking Bad S01E05: Gray Matter
  static String _buildContainerTitle(
    MatchResult metadata, {
    int seasonDigits = 2,
    int episodeDigits = 2,
  }) {
    if (metadata.season != null && metadata.episode != null) {
      final s = metadata.season!.toString().padLeft(seasonDigits, '0');
      final e = metadata.episode!.toString().padLeft(episodeDigits, '0');
      final base = '${metadata.title ?? ''} S${s}E${e}';
      final ep = metadata.episodeTitle;
      return (ep != null && ep.isNotEmpty) ? '$base: $ep' : base;
    }
    final title = metadata.title ?? '';
    final year = metadata.year;
    return year != null ? '$title ($year)' : title;
  }

  /// Centralized metadata search method
  /// Searches for movies or TV shows and returns results with full metadata
  /// For TV shows, preserves season/episode/episodeTitle from the original file
  static Future<List<MatchResult>> searchMetadata({
    required String title,
    int? year,
    required bool isMovie,
    required String source, // 'tmdb' or 'omdb'
    required String apiKey,
    int? season, // For TV shows - preserved from original file
    int? episode, // For TV shows - preserved from original file
    String? episodeTitle, // For TV shows - preserved from original file
    bool fetchAllEpisodes =
        false, // If true, fetches all episode details (no rate limit)
    bool useSeasonPoster = false, // TMDB only: prefer season poster over show poster
  }) async {
    // Validation: Ensure required parameters are valid
    if (apiKey.trim().isEmpty) {
      debugPrint('❌ searchMetadata: API key is empty for source "$source"');
      return [];
    }

    if (title.trim().isEmpty) {
      debugPrint('❌ searchMetadata: Title is empty, cannot search');
      return [];
    }

    if (source != 'tmdb' && source != 'omdb' && source != 'anidb') {
      debugPrint('❌ searchMetadata: Unknown source "$source"');
      return [];
    }

    List<MatchResult> results = [];

    try {
      if (source == 'tmdb') {
        final tmdb = TmdbService(apiKey);

        if (isMovie) {
          // Search for movies and fetch full details for each
          final allResults = await tmdb.searchMovieAll(title, year);

          for (var result in allResults) {
            int? movieId = result['id'];

            // Basic info from search
            String? posterUrl = result['poster_path'] != null
                ? "https://image.tmdb.org/t/p/w500${result['poster_path']}"
                : null;

            // Variables for detailed metadata
            List<String>? genres;
            String? director;
            List<String>? actors;
            String? description = result['overview'];
            double? rating = result['vote_average']?.toDouble();
            String? contentRating;
            int? runtime;
            List<String>? alternativePosters;

            // Fetch full details if we have an ID
            if (movieId != null) {
              try {
                final details = await tmdb.getMovieDetails(movieId);
                if (details != null) {
                  genres = TmdbService.extractGenres(details);
                  director = TmdbService.extractDirector(details);
                  actors = TmdbService.extractCast(details);
                  description = details['overview'] ?? description;
                  rating = details['vote_average']?.toDouble() ?? rating;
                  contentRating = TmdbService.extractContentRating(
                    details,
                    false,
                  );
                  runtime = details['runtime'];
                }

                // Fetch alternative posters
                alternativePosters = await tmdb.getMoviePosters(movieId);
              } catch (e) {
                debugPrint('Error fetching movie details for ID $movieId: $e');
              }
            }

            results.add(
              MatchResult(
                newName: result['title'] ?? 'Unknown',
                posterUrl: posterUrl,
                title: result['title'],
                year: result['release_date'] != null &&
                        result['release_date'].length >= 4
                    ? int.tryParse(result['release_date'].substring(0, 4))
                    : null,
                type: 'movie',
                description: description,
                genres: genres,
                director: director,
                actors: actors,
                rating: rating,
                contentRating: contentRating,
                runtime: runtime,
                tmdbId: movieId,
                alternativePosterUrls: alternativePosters,
              ),
            );
          }
        } else {
          // Search for TV shows and fetch full details for each
          final allResults = await tmdb.searchTVAll(title);

          for (var result in allResults) {
            int? tvId = result['id'];

            // Basic info from search
            String? posterUrl = result['poster_path'] != null
                ? "https://image.tmdb.org/t/p/w500${result['poster_path']}"
                : null;

            // Variables for detailed metadata
            List<String>? genres;
            List<String>? actors;
            String? description = result['overview'];
            double? rating = result['vote_average']?.toDouble();
            String? contentRating;
            List<String>? alternativePosters;
            String? fetchedEpisodeTitle =
                episodeTitle; // Start with provided value

            // Fetch full details if we have an ID
            if (tvId != null) {
              try {
                final details = await tmdb.getTVDetails(tvId);
                if (details != null) {
                  genres = TmdbService.extractGenres(details);
                  actors = TmdbService.extractCast(details);
                  description = details['overview'] ?? description;
                  rating = details['vote_average']?.toDouble() ?? rating;
                  contentRating = TmdbService.extractContentRating(
                    details,
                    true,
                  );
                }

                // Fetch alternative posters
                alternativePosters = await tmdb.getTVPosters(tvId);

                // Override with season-specific poster when enabled
                if (useSeasonPoster && season != null) {
                  final seasonPoster =
                      await tmdb.getSeasonPosterUrl(tvId, season);
                  if (seasonPoster != null) {
                    posterUrl = seasonPoster;
                    debugPrint('🖼️  Using season $season poster for $tvId');
                  }
                }

                // Fetch specific episode title and description if season/episode provided
                if (season != null && episode != null) {
                  debugPrint(
                    '🔎 Fetching episode details for S${season}E${episode} from TMDB show $tvId',
                  );
                  try {
                    // Fetch episode details including description
                    Map<String, dynamic>? episodeDetails =
                        await tmdb.getEpisodeDetails(tvId, season, episode);

                    // Fallback: some shows list early episodes under Season 0
                    // (Specials) on TMDB rather than Season 1 (e.g. One Piece,
                    // Solo Leveling, Fallout). Try Season 0 before skipping.
                    if (episodeDetails == null && season == 1) {
                      episodeDetails =
                          await tmdb.getEpisodeDetails(tvId, 0, episode);
                      if (episodeDetails != null) {
                        debugPrint(
                          '✅ Found S${season}E${episode} under Season 0 (Specials) for "${result['name']}"',
                        );
                      }
                    }

                    if (episodeDetails != null) {
                      // Use episode-specific title and description
                      fetchedEpisodeTitle = episodeDetails['name'];
                      description = episodeDetails['overview'] ?? description;
                      debugPrint(
                        '✅ Fetched episode details for S${season}E${episode}: $fetchedEpisodeTitle',
                      );
                    } else {
                      debugPrint(
                        '⚠️ Show "${result['name']}" doesn\'t have S${season}E${episode} - skipping',
                      );
                      continue; // Skip this show - it doesn't have this episode
                    }
                  } catch (e) {
                    debugPrint(
                      'Error fetching episode details: $e - skipping show',
                    );
                    continue; // Skip on error too
                  }
                }
              } catch (e) {
                debugPrint('Error fetching TV details for ID $tvId: $e');
                continue; // Skip this result
              }
            }

            // Debug: Log what we're about to add
            debugPrint('📝 Creating TV MatchResult:');
            debugPrint('   Title: ${result['name']}');
            final _airDate = result['first_air_date'] as String?;
            debugPrint(
                '   Year: ${(_airDate != null && _airDate.length >= 4) ? _airDate.substring(0, 4) : "null"}');
            debugPrint('   Rating: $rating');
            debugPrint('   Content Rating: $contentRating');
            debugPrint('   Genres: ${genres?.join(", ") ?? "null"}');

            results.add(
              MatchResult(
                newName: result['name'] ?? 'Unknown',
                posterUrl: posterUrl,
                title: result['name'],
                year: result['first_air_date'] != null &&
                        result['first_air_date'].length >= 4
                    ? int.tryParse(result['first_air_date'].substring(0, 4))
                    : null,
                season: season,
                episode: episode,
                episodeTitle: fetchedEpisodeTitle,
                type: 'episode',
                description: description,
                genres: genres,
                actors: actors,
                rating: rating,
                contentRating: contentRating,
                tmdbId: tvId,
                alternativePosterUrls: alternativePosters,
              ),
            );
          }
        }
      } else if (source == 'omdb') {
        final omdb = OmdbService(apiKey);

        if (isMovie) {
          // Search for movies and fetch full details for each
          final allResults = await omdb.searchMovieAll(title, year);

          for (var result in allResults) {
            String? imdbId = result['imdbID'];

            // Basic info from search
            String? posterUrl =
                result['Poster'] != null && result['Poster'] != 'N/A'
                    ? result['Poster']
                    : null;

            // Variables for detailed metadata
            List<String>? genres;
            String? director;
            List<String>? actors;
            String? description;
            double? rating = OmdbService.extractRating(result);
            String? contentRating;
            int? runtime;

            // Fetch full details if we have an ID
            if (imdbId != null) {
              try {
                final details = await omdb.getMovieDetails(imdbId);
                if (details != null) {
                  genres = OmdbService.extractGenres(details);
                  director = OmdbService.extractDirector(details);
                  actors = OmdbService.extractActors(details);
                  description = details['Plot'];
                  if (description == 'N/A') description = null;
                  rating = OmdbService.extractRating(details) ?? rating;
                  contentRating = OmdbService.extractContentRating(details);
                  runtime = OmdbService.extractRuntime(details);
                }
              } catch (e) {
                debugPrint(
                  'Error fetching movie details for IMDb ID $imdbId: $e',
                );
              }
            }

            results.add(
              MatchResult(
                newName: result['Title'] ?? 'Unknown',
                posterUrl: posterUrl,
                title: result['Title'],
                year: result['Year'] != null && result['Year'].length >= 4
                    ? int.tryParse(
                        RegExp(r'\d{4}').firstMatch(result['Year'])?.group(0) ??
                            '',
                      )
                    : null,
                type: 'movie',
                description: description,
                genres: genres,
                director: director,
                actors: actors,
                rating: rating,
                contentRating: contentRating,
                runtime: runtime,
                imdbId: imdbId,
              ),
            );
          }
        } else {
          // Search for TV shows and fetch full details for each
          final allResults = await omdb.searchSeriesAll(title);

          for (var result in allResults) {
            String? imdbId = result['imdbID'];

            // Basic info from search
            String? posterUrl =
                result['Poster'] != null && result['Poster'] != 'N/A'
                    ? result['Poster']
                    : null;

            // Variables for detailed metadata
            List<String>? genres;
            List<String>? actors;
            String? description;
            double? rating = OmdbService.extractRating(result);
            String? contentRating;
            String? fetchedEpisodeTitle =
                episodeTitle; // Start with provided value

            // Fetch full details if we have an ID
            if (imdbId != null) {
              try {
                final details = await omdb.getSeriesDetails(imdbId);
                if (details != null) {
                  genres = OmdbService.extractGenres(details);
                  actors = OmdbService.extractActors(details);
                  description = details['Plot'];
                  if (description == 'N/A') description = null;
                  rating = OmdbService.extractRating(details) ?? rating;
                  contentRating = OmdbService.extractContentRating(details);
                }

                // Fetch specific episode title if season/episode provided
                if (season != null && episode != null) {
                  debugPrint(
                    '🔎 Fetching episode title for S${season}E${episode} from OMDb series $imdbId',
                  );
                  try {
                    final episodeLookup = await omdb.getEpisodeLookup(imdbId, [
                      season,
                    ]);
                    String key = "S${season}E${episode}";
                    if (episodeLookup.containsKey(key)) {
                      fetchedEpisodeTitle = episodeLookup[key];
                      debugPrint(
                        '✅ Fetched episode title for $key: $fetchedEpisodeTitle',
                      );
                    } else {
                      debugPrint(
                        '⚠️ Show "${result['Title']}" doesn\'t have $key - skipping',
                      );
                      continue; // Skip this show - it doesn't have this episode
                    }
                  } catch (e) {
                    debugPrint(
                      'Error fetching episode title: $e - skipping show',
                    );
                    continue; // Skip on error too
                  }
                }
              } catch (e) {
                debugPrint(
                  'Error fetching series details for IMDb ID $imdbId: $e',
                );
                continue; // Skip this result
              }
            }

            results.add(
              MatchResult(
                newName: result['Title'] ?? 'Unknown',
                posterUrl: posterUrl,
                title: result['Title'],
                year: result['Year'] != null && result['Year'].length >= 4
                    ? int.tryParse(
                        RegExp(r'\d{4}').firstMatch(result['Year'])?.group(0) ??
                            '',
                      )
                    : null,
                season: season,
                episode: episode,
                episodeTitle: fetchedEpisodeTitle,
                type: 'episode',
                description: description,
                genres: genres,
                actors: actors,
                rating: rating,
                contentRating: contentRating,
                imdbId: imdbId,
              ),
            );
          }
        }
      } else if (source == 'anidb') {
        // AniDB/MAL search - primarily for anime content
        final anidb = AnidbService(apiKey);

        // Search using hybrid approach (AniDB + Jikan/MAL)
        final allResults = await anidb.searchAnimeAll(title);

        // Build MatchResult list for searchResults
        List<MatchResult> allMatchResults = [];

        // Fetch episode details for all results when building searchResults
        // Users expect complete metadata in Fix Match modal
        for (var result in allResults) {
          // Basic info from search
          String? posterUrl = result['poster_url'];
          String? resultTitle = result['title'];
          String? description = result['description'];

          // Extract year from startdate
          int? year;
          final startDate = result['startdate'];
          if (startDate != null && startDate.toString().length >= 4) {
            year = int.tryParse(startDate.toString().substring(0, 4));
          }

          // Extract rating (AniDB uses 10-point scale, MAL also uses 10-point)
          double? rating;
          final ratingStr = result['rating'];
          if (ratingStr != null) {
            rating = double.tryParse(ratingStr.toString());
          }

          // Extract episode count
          int? episodeCount;
          final epCountStr = result['episodecount'];
          if (epCountStr != null) {
            episodeCount = int.tryParse(epCountStr.toString());
          }

          // For now, treat all anime as TV series
          // AniDB type field includes: TV Series, Movie, OVA, Web, etc.
          String type = isMovie ? 'movie' : 'episode';

          // Variables for episode-specific data
          String? fetchedEpisodeTitle = episodeTitle;

          // Fetch episode title and description if we have season/episode info
          if (!isMovie &&
              season != null &&
              episode != null &&
              (result['aid'] != null || result['mal_id'] != null)) {
            try {
              // Try AniDB first (if we have AID)
              if (result['aid'] != null) {
                final aid = result['aid'] as int;
                debugPrint('🔍 Fetching episodes from AniDB (AID: $aid)');
                final episodeLookup =
                    await anidb.getEpisodeLookup(aid, [season]);
                String key = "S${season}E${episode}";

                if (episodeLookup.containsKey(key)) {
                  fetchedEpisodeTitle = episodeLookup[key];
                  debugPrint(
                    '✅ Fetched episode title for $key: $fetchedEpisodeTitle',
                  );
                } else {
                  debugPrint(
                    'ℹ️  Episode $key not found in "${resultTitle}" - will show without episode title',
                  );
                  fetchedEpisodeTitle = null;
                }
              }
              // Fall back to MAL/Jikan if we have MAL ID
              else if (result['mal_id'] != null) {
                final malId = result['mal_id'] as int;
                debugPrint(
                    '🔍 Fetching episode details from MAL (ID: $malId, Episode: $episode)');

                // Fetch episode details including description
                final episodeDetails =
                    await anidb.getEpisodeDetailsFromMAL(malId, episode);

                if (episodeDetails != null) {
                  fetchedEpisodeTitle = episodeDetails['title'];
                  // Use episode-specific description if available
                  if (episodeDetails['description']?.isNotEmpty == true) {
                    description = episodeDetails['description'];
                  }
                  debugPrint(
                    '✅ Fetched episode details for E${episode}: $fetchedEpisodeTitle',
                  );
                } else {
                  debugPrint(
                    'ℹ️  Episode E${episode} not found in MAL ID $malId - will show without episode details',
                  );
                  fetchedEpisodeTitle = null;
                }
              }
            } catch (e) {
              debugPrint(
                  '⚠️  Error fetching episode details: $e - continuing without it');
              // Don't skip - just proceed without episode title
              fetchedEpisodeTitle = null;
            }
          }

          final matchResult = MatchResult(
            newName: resultTitle ?? 'Unknown',
            posterUrl: posterUrl,
            title: resultTitle,
            year: year,
            season: !isMovie ? season : null,
            episode: !isMovie ? episode : null,
            episodeTitle: !isMovie ? fetchedEpisodeTitle : null,
            type: type,
            description: description,
            genres: result['tags'] != null
                ? List<String>.from(result['tags'])
                : null,
            rating: rating,
            runtime: episodeCount, // Episode count for anime series
            // Anime-specific metadata from Jikan/MAL
            director: null, // Anime credits creators, not directors typically
            actors: null, // Voice actors would require additional API call
            contentRating:
                result['age_rating']?.toString(), // G, PG, PG-13, R, etc.
            studio: result['studios'] != null &&
                    (result['studios'] as List).isNotEmpty
                ? (result['studios'] as List)
                    .join(', ') // Join multiple studios
                : null,
            // Store source-specific IDs
            tmdbId: null,
            imdbId: null,
            // Note: result['mal_id'] available if we add malId field to MatchResult
            alternativePosterUrls:
                null, // AniDB doesn't provide multiple posters
            searchResults: null, // Will be set after loop
          );

          allMatchResults.add(matchResult);
        }

        // Add searchResults to all results for Fix Match functionality
        for (var matchResult in allMatchResults) {
          matchResult.searchResults = List.from(allMatchResults);
        }

        results.addAll(allMatchResults);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      rethrow;
    }

    return results;
  }

  /// Batch match multiple media records to metadata
  /// Now uses centralized searchMetadata for consistency
  static Future<List<MatchResult>> matchTitles(
    List<MediaRecord> records, {
    required String seriesFormat,
    required String movieFormat,
    String? tmdbApiKey,
    String? omdbApiKey,
    String? anidbClientId,
    String metadataSource = 'tmdb',
    bool useSeasonPoster = false,
    int episodeDigits = 2,
    int seasonDigits = 2,
  }) async {
    List<MatchResult> results = [];

    // Determine which API source to use
    // Try preferred source first, then fallback to any available
    String? activeSource;
    String? activeApiKey;

    // Try user's preferred source first
    if (metadataSource == 'tmdb' &&
        tmdbApiKey != null &&
        tmdbApiKey.isNotEmpty) {
      activeSource = 'tmdb';
      activeApiKey = tmdbApiKey;
    } else if (metadataSource == 'omdb' &&
        omdbApiKey != null &&
        omdbApiKey.isNotEmpty) {
      activeSource = 'omdb';
      activeApiKey = omdbApiKey;
    } else if (metadataSource == 'anidb' &&
        anidbClientId != null &&
        anidbClientId.isNotEmpty) {
      activeSource = 'anidb';
      activeApiKey = anidbClientId;
    }

    // Fallback to any available API if preferred source isn't configured
    if (activeSource == null) {
      if (tmdbApiKey != null && tmdbApiKey.isNotEmpty) {
        activeSource = 'tmdb';
        activeApiKey = tmdbApiKey;
        debugPrint(
            '⚠️ Preferred source "$metadataSource" not configured, using TMDB instead');
      } else if (omdbApiKey != null && omdbApiKey.isNotEmpty) {
        activeSource = 'omdb';
        activeApiKey = omdbApiKey;
        debugPrint(
            '⚠️ Preferred source "$metadataSource" not configured, using OMDb instead');
      } else if (anidbClientId != null && anidbClientId.isNotEmpty) {
        activeSource = 'anidb';
        activeApiKey = anidbClientId;
        debugPrint(
            '⚠️ Preferred source "$metadataSource" not configured, using AniDB instead');
      }
    }

    if (activeSource == null || activeApiKey == null) {
      debugPrint('⚠️ No API keys configured for batch matching');
      return results;
    }

    debugPrint('📦 Batch matching ${records.length} files using $activeSource');

    for (var record in records) {
      try {
        if (record.title == null) {
          debugPrint('⚠️ Skipping record with no title');
          continue;
        }

        // Use centralized search to get comprehensive metadata
        final searchResults = await searchMetadata(
          title: record.title!,
          year: record.year,
          isMovie: record.type == 'movie',
          source: activeSource,
          apiKey: activeApiKey,
          season: record.season,
          episode: record.episode,
          episodeTitle: null, // Will be fetched for the matched show
          useSeasonPoster: useSeasonPoster,
        );

        if (searchResults.isEmpty) {
          debugPrint('⚠️ No results found for: ${record.title}');
          continue;
        }

        // Take the first result as the best match
        final bestMatch = searchResults.first;

        // Create formatted filename
        String format = record.type == 'episode' ? seriesFormat : movieFormat;
        Map<String, dynamic> context;

        if (record.type == 'episode') {
          context = {
            "series_name": bestMatch.title,
            "year": bestMatch.year,
            "season_number": record.season?.toString().padLeft(seasonDigits, '0'),
            "episode_number": record.episode?.toString().padLeft(episodeDigits, '0'),
            "episode_title": bestMatch.episodeTitle ?? "Title",
          };
        } else {
          context = {"movie_name": bestMatch.title, "year": bestMatch.year};
        }

        // Create the final match result with formatted name and all search results
        results.add(
          MatchResult(
            newName:
                "${createFormattedTitle(format, context)}.${record.container}",
            posterUrl: bestMatch.posterUrl,
            title: bestMatch.title,
            year: bestMatch.year,
            season: bestMatch.season,
            episode: bestMatch.episode,
            episodeTitle: bestMatch.episodeTitle,
            type: bestMatch.type,
            description: bestMatch.description,
            genres: bestMatch.genres,
            director: bestMatch.director,
            actors: bestMatch.actors,
            rating: bestMatch.rating,
            contentRating: bestMatch.contentRating,
            runtime: bestMatch.runtime,
            studio: bestMatch.studio,
            tmdbId: bestMatch.tmdbId,
            imdbId: bestMatch.imdbId,
            alternativePosterUrls: bestMatch.alternativePosterUrls,
            searchResults: searchResults, // All results for fix match modal
            coverBytes: null, // Will be downloaded separately if needed
          ),
        );

        debugPrint('✅ Matched: ${record.title} -> ${bestMatch.title}');
      } catch (e) {
        debugPrint('❌ Error matching ${record.title}: $e');
        // Continue with next record instead of failing entire batch
      }
    }

    debugPrint(
      '📦 Batch matching complete: ${results.length}/${records.length} matched',
    );
    return results;
  }

  /// Perform batch file renaming
  static void performFileRenaming(
    List<String> oldPaths,
    List<String> newNames,
  ) {
    for (int i = 0; i < oldPaths.length; i++) {
      String oldPath = oldPaths[i];
      String newPath = p.join(p.dirname(oldPath), newNames[i]);
      if (oldPath != newPath) {
        debugPrint('Renaming: $oldPath -> $newPath');
        File(oldPath).renameSync(newPath);
      }
    }
  }

  // FFmpeg availability cache
  static bool? _ffmpegAvailable;
  static String? _ffmpegPath;

  /// Check FFmpeg availability (cached to avoid repeated checks)
  /// Checks for bundled ffmpeg.exe first, then falls back to PATH
  static Future<bool> _checkFFmpegAvailable({SettingsService? settings}) async {
    // Don't use cache if settings provided (path might have changed)
    if (settings == null && _ffmpegAvailable != null) return _ffmpegAvailable!;

    // 1. Try custom folder path from settings
    if (settings != null && settings.ffmpegPath.isNotEmpty) {
      try {
        final binPath = p.join(settings.ffmpegPath, 'bin', 'ffmpeg.exe');
        if (File(binPath).existsSync()) {
          var result = await Process.run(binPath, ['-version']);
          if (result.exitCode == 0) {
            _ffmpegPath = binPath;
            _ffmpegAvailable = true;
            debugPrint('✅ Using custom FFmpeg: $binPath');
            return true;
          }
        }

        // Try without bin/ subdirectory
        final directPath = p.join(settings.ffmpegPath, 'ffmpeg.exe');
        if (File(directPath).existsSync()) {
          var result = await Process.run(directPath, ['-version']);
          if (result.exitCode == 0) {
            _ffmpegPath = directPath;
            _ffmpegAvailable = true;
            debugPrint('✅ Using custom FFmpeg: $directPath');
            return true;
          }
        }
      } catch (e) {
        // Continue to bundled check
      }
    }

    // 2. Try bundled ffmpeg.exe in app directory
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final bundledFfmpeg = p.join(exeDir, 'ffmpeg.exe');

      if (File(bundledFfmpeg).existsSync()) {
        var result = await Process.run(bundledFfmpeg, ['-version']);
        if (result.exitCode == 0) {
          _ffmpegPath = bundledFfmpeg;
          _ffmpegAvailable = true;
          debugPrint('✅ Using bundled FFmpeg: $bundledFfmpeg');
          return true;
        }
      }
    } catch (e) {
      // Continue to PATH check
    }

    // 3. Fall back to FFmpeg in PATH
    try {
      var result = await Process.run('ffmpeg', ['-version']);
      _ffmpegAvailable = result.exitCode == 0;
      _ffmpegPath = 'ffmpeg'; // Use from PATH
      if (_ffmpegAvailable!) {
        debugPrint('✅ Using FFmpeg from PATH');
      }
      return _ffmpegAvailable!;
    } catch (e) {
      _ffmpegAvailable = false;
      return false;
    }
  }

  /// Generic tool path resolver - checks UserData → custom → bundled
  /// Returns null if tool not found (we skip PATH check to avoid hangs)
  static Future<String?> _resolveToolPath(
    String toolName,
    String? customPath,
  ) async {
    // 0. Try UserData/tools folder first
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final toolNameLower = toolName.toLowerCase();
      String userDataSubDir;

      // Map tool names to their UserData subdirectory names
      if (toolNameLower == 'mkvpropedit') {
        userDataSubDir = 'mkvtoolnix';
      } else if (toolNameLower == 'atomicparsley') {
        userDataSubDir = 'atomicparsley';
      } else {
        userDataSubDir = toolNameLower;
      }

      final userDataTool = p.join(
        exeDir,
        'UserData',
        'tools',
        userDataSubDir,
        '$toolName.exe',
      );
      if (File(userDataTool).existsSync()) {
        debugPrint('✅ Using UserData $toolName: $userDataTool');
        return userDataTool;
      }
    } catch (e) {
      // Continue to custom path check
    }

    // 1. Try custom path from settings
    if (customPath != null && customPath.isNotEmpty) {
      // Try bin/ subdirectory first (like FFmpeg structure)
      final binPath = p.join(customPath, 'bin', '$toolName.exe');
      if (File(binPath).existsSync()) {
        debugPrint('✅ Using custom $toolName: $binPath');
        return binPath;
      }

      // Try direct path in folder
      final directPath = p.join(customPath, '$toolName.exe');
      if (File(directPath).existsSync()) {
        debugPrint('✅ Using custom $toolName: $directPath');
        return directPath;
      }
    }

    // 2. Try bundled tool in app directory (deprecated - will be removed)
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final bundledTool = p.join(exeDir, '$toolName.exe');

      if (File(bundledTool).existsSync()) {
        debugPrint('✅ Using bundled $toolName: $bundledTool');
        return bundledTool;
      }
    } catch (e) {
      // Tool not found
    }

    // Tool not found - return null to trigger FFmpeg fallback
    return null;
  }

  /// Resolve mkvpropedit path (custom → bundled → PATH)
  static Future<String?> _resolveMkvpropedit({
    SettingsService? settings,
  }) async {
    return _resolveToolPath('mkvpropedit', settings?.mkvpropeditPath);
  }

  /// Resolve AtomicParsley path (custom → bundled → PATH)
  static Future<String?> _resolveAtomicParsley({
    SettingsService? settings,
  }) async {
    return _resolveToolPath('AtomicParsley', settings?.atomicparsleyPath);
  }

  /// Escape special characters for FFmpeg metadata
  static String _escapeMetadata(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll('=', '\\=')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '')
        .replaceAll('"', '\\"');
  }

  /// Read existing metadata from a media file using FFprobe
  static Future<MatchResult?> readMetadata(
    String filePath, {
    SettingsService? settings,
  }) async {
    debugPrint("\n" + "=" * 60);
    debugPrint("📖 READING METADATA: ${p.basename(filePath)}");
    debugPrint("=" * 60);

    // Validate input file
    if (!File(filePath).existsSync()) {
      debugPrint("❌ File doesn't exist: $filePath");
      debugPrint("=" * 60 + "\n");
      return null;
    }

    String ext = p.extension(filePath).toLowerCase();
    if (ext != '.mp4' && ext != '.mkv') {
      debugPrint("⚠️  Unsupported format (only .mp4 and .mkv supported)");
      debugPrint("=" * 60 + "\n");
      return null;
    }

    // Check FFprobe availability
    String? ffprobePath;

    // 1. Try custom folder path from settings first
    if (settings != null && settings.ffmpegPath.isNotEmpty) {
      // User provides folder path, we look in bin/ subdirectory
      final binPath = p.join(settings.ffmpegPath, 'bin', 'ffprobe.exe');
      if (File(binPath).existsSync()) {
        ffprobePath = binPath;
        debugPrint('✅ Using custom FFprobe: $ffprobePath');
      } else {
        // Try without bin/ subdirectory (in case user pointed directly to bin folder)
        final directPath = p.join(settings.ffmpegPath, 'ffprobe.exe');
        if (File(directPath).existsSync()) {
          ffprobePath = directPath;
          debugPrint('✅ Using custom FFprobe: $ffprobePath');
        } else {
          debugPrint('⚠️  FFprobe not found in: ${settings.ffmpegPath}');
          debugPrint('    Expected: $binPath or $directPath');
        }
      }
    }

    // 2. Try bundled ffprobe (in same directory as exe)
    if (ffprobePath == null) {
      try {
        final exePath = Platform.resolvedExecutable;
        final exeDir = p.dirname(exePath);
        final bundledFfprobe = p.join(exeDir, 'ffprobe.exe');

        if (File(bundledFfprobe).existsSync()) {
          ffprobePath = bundledFfprobe;
          debugPrint('✅ Using bundled FFprobe: $bundledFfprobe');
        }
      } catch (e) {
        debugPrint('⚠️  Could not locate bundled FFprobe: $e');
      }
    }

    // 3. If still not found, just try "ffprobe" (assume it's in PATH)
    if (ffprobePath == null) {
      ffprobePath = 'ffprobe';
      debugPrint(
        '⚠️  FFprobe not found in custom/bundled paths, trying system PATH...',
      );
    }

    // Run FFprobe to get metadata
    try {
      var result = await Process.run(
        ffprobePath, // Already checked for null above
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          filePath,
        ],
        runInShell:
            false, // Don't use shell to avoid issues with spaces in paths
      );

      if (result.exitCode != 0) {
        debugPrint("❌ FFprobe failed (exit ${result.exitCode})");
        if (result.stderr.toString().isNotEmpty) {
          debugPrint("   Stderr: ${result.stderr}");
        }
        debugPrint("=" * 60 + "\n");
        return null;
      }

      // Parse JSON output
      final jsonData = json.decode(result.stdout);
      final format = jsonData['format'];

      if (format == null || format['tags'] == null) {
        debugPrint("ℹ️  No metadata tags found");
        debugPrint("=" * 60 + "\n");
        return null;
      }

      final tags = format['tags'];

      // DEBUG: Print ALL tags found
      debugPrint("🔍 ALL TAGS FOUND:");
      tags.forEach((key, value) {
        debugPrint("   $key: $value");
      });
      debugPrint("");

      // Extract metadata - check multiple variations
      String? title = tags['title'] ?? tags['TITLE'];
      String? yearStr = tags['year'] ??
          tags['date'] ??
          tags['YEAR'] ??
          tags['DATE'] ??
          tags['DATE_RELEASED'] ?? // MKV standard tag
          tags['date_released'];
      int? year;
      if (yearStr != null) {
        year = int.tryParse(yearStr.toString().substring(0, 4));
      }

      String? description = tags['comment'] ??
          tags['description'] ??
          tags['synopsis'] ??
          tags['COMMENT'] ??
          tags['DESCRIPTION'] ??
          tags['SYNOPSIS'];

      String? genre = tags['genre'] ?? tags['GENRE'];
      List<String>? genres = genre?.split(',').map((e) => e.trim()).toList();

      String? director = tags['director'] ??
          tags['artist'] ??
          tags['DIRECTOR'] ??
          tags['ARTIST'];

      String? actorStr =
          tags['actor'] ?? tags['ACTOR'] ?? tags['actors'] ?? tags['ACTORS'];
      List<String>? actors = actorStr?.split(',').map((e) => e.trim()).toList();

      double? rating;
      String? ratingStr = tags['rating'] ?? tags['RATING'];
      if (ratingStr != null) {
        rating = double.tryParse(ratingStr);
      }

      String? contentRating = tags['content_rating'] ??
          tags['CONTENT_RATING'] ??
          tags['LAW_RATING'] ?? // MKV standard tag
          tags['law_rating'];

      // TV Show metadata - check MANY variations!
      String? show = tags['show'] ??
          tags['SHOW'] ??
          tags['series'] ??
          tags['SERIES'] ??
          tags['album'] ?? // Sometimes stored as album
          tags['ALBUM'];

      // Season - check multiple possible names
      String? seasonStr = tags['season_number'] ??
          tags['SEASON_NUMBER'] ??
          tags['season'] ??
          tags['SEASON'] ??
          tags['PART'] ??
          tags['part'];
      int? season;
      if (seasonStr != null) {
        season = int.tryParse(seasonStr.toString());
      }

      // Episode - check multiple possible names
      String? episodeStr = tags['episode_sort'] ??
          tags['EPISODE_SORT'] ??
          tags['episode'] ??
          tags['EPISODE'] ??
          tags['EPISODE_NUMBER'] ??
          tags['episode_number'] ??
          tags['PART_NUMBER'] ??
          tags['part_number'] ??
          tags['track'] ?? // Sometimes stored as track
          tags['TRACK'];
      int? episode;
      if (episodeStr != null) {
        episode = int.tryParse(episodeStr.toString());
      }

      String? episodeTitle = tags['episode_id'] ??
          tags['EPISODE_ID'] ??
          tags['subtitle'] ??
          tags['SUBTITLE'];

      // SMART PARSING: Check if TITLE contains episode pattern (S##E##)
      // This prevents duplication when TITLE is already formatted
      if (title != null && title.contains(RegExp(r'[Ss]\d{1,2}[Ee]\d{1,2}'))) {
        debugPrint("🧠 Smart parsing: TITLE contains episode pattern");

        // Extract from TITLE instead of filename
        RegExpMatch? titleMatch = RegExp(
          r'[Ss](\d{1,2})[Ee](\d{1,2})',
        ).firstMatch(title);

        if (titleMatch != null) {
          // Parse season/episode if not already in tags
          season ??= int.tryParse(titleMatch.group(1)!);
          episode ??= int.tryParse(titleMatch.group(2)!);

          // Extract show name (text before S##E##)
          if (show == null || show.isEmpty) {
            String before = title.substring(0, titleMatch.start).trim();
            before = before.replaceFirst(RegExp(r'[\s\-\.]+$'), '');
            if (before.isNotEmpty) {
              show = before;
            }
          }

          // Extract episode title (text after S##E##)
          if (episodeTitle == null || episodeTitle.isEmpty) {
            int afterPattern = titleMatch.end;
            String after = title.substring(afterPattern).trim();
            after = after.replaceFirst(RegExp(r'^[\s\-\.]+'), '');
            if (after.isNotEmpty) {
              episodeTitle = after;
            }
          }

          // For 'title' field, use the show name for TV episodes
          title = show;
        }
      } else {
        // Standard parsing: Check filename for S##E## pattern if tags don't have season/episode
        if (season == null || episode == null) {
          String filename = p.basenameWithoutExtension(filePath);
          RegExpMatch? match = RegExp(
            r'[Ss](\d{1,2})[Ee](\d{1,2})',
          ).firstMatch(filename);
          if (match != null) {
            season ??= int.tryParse(match.group(1)!);
            episode ??= int.tryParse(match.group(2)!);

            // Extract episode title from filename
            if (episodeTitle == null) {
              int afterPattern = match.end;
              String after = filename.substring(afterPattern).trim();
              after = after.replaceFirst(RegExp(r'^[\s\-\.]+'), '');
              if (after.isNotEmpty) {
                episodeTitle = after;
              }
            }

            // Extract show name from filename
            if (show == null || show.isEmpty) {
              String before = filename.substring(0, match.start).trim();
              before = before.replaceFirst(RegExp(r'[\s\-\.]+$'), '');
              if (before.isNotEmpty) {
                show = before;
                // For TV episodes, title should be the show name
                if (title == null || title.isEmpty) {
                  title = show;
                }
              }
            }
          }
        }
      }

      // Determine type
      String type = (season != null && episode != null) ? 'episode' : 'movie';

      debugPrint("📊 Found metadata:");
      debugPrint("   Title: ${title ?? 'N/A'}");
      debugPrint("   Year: ${year ?? 'N/A'}");
      debugPrint("   Type: $type");
      if (type == 'episode') {
        debugPrint("   Show: ${show ?? 'N/A'}");
        debugPrint("   Season: ${season ?? 'N/A'}");
        debugPrint("   Episode: ${episode ?? 'N/A'}");
        debugPrint("   Episode Title: ${episodeTitle ?? 'N/A'}");
      }
      debugPrint("=" * 60 + "\n");

      // Generate newName using user format settings (if provided)
      String newName;
      final ext = p.extension(filePath);

      if (type == 'episode' && season != null && episode != null) {
        // TV Show format - use user's series format template
        final String formatTemplate = settings?.seriesFormat ??
            "{series_name} - S{season_number}E{episode_number} - {episode_title}";

        Map<String, dynamic> context = {
          'series_name': title ?? show ?? 'Unknown Show',
          'season_number': season.toString().padLeft(settings?.seasonDigits ?? 2, '0'),
          'episode_number': episode.toString().padLeft(settings?.episodeDigits ?? 2, '0'),
          'episode_title': episodeTitle ?? '',
        };

        newName = createFormattedTitle(formatTemplate, context) + ext;
      } else {
        // Movie format - use user's movie format template
        final String formatTemplate =
            settings?.movieFormat ?? "{movie_name} ({year})";

        Map<String, dynamic> context = {
          'movie_name': title ?? 'Unknown Movie',
          'year': year?.toString() ?? '',
        };

        newName = createFormattedTitle(formatTemplate, context) + ext;
      }

      debugPrint("📝 Generated newName: $newName");
      debugPrint("=" * 60 + "\n");

      // Note: Cover extraction is skipped during initial file import for speed
      // Covers will be extracted later when needed (during rename/embed operations)
      Uint8List? coverBytes;

      // Create MatchResult with existing metadata
      return MatchResult(
        newName: newName, // Properly formatted name
        title: title ?? (type == 'episode' ? show : null),
        year: year,
        season: season,
        episode: episode,
        episodeTitle: episodeTitle,
        type: type,
        description: description,
        genres: genres,
        director: director,
        actors: actors,
        rating: rating,
        contentRating: contentRating,
        coverBytes: coverBytes, // Include extracted cover art as bytes
      );
    } catch (e) {
      debugPrint("❌ Error reading metadata: $e");
      debugPrint("=" * 60 + "\n");
      return null;
    }
  }

  /// Download cover art from URL
  static Future<void> downloadCover(String url, String savePath) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        File(savePath).writeAsBytesSync(response.bodyBytes);
        debugPrint('✅ Cover downloaded: $savePath');
      } else {
        debugPrint('❌ Failed to download cover: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error downloading cover: $e');
    }
  }

  /// Extract cover bytes from media file (wrapper around CoverExtractor)
  static Future<Uint8List?> extractCover(
    String filePath, {
    SettingsService? settings,
  }) async {
    return await CoverExtractor.extractCoverBytes(filePath, settings: settings);
  }

  /// Extract embedded cover art from media file and save to disk
  static Future<String?> extractCoverArt(
    String filePath, {
    SettingsService? settings,
  }) async {
    // Check FFmpeg availability
    String? ffmpegPath;

    // 1. Try custom folder path from settings first
    if (settings != null && settings.ffmpegPath.isNotEmpty) {
      // User provides folder path, we look in bin/ subdirectory
      final binPath = p.join(settings.ffmpegPath, 'bin', 'ffmpeg.exe');
      if (File(binPath).existsSync()) {
        ffmpegPath = binPath;
      } else {
        // Try without bin/ subdirectory
        final directPath = p.join(settings.ffmpegPath, 'ffmpeg.exe');
        if (File(directPath).existsSync()) {
          ffmpegPath = directPath;
        }
      }
    }

    // 2. Try bundled FFmpeg
    if (ffmpegPath == null) {
      try {
        final exePath = Platform.resolvedExecutable;
        final exeDir = p.dirname(exePath);
        final bundledFfmpeg = p.join(exeDir, 'ffmpeg.exe');

        if (File(bundledFfmpeg).existsSync()) {
          ffmpegPath = bundledFfmpeg;
        }
      } catch (e) {
        // Continue to PATH check
      }
    }

    // 3. Try system PATH
    if (ffmpegPath == null) {
      try {
        var result = await Process.run('ffmpeg', ['-version']);
        if (result.exitCode == 0) {
          ffmpegPath = 'ffmpeg';
        }
      } catch (e) {
        return null; // FFmpeg not available
      }
    }

    // Create cache folder in app directory (next to MyMeta.exe)
    final exePath = Platform.resolvedExecutable;
    final appDir = p.dirname(exePath);
    final cacheDir = Directory(p.join(appDir, 'Cache'));

    // Create cache directory if it doesn't exist
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    // Use filename as unique identifier for the cover
    final fileName = p.basenameWithoutExtension(filePath);
    final coverPath = p.join(cacheDir.path, '${fileName}_cover.jpg');

    try {
      // First try: Extract attached picture (works for MKV files with embedded covers)
      var result = await Process.run(
        ffmpegPath!,
        [
          '-dump_attachment:t', '', // Dump all attachments with mimetype image
          '-i', filePath,
          '-y',
        ],
        runInShell: true,
        workingDirectory: cacheDir.path,
      );

      // Check if any image files were extracted
      final extractedFiles = cacheDir
          .listSync()
          .where(
            (f) =>
                f.path.toLowerCase().endsWith('.jpg') ||
                f.path.toLowerCase().endsWith('.png') ||
                f.path.toLowerCase().endsWith('.jpeg'),
          )
          .toList();

      if (extractedFiles.isNotEmpty) {
        // Rename first extracted image to our standard name
        final extractedFile = File(extractedFiles.first.path);
        extractedFile.renameSync(coverPath);
        if (File(coverPath).existsSync() &&
            File(coverPath).lengthSync() > 5000) {
          debugPrint('✅ Extracted cover via attachment: $coverPath');
          return coverPath;
        }
      }

      // Second try: Extract from video stream (fallback for files without attached pictures)
      result = await Process.run(
          ffmpegPath,
          [
            '-i', filePath,
            '-vf', 'select=eq(pict_type\\,I)', // Select I-frames
            '-frames:v', '1', // Only first frame
            '-q:v', '2', // High quality
            '-y',
            coverPath,
          ],
          runInShell: true);

      if (result.exitCode == 0 && File(coverPath).existsSync()) {
        final fileSize = File(coverPath).lengthSync();
        if (fileSize > 5000) {
          // At least 5KB to ensure it's a real image
          debugPrint('✅ Extracted cover via video frame: $coverPath');
          return coverPath;
        } else {
          debugPrint(
            '⚠️  Extracted file too small ($fileSize bytes), probably empty',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error extracting cover: $e');
    }

    return null;
  }

  /// Remove old cover attachments from MKV file before attaching new one
  /// Prevents duplicate covers and fixes Windows Explorer caching issues
  static Future<void> _removeOldCoversFromMkv(
    String filePath,
    String mkvpropeditPath,
  ) async {
    try {
      // Find all existing cover attachments
      var identifyResult = await Process.run(
        mkvpropeditPath.replaceAll('mkvpropedit.exe', 'mkvmerge.exe'),
        ['--identify', filePath],
        runInShell: false,
      );

      // Parse attachment IDs that need to be deleted
      List<String> deleteArgs = [filePath];
      RegExp attachmentRegex = RegExp(r'Attachment ID (\d+):.*cover');
      for (var match in attachmentRegex.allMatches(
        identifyResult.stdout.toString(),
      )) {
        deleteArgs.addAll(['--delete-attachment', match.group(1)!]);
      }

      // Delete existing covers if any found
      if (deleteArgs.length > 1) {
        await Process.run(mkvpropeditPath, deleteArgs, runInShell: false);
        debugPrint('🗑️  Removed ${(deleteArgs.length - 1) ~/ 2} old cover(s) from MKV');
      }
    } catch (e) {
      debugPrint('⚠️  Error removing old covers from MKV: $e');
    }
  }

  /// Remove old cover (attached_pic) from MP4 file before attaching new one
  /// Uses FFmpeg to re-encode video streams while dropping old cover
  /// Prevents old cover from persisting in Windows Explorer
  static Future<void> _removeOldCoversFromMp4(
    String filePath,
    String? ffmpegPath,
  ) async {
    if (ffmpegPath == null || ffmpegPath.isEmpty) return;

    try {
      // Check if file has attached images
      final probeResult = await Process.run(
        ffmpegPath.replaceAll('ffmpeg.exe', 'ffprobe.exe'),
        [
          '-v', 'error',
          '-select_streams', 'v:1', // Check for second video stream (attached pic)
          '-show_entries', 'stream=codec_type',
          '-of', 'csv=p=0',
          filePath,
        ],
        runInShell: false,
      );

      // If there's an attached picture stream, create a copy without it
      if (probeResult.stdout.toString().contains('video')) {
        final tempPath = '$filePath.TEMP.mp4';

        debugPrint('⏳ Removing old cover from MP4...');
        final result = await Process.run(
          ffmpegPath,
          [
            '-i', filePath,
            '-c', 'copy',
            '-map', '0:v:0', // Only main video
            '-map', '0:a?', // All audio
            '-map', '0:s?', // All subtitles
            '-map', '-0:v:1', // Exclude attached pictures
            '-y',
            tempPath,
          ],
          runInShell: false,
        );

        if (result.exitCode == 0 && File(tempPath).existsSync()) {
          File(filePath).deleteSync();
          File(tempPath).renameSync(filePath);
          debugPrint('🗑️  Removed old cover from MP4');
        }
      }
    } catch (e) {
      debugPrint('⚠️  Error removing old covers from MP4: $e');
    }
  }

  /// Embed metadata into MKV file using mkvpropedit with XML tags (fast in-place)
  static Future<bool> _embedMetadataMkv(
    String filePath,
    String? coverPath,
    MatchResult metadata, {
    SettingsService? settings,
  }) async {
    String? toolPath = await _resolveMkvpropedit(settings: settings);
    if (toolPath == null) {
      debugPrint('mkvpropedit not available');
      return false;
    }
    if (!File(filePath).existsSync()) {
      debugPrint('MKV file not found');
      return false;
    }

    try {
      bool hasAttachment = false;
      bool hasTags = false;
      final containerTitle = _buildContainerTitle(
        metadata,
        seasonDigits: settings?.seasonDigits ?? 2,
        episodeDigits: settings?.episodeDigits ?? 2,
      );

      // Step 1: Attach cover (delete existing covers first to prevent duplicates!)
      if (coverPath != null && File(coverPath).existsSync()) {
        // Remove old covers to prevent duplicates and Windows Explorer caching issues
        await _removeOldCoversFromMkv(filePath, toolPath);

        // Now add the new cover
        var result = await Process.run(
            toolPath,
            [
              filePath,
              '--attachment-name',
              'cover.jpg',
              '--attachment-mime-type',
              'image/jpeg',
              '--add-attachment',
              coverPath,
            ],
            runInShell: false);
        if (result.exitCode == 0) {
          debugPrint('Cover attached');
          hasAttachment = true;
        } else {
          debugPrint('Cover failed: ${result.stderr}');
        }
      }

      // Step 2: XML tags (writes to Tags element where FFprobe reads!)
      StringBuffer xml = StringBuffer();
      xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      xml.writeln('<Tags><Tag><Targets></Targets>');
      int tagCount = 0;

      void addTag(String name, String? value) {
        if (value != null && value.isNotEmpty) {
          String escaped = value
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;');
          xml.writeln(
            '<Simple><Name>$name</Name><String>$escaped</String></Simple>',
          );
          tagCount++;
        }
      }

      addTag('TITLE', metadata.title);
      if (metadata.year != null)
        addTag('DATE_RELEASED', metadata.year.toString());
      addTag('DESCRIPTION', metadata.description);
      addTag('SYNOPSIS', metadata.description);
      if (metadata.genres != null && metadata.genres!.isNotEmpty)
        addTag('GENRE', metadata.genres!.join(', '));
      addTag('DIRECTOR', metadata.director);
      if (metadata.actors != null && metadata.actors!.isNotEmpty)
        addTag('ACTOR', metadata.actors!.join(', '));
      if (metadata.rating != null) addTag('RATING', metadata.rating.toString());
      addTag('LAW_RATING', metadata.contentRating);
      if (metadata.season != null && metadata.episode != null) {
        addTag('CONTENT_TYPE', 'TV Show');
        addTag('SEASON/PART_NUMBER', metadata.season.toString());
        addTag('EPISODE/PART_NUMBER', metadata.episode.toString());
        addTag('EPISODE/TITLE', metadata.episodeTitle);
      } else {
        addTag('CONTENT_TYPE', 'Movie');
      }
      xml.writeln('</Tag></Tags>');

      if (tagCount > 0) {
        final exeDir = p.dirname(Platform.resolvedExecutable);
        final cacheDir = p.join(exeDir, 'UserData', 'Cache');
        await Directory(cacheDir).create(recursive: true);
        String xmlPath = p.join(
          cacheDir,
          'tags_${DateTime.now().millisecondsSinceEpoch}.xml',
        );
        await File(xmlPath).writeAsString(xml.toString());
        debugPrint('Writing $tagCount tags (in-place)...');
        var result = await Process.run(
            toolPath,
            [
              filePath,
              '--tags',
              'all:$xmlPath',
              // Set segment info title and video track name in the same pass
              if (containerTitle.isNotEmpty) ...['--edit', 'info', '--set', 'title=$containerTitle'],
              if (containerTitle.isNotEmpty) ...['--edit', 'track:v1', '--set', 'name=$containerTitle'],
            ],
            runInShell: false);
        try {
          await File(xmlPath).delete();
        } catch (e) {}
        if (result.exitCode == 0) {
          debugPrint('$tagCount tags written');
          hasTags = true;
        } else {
          debugPrint('Tags failed: ${result.stderr}');
        }
      }

      if (hasAttachment || hasTags) {
        debugPrint('MKV complete (fast in-place)');
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('Error: $e');
      return false;
    }
  }

  /// Embed metadata into MP4 file using AtomicParsley (fast single-pass editing)
  static Future<bool> _embedMetadataMp4(
    String filePath,
    String? coverPath,
    MatchResult metadata, {
    SettingsService? settings,
  }) async {
    String? toolPath = await _resolveAtomicParsley(settings: settings);
    if (toolPath == null) {
      debugPrint('⚠️  AtomicParsley not available');
      return false;
    }

    // Remove old covers to prevent duplicates and Windows Explorer caching issues
    if (coverPath != null && File(coverPath).existsSync()) {
      await _removeOldCoversFromMp4(filePath, _ffmpegPath);
    }

    List<String> args = [filePath];

    // Map metadata fields to AtomicParsley arguments
    final containerTitle = _buildContainerTitle(metadata);
    if (containerTitle.isNotEmpty) {
      args.addAll(['--title', containerTitle]);
    }

    if (metadata.year != null) {
      args.addAll(['--year', metadata.year.toString()]);
    }

    if (metadata.description != null && metadata.description!.isNotEmpty) {
      args.addAll(['--description', metadata.description!]);
      args.addAll(['--longdesc', metadata.description!]);
    }

    if (metadata.genres != null && metadata.genres!.isNotEmpty) {
      args.addAll(['--genre', metadata.genres!.first]);
    }

    if (metadata.director != null && metadata.director!.isNotEmpty) {
      args.addAll(['--artist', metadata.director!]);
    }

    // TV Show specifics
    if (metadata.season != null && metadata.episode != null) {
      args.addAll(['--TVShowName', metadata.title ?? '']);
      args.addAll(['--TVSeasonNum', metadata.season.toString()]);
      args.addAll(['--TVEpisodeNum', metadata.episode.toString()]);
      if (metadata.episodeTitle != null && metadata.episodeTitle!.isNotEmpty) {
        args.addAll(['--TVEpisode', metadata.episodeTitle!]);
      }
    }

    // Add cover art
    if (coverPath != null && File(coverPath).existsSync()) {
      args.addAll(['--artwork', coverPath]);
    }

    // Overwrite in place
    args.add('--overWrite');

    // DEBUG: Log exact command and arguments
    debugPrint('🔧 ATOMICPARSLEY COMMAND:');
    debugPrint('   Tool: $toolPath');
    debugPrint('   File: $filePath');
    debugPrint('   Args: ${args.join(' | ')}');
    debugPrint('   Full: "$toolPath" ${args.map((a) => '"$a"').join(' ')}');

    // Check file before
    File targetFile = File(filePath);
    DateTime beforeTime = targetFile.lastModifiedSync();
    int beforeSize = targetFile.lengthSync();
    debugPrint(
      '📊 BEFORE: Modified=${beforeTime.toIso8601String()}, Size=$beforeSize',
    );

    try {
      // Use runInShell: false to avoid path quoting issues with spaces
      var result = await Process.run(toolPath, args, runInShell: false);

      debugPrint('📤 Exit Code: ${result.exitCode}');

      // ALWAYS log stdout and stderr
      String stdout = result.stdout.toString().trim();
      String stderr = result.stderr.toString().trim();

      if (stdout.isNotEmpty) {
        debugPrint('📄 STDOUT:');
        debugPrint(stdout);
      }

      if (stderr.isNotEmpty) {
        debugPrint('⚠️  STDERR:');
        debugPrint(stderr);
      }

      // Wait for file system to sync
      await Future.delayed(Duration(milliseconds: 500));

      // Check file after
      if (targetFile.existsSync()) {
        DateTime afterTime = targetFile.lastModifiedSync();
        int afterSize = targetFile.lengthSync();
        debugPrint(
          '📊 AFTER: Modified=${afterTime.toIso8601String()}, Size=$afterSize',
        );

        bool timeChanged = afterTime.isAfter(beforeTime);
        bool sizeChanged = afterSize != beforeSize;

        debugPrint('   Time changed: $timeChanged');
        debugPrint('   Size changed: $sizeChanged');

        if (!timeChanged && !sizeChanged) {
          debugPrint(
            '❌ FILE NOT MODIFIED - AtomicParsley did NOT write metadata!',
          );
          debugPrint('   This means the command failed silently');
          return false;
        }
      }

      if (result.exitCode == 0) {
        debugPrint('✅ MP4 metadata embedded with AtomicParsley');
        return true;
      } else {
        debugPrint('❌ AtomicParsley failed (exit ${result.exitCode})');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error running AtomicParsley: $e');
      return false;
    }
  }

  /// Main metadata embedding dispatcher - tries format-specific tools first, falls back to FFmpeg
  static Future<void> embedMetadata(
    String filePath,
    String? coverPath,
    MatchResult metadata, {
    SettingsService? settings,
  }) async {
    debugPrint("\n" + "=" * 60);
    debugPrint("🎬 EMBEDDING: ${p.basename(filePath)}");
    debugPrint("=" * 60);

    // Validate input file
    if (!File(filePath).existsSync()) {
      debugPrint("❌ Input file doesn't exist: $filePath");
      debugPrint("=" * 60 + "\n");
      return;
    }

    String ext = p.extension(filePath).toLowerCase();
    bool hasCover = coverPath != null && File(coverPath).existsSync();

    debugPrint("📁 Extension: $ext");
    debugPrint("🖼️  Cover: ${hasCover ? '✅ ' + coverPath : '❌ None'}");

    // Check supported formats
    if (ext != '.mp4' && ext != '.mkv') {
      debugPrint("⚠️  Unsupported format (only .mp4 and .mkv supported)");
      debugPrint("=" * 60 + "\n");
      return;
    }

    bool success = false;

    // Try format-specific tool first for maximum speed
    if (ext == '.mkv') {
      debugPrint("🔧 Using mkvpropedit with XML tags (fast in-place)...");
      success = await _embedMetadataMkv(
        filePath,
        coverPath,
        metadata,
        settings: settings,
      );
    } else if (ext == '.mp4') {
      debugPrint("🔧 Attempting AtomicParsley (fast single-pass)...");
      success = await _embedMetadataMp4(
        filePath,
        coverPath,
        metadata,
        settings: settings,
      );
    }

    // Fall back to FFmpeg if specialized tool failed or unavailable
    if (!success) {
      debugPrint("⚠️  Falling back to FFmpeg (slower but reliable)...");
      await _embedMetadataFFmpeg(
        filePath,
        coverPath,
        metadata,
        settings: settings,
      );
    }

    debugPrint("=" * 60 + "\n");
  }

  /// Embed metadata using FFmpeg (fallback method - slower but universal)
  static Future<void> _embedMetadataFFmpeg(
    String filePath,
    String? coverPath,
    MatchResult metadata, {
    SettingsService? settings,
  }) async {
    String ext = p.extension(filePath).toLowerCase();
    bool hasCover = coverPath != null && File(coverPath).existsSync();

    // Check FFmpeg (with settings)
    if (!await _checkFFmpegAvailable(settings: settings)) {
      debugPrint("❌ FFmpeg not found - Configure in Settings or add to PATH");
      debugPrint("=" * 60 + "\n");
      return;
    }

    // Remove old covers for MP4 to prevent duplicates and Windows Explorer caching issues
    if (ext == '.mp4' && hasCover) {
      await _removeOldCoversFromMp4(filePath, _ffmpegPath);
    }

    // Build command
    String tempPath = "${filePath}.TEMP$ext";
    List<String> args = [
      '-y', // Overwrite
      '-loglevel',
      'error', // Only show errors
      '-i',
      filePath,
    ];

    // === COVER ART ===
    if (hasCover) {
      if (ext == '.mp4') {
        // MP4: Add cover as second input with explicit stream mapping
        args.addAll([
          '-i',
          coverPath,
          '-map', '0:v?', // Video from input 0
          '-map', '0:a?', // Audio from input 0
          '-map', '0:s?', // Subtitles from input 0
          '-map', '1:v', // Cover from input 1
          '-c:v', 'copy',
          '-c:a', 'copy',
          '-c:s', 'copy',
          '-disposition:v:0', '0',
          '-disposition:v:1', 'attached_pic',
        ]);
        debugPrint("✅ MP4 cover will be embedded as attached_pic");
      } else {
        // MKV: Attach cover - codec BEFORE attach!
        args.addAll([
          '-c',
          'copy',
          '-attach',
          coverPath,
          '-metadata:s:t',
          'mimetype=image/jpeg',
          '-metadata:s:t',
          'filename=cover.jpg',
        ]);
        debugPrint("✅ MKV cover will be attached");
      }
    } else {
      args.addAll([
        '-c',
        'copy',
        '-map',
        '0', // Always map input streams
      ]);
    }

    // === METADATA ===
    int metaCount = 0;

    void addMeta(String key, String? value) {
      if (value != null && value.isNotEmpty) {
        args.addAll(['-metadata', '$key=${_escapeMetadata(value)}']);
        metaCount++;
      }
    }

    // Basic Info — use the formatted container title for both the file title tag
    // and the video stream title so media players display it correctly.
    final containerTitle = _buildContainerTitle(metadata);
    addMeta('title', containerTitle);
    if (containerTitle.isNotEmpty) {
      args.addAll(['-metadata:s:v:0', 'title=${_escapeMetadata(containerTitle)}']);
      metaCount++;
    }
    if (metadata.year != null) {
      addMeta('year', metadata.year.toString());
      addMeta('date', metadata.year.toString());
    }

    // Extended Info
    addMeta('comment', metadata.description);
    addMeta('description', metadata.description);
    addMeta('synopsis', metadata.description);

    if (metadata.genres != null && metadata.genres!.isNotEmpty) {
      addMeta('genre', metadata.genres!.join(', '));
    }

    addMeta('director', metadata.director);
    addMeta('artist', metadata.director);

    if (metadata.actors != null && metadata.actors!.isNotEmpty) {
      addMeta('actor', metadata.actors!.join(', '));
    }

    if (metadata.rating != null) {
      addMeta('rating', metadata.rating.toString());
    }

    addMeta('content_rating', metadata.contentRating);

    // TV Show specifics
    if (metadata.season != null && metadata.episode != null) {
      addMeta('show', metadata.title);
      addMeta('season_number', metadata.season.toString());
      addMeta('episode_sort', metadata.episode.toString());
      addMeta('episode_id', metadata.episodeTitle);
    }

    args.add(tempPath);

    debugPrint("📊 Metadata fields: $metaCount");
    debugPrint("🔧 Command: ffmpeg ${args.take(10).join(' ')}...");

    // === EXECUTE ===
    try {
      // Use runInShell: false to avoid path quoting issues with spaces
      var result = await Process.run(
        _ffmpegPath ?? 'ffmpeg',
        args,
        runInShell: false,
      );

      if (result.exitCode == 0) {
        // Verify temp file
        if (!File(tempPath).existsSync()) {
          debugPrint("❌ Temp file not created!");
          debugPrint("=" * 60 + "\n");
          return;
        }

        var tempSize = File(tempPath).lengthSync();
        var origSize = File(filePath).lengthSync();

        if (tempSize == 0) {
          debugPrint("❌ Temp file is empty!");
          File(tempPath).deleteSync();
          debugPrint("=" * 60 + "\n");
          return;
        }

        debugPrint(
          "📦 Size: ${(origSize / 1048576).toStringAsFixed(1)} MB → ${(tempSize / 1048576).toStringAsFixed(1)} MB",
        );

        // Replace original
        try {
          File(filePath).deleteSync();
          File(tempPath).renameSync(filePath);
          debugPrint(
            "✅ SUCCESS! Embedded ${hasCover ? 'cover + ' : ''}$metaCount metadata fields",
          );
        } catch (e) {
          debugPrint("❌ Could not replace file: $e");
          if (File(tempPath).existsSync()) File(tempPath).deleteSync();
        }
      } else {
        debugPrint("❌ FFmpeg failed (exit ${result.exitCode})");
        if (result.stderr.toString().isNotEmpty) {
          debugPrint("Error: ${result.stderr}");
        }
        if (File(tempPath).existsSync()) File(tempPath).deleteSync();
      }
    } catch (e) {
      debugPrint("❌ Exception: $e");
      if (File(tempPath).existsSync()) {
        try {
          File(tempPath).deleteSync();
        } catch (_) {}
      }
    }
  }
}
