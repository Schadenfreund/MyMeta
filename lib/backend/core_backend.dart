import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'media_record.dart';
import 'match_result.dart';
import '../services/tmdb_service.dart';
import '../services/omdb_service.dart';
import '../services/settings_service.dart';
import '../utils/cover_extractor.dart';
import 'package:http/http.dart' as http;

class CoreBackend {
  static String createFormattedTitle(
      String template, Map<String, dynamic> context) {
    // Basic substitution: {series_name}, {year}, {season_number}, {episode_number}, {episode_title}
    String result = template;
    context.forEach((key, value) {
      String replacement = value?.toString() ?? "{None}";
      result = result.replaceAll('{$key}', replacement);
    });
    return result;
  }

  static Future<List<MatchResult>> matchTitles(
    List<MediaRecord> records, {
    required String seriesFormat,
    required String movieFormat,
    String? tmdbApiKey,
    String? omdbApiKey,
    String metadataSource = 'tmdb',
  }) async {
    List<MatchResult> results = [];
    TmdbService? tmdb;
    OmdbService? omdb;

    if (metadataSource == 'tmdb' &&
        tmdbApiKey != null &&
        tmdbApiKey.isNotEmpty) {
      tmdb = TmdbService(tmdbApiKey);
    } else if (metadataSource == 'omdb' &&
        omdbApiKey != null &&
        omdbApiKey.isNotEmpty) {
      omdb = OmdbService(omdbApiKey);
    }

    for (var record in records) {
      if (record.type == 'episode') {
        String format = seriesFormat;
        String? episodeTitle = "Title";
        String? seriesName = record.title;
        int? year = record.year;
        String? posterUrl;

        if (tmdb != null && record.title != null) {
          // TMDB Logic
          try {
            var show = await tmdb.searchTV(record.title!);
            if (show != null) {
              seriesName = show['name'];
              String? date = show['first_air_date'];
              if (date != null && date.length >= 4) {
                year = int.tryParse(date.substring(0, 4));
              }
              if (show['poster_path'] != null) {
                posterUrl =
                    "https://image.tmdb.org/t/p/w500${show['poster_path']}";
              }

              // Fetch detailed metadata
              int? tvId = show['id'];
              Map<String, dynamic>? details;
              List<String>? genres;
              List<String>? actors;
              String? description;
              double? rating;
              String? contentRating;
              int? tmdbId;

              if (tvId != null) {
                details = await tmdb.getTVDetails(tvId);
                if (details != null) {
                  tmdbId = tvId;
                  genres = TmdbService.extractGenres(details);
                  actors = TmdbService.extractCast(details);
                  description = details['overview'];
                  rating = details['vote_average']?.toDouble();
                  contentRating =
                      TmdbService.extractContentRating(details, true);
                }
              }

              if (record.season != null && record.episode != null) {
                try {
                  var lookup =
                      await tmdb.getEpisodeLookup(show['id'], [record.season!]);
                  String key = "S${record.season}E${record.episode}";
                  if (lookup.containsKey(key)) {
                    episodeTitle = lookup[key];
                  }
                } catch (e) {
                  print("Episode lookup error TMDB: $e");
                }
              }

              // Fetch alternative posters for this TV show
              List<String>? alternativePosters;
              if (tvId != null) {
                try {
                  alternativePosters = await tmdb.getTVPosters(tvId);
                } catch (e) {
                  print("Error fetching alternative posters: $e");
                }
              }

              // Fetch all search results for re-matching
              List<MatchResult>? searchResults;
              try {
                var allResults = await tmdb.searchTVAll(record.title!);
                searchResults = [];
                for (var result in allResults) {
                  String? rSeriesName = result['name'];
                  int? rYear;
                  String? date = result['first_air_date'];
                  if (date != null && date.length >= 4) {
                    rYear = int.tryParse(date.substring(0, 4));
                  }
                  String? rPosterUrl;
                  if (result['poster_path'] != null) {
                    rPosterUrl =
                        "https://image.tmdb.org/t/p/w500${result['poster_path']}";
                  }
                  double? rRating = result['vote_average']?.toDouble();
                  int? rTmdbId = result['id'];

                  searchResults.add(MatchResult(
                    newName: rSeriesName ?? "Unknown",
                    posterUrl: rPosterUrl,
                    title: rSeriesName,
                    year: rYear,
                    type: 'episode',
                    rating: rRating,
                    tmdbId: rTmdbId,
                  ));
                }
              } catch (e) {
                print("Error fetching search results: $e");
              }

              var context = {
                "series_name": seriesName,
                "year": year,
                "season_number": record.season?.toString().padLeft(2, '0'),
                "episode_number": record.episode?.toString().padLeft(2, '0'),
                "episode_title": episodeTitle
              };

              results.add(MatchResult(
                  newName:
                      "${createFormattedTitle(format, context)}.${record.container}",
                  posterUrl: posterUrl,
                  title: seriesName,
                  year: year,
                  season: record.season,
                  episode: record.episode,
                  episodeTitle: episodeTitle,
                  type: 'episode',
                  description: description,
                  genres: genres,
                  actors: actors,
                  rating: rating,
                  contentRating: contentRating,
                  tmdbId: tmdbId,
                  alternativePosterUrls: alternativePosters,
                  searchResults: searchResults));
              continue; // Skip to next record
            }
          } catch (e) {
            print("TMDB Search Error: $e");
          }
        } else if (omdb != null && record.title != null) {
          // OMDb Logic
          try {
            var show = await omdb.searchSeries(record.title!);
            if (show != null) {
              seriesName = show['Title'];
              String? date = show['Year']; // Format might be "2005–"
              if (date != null && date.length >= 4) {
                // Simple extraction
                var yearMatch = RegExp(r'\d{4}').firstMatch(date);
                if (yearMatch != null) year = int.parse(yearMatch.group(0)!);
              }
              if (show['Poster'] != null && show['Poster'] != 'N/A') {
                posterUrl = show['Poster'];
              }

              // Fetch detailed metadata
              String? imdbId = show['imdbID'];
              Map<String, dynamic>? details;
              List<String>? genres;
              List<String>? actors;
              String? description;
              double? rating;
              String? contentRating;

              if (imdbId != null) {
                details = await omdb.getSeriesDetails(imdbId);
                if (details != null) {
                  genres = OmdbService.extractGenres(details);
                  actors = OmdbService.extractActors(details);
                  description = details['Plot'];
                  if (description == 'N/A') description = null;
                  rating = OmdbService.extractRating(details);
                  contentRating = OmdbService.extractContentRating(details);
                }
              }

              if (record.season != null && record.episode != null) {
                try {
                  var lookup = await omdb
                      .getEpisodeLookup(show['imdbID'], [record.season!]);
                  String key = "S${record.season}E${record.episode}";
                  if (lookup.containsKey(key)) {
                    episodeTitle = lookup[key];
                  }
                } catch (e) {
                  print("Episode lookup error OMDB: $e");
                }
              }

              // Fetch all search results for re-matching
              List<MatchResult>? searchResults;
              try {
                var allResults = await omdb.searchSeriesAll(record.title!);
                searchResults = [];
                for (var result in allResults) {
                  String? rSeriesName = result['Title'];
                  int? rYear;
                  String? date = result['Year'];
                  if (date != null && date.length >= 4) {
                    var yearMatch = RegExp(r'\d{4}').firstMatch(date);
                    if (yearMatch != null)
                      rYear = int.parse(yearMatch.group(0)!);
                  }
                  String? rPosterUrl;
                  if (result['Poster'] != null && result['Poster'] != 'N/A') {
                    rPosterUrl = result['Poster'];
                  }
                  double? rRating = OmdbService.extractRating(result);
                  String? rImdbId = result['imdbID'];

                  searchResults.add(MatchResult(
                    newName: rSeriesName ?? "Unknown",
                    posterUrl: rPosterUrl,
                    title: rSeriesName,
                    year: rYear,
                    type: 'episode',
                    rating: rRating,
                    imdbId: rImdbId,
                  ));
                }
              } catch (e) {
                print("Error fetching search results: $e");
              }

              var context = {
                "series_name": seriesName,
                "year": year,
                "season_number": record.season?.toString().padLeft(2, '0'),
                "episode_number": record.episode?.toString().padLeft(2, '0'),
                "episode_title": episodeTitle
              };

              results.add(MatchResult(
                  newName:
                      "${createFormattedTitle(format, context)}.${record.container}",
                  posterUrl: posterUrl,
                  title: seriesName,
                  year: year,
                  season: record.season,
                  episode: record.episode,
                  episodeTitle: episodeTitle,
                  type: 'episode',
                  description: description,
                  genres: genres,
                  actors: actors,
                  rating: rating,
                  contentRating: contentRating,
                  imdbId: imdbId,
                  searchResults: searchResults));
              continue; // Skip to next record
            }
          } catch (e) {
            print("OMDb Search Error: $e");
          }
        }

        var context = {
          "series_name": seriesName,
          "year": year,
          "season_number": record.season?.toString().padLeft(2, '0'),
          "episode_number": record.episode?.toString().padLeft(2, '0'),
          "episode_title": episodeTitle
        };

        results.add(MatchResult(
            newName:
                "${createFormattedTitle(format, context)}.${record.container}",
            posterUrl: posterUrl,
            title: seriesName,
            year: year,
            season: record.season,
            episode: record.episode,
            episodeTitle: episodeTitle,
            type: 'episode'));
      } else {
        String format = movieFormat;
        String? movieName = record.title;
        int? year = record.year;
        String? posterUrl;

        if (tmdb != null && record.title != null) {
          // TMDB Logic
          try {
            var movie = await tmdb.searchMovie(record.title!, record.year);
            if (movie != null) {
              movieName = movie['title'];
              String? date = movie['release_date'];
              if (date != null && date.length >= 4) {
                year = int.tryParse(date.substring(0, 4));
              }
              if (movie['poster_path'] != null) {
                posterUrl =
                    "https://image.tmdb.org/t/p/w500${movie['poster_path']}";
              }

              // Fetch detailed metadata
              int? movieId = movie['id'];
              Map<String, dynamic>? details;
              List<String>? genres;
              String? director;
              List<String>? actors;
              String? description;
              double? rating;
              String? contentRating;
              int? runtime;
              int? tmdbId;

              if (movieId != null) {
                details = await tmdb.getMovieDetails(movieId);
                if (details != null) {
                  tmdbId = movieId;
                  genres = TmdbService.extractGenres(details);
                  director = TmdbService.extractDirector(details);
                  actors = TmdbService.extractCast(details);
                  description = details['overview'];
                  rating = details['vote_average']?.toDouble();
                  contentRating =
                      TmdbService.extractContentRating(details, false);
                  runtime = details['runtime'];
                }
              }

              // Fetch alternative posters for this movie
              List<String>? alternativePosters;
              if (movieId != null) {
                try {
                  alternativePosters = await tmdb.getMoviePosters(movieId);
                } catch (e) {
                  print("Error fetching alternative posters: $e");
                }
              }

              // Fetch all search results for re-matching
              List<MatchResult>? searchResults;
              try {
                var allResults =
                    await tmdb.searchMovieAll(record.title!, record.year);
                searchResults = [];
                for (var result in allResults) {
                  String? rMovieName = result['title'];
                  int? rYear;
                  String? date = result['release_date'];
                  if (date != null && date.length >= 4) {
                    rYear = int.tryParse(date.substring(0, 4));
                  }
                  String? rPosterUrl;
                  if (result['poster_path'] != null) {
                    rPosterUrl =
                        "https://image.tmdb.org/t/p/w500${result['poster_path']}";
                  }
                  double? rRating = result['vote_average']?.toDouble();
                  int? rTmdbId = result['id'];

                  searchResults.add(MatchResult(
                    newName: rMovieName ?? "Unknown",
                    posterUrl: rPosterUrl,
                    title: rMovieName,
                    year: rYear,
                    type: 'movie',
                    rating: rRating,
                    tmdbId: rTmdbId,
                  ));
                }
              } catch (e) {
                print("Error fetching search results: $e");
              }

              var context = {"movie_name": movieName, "year": year};
              results.add(MatchResult(
                  newName:
                      "${createFormattedTitle(format, context)}.${record.container}",
                  posterUrl: posterUrl,
                  title: movieName,
                  year: year,
                  type: 'movie',
                  description: description,
                  genres: genres,
                  director: director,
                  actors: actors,
                  rating: rating,
                  contentRating: contentRating,
                  runtime: runtime,
                  tmdbId: tmdbId,
                  alternativePosterUrls: alternativePosters,
                  searchResults: searchResults));
              continue; // Skip to next record
            }
          } catch (e) {
            print("TMDB Movie Search Error: $e");
          }
        } else if (omdb != null && record.title != null) {
          // OMDb Logic
          try {
            var movie = await omdb.searchMovie(record.title!, record.year);
            if (movie != null) {
              movieName = movie['Title'];
              String? date = movie['Year'];
              if (date != null && date.length >= 4) {
                var yearMatch = RegExp(r'\d{4}').firstMatch(date);
                if (yearMatch != null) year = int.parse(yearMatch.group(0)!);
              }
              if (movie['Poster'] != null && movie['Poster'] != 'N/A') {
                posterUrl = movie['Poster'];
              }

              // Fetch detailed metadata
              String? imdbId = movie['imdbID'];
              Map<String, dynamic>? details;
              List<String>? genres;
              String? director;
              List<String>? actors;
              String? description;
              double? rating;
              String? contentRating;
              int? runtime;

              if (imdbId != null) {
                details = await omdb.getMovieDetails(imdbId);
                if (details != null) {
                  genres = OmdbService.extractGenres(details);
                  director = OmdbService.extractDirector(details);
                  actors = OmdbService.extractActors(details);
                  description = details['Plot'];
                  if (description == 'N/A') description = null;
                  rating = OmdbService.extractRating(details);
                  contentRating = OmdbService.extractContentRating(details);
                  runtime = OmdbService.extractRuntime(details);
                }
              }

              // Fetch all search results for re-matching
              List<MatchResult>? searchResults;
              try {
                var allResults =
                    await omdb.searchMovieAll(record.title!, record.year);
                searchResults = [];
                for (var result in allResults) {
                  String? rMovieName = result['Title'];
                  int? rYear;
                  String? date = result['Year'];
                  if (date != null && date.length >= 4) {
                    var yearMatch = RegExp(r'\d{4}').firstMatch(date);
                    if (yearMatch != null)
                      rYear = int.parse(yearMatch.group(0)!);
                  }
                  String? rPosterUrl;
                  if (result['Poster'] != null && result['Poster'] != 'N/A') {
                    rPosterUrl = result['Poster'];
                  }
                  double? rRating = OmdbService.extractRating(result);
                  String? rImdbId = result['imdbID'];

                  searchResults.add(MatchResult(
                    newName: rMovieName ?? "Unknown",
                    posterUrl: rPosterUrl,
                    title: rMovieName,
                    year: rYear,
                    type: 'movie',
                    rating: rRating,
                    imdbId: rImdbId,
                  ));
                }
              } catch (e) {
                print("Error fetching search results: $e");
              }

              var context = {"movie_name": movieName, "year": year};
              results.add(MatchResult(
                  newName:
                      "${createFormattedTitle(format, context)}.${record.container}",
                  posterUrl: posterUrl,
                  title: movieName,
                  year: year,
                  type: 'movie',
                  description: description,
                  genres: genres,
                  director: director,
                  actors: actors,
                  rating: rating,
                  contentRating: contentRating,
                  runtime: runtime,
                  imdbId: imdbId,
                  searchResults: searchResults));
              continue; // Skip to next record
            }
          } catch (e) {
            print("OMDb Movie Search Error: $e");
          }
        }

        var context = {"movie_name": movieName, "year": year};
        results.add(MatchResult(
            newName:
                "${createFormattedTitle(format, context)}.${record.container}",
            posterUrl: posterUrl,
            title: movieName,
            year: year,
            type: 'movie'));
      }
    }

    return results;
  }

  static void performFileRenaming(
      List<String> oldPaths, List<String> newNames) {
    if (oldPaths.length != newNames.length) {
      throw Exception("Count mismatch");
    }

    for (int i = 0; i < oldPaths.length; i++) {
      String oldPath = oldPaths[i];
      String newName = newNames[i];
      String parent = p.dirname(oldPath);
      String newPath = p.join(parent, newName);

      File(oldPath).renameSync(newPath);
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
            print('✅ Using custom FFmpeg: $binPath');
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
            print('✅ Using custom FFmpeg: $directPath');
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
          print('✅ Using bundled FFmpeg: $bundledFfmpeg');
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
        print('✅ Using FFmpeg from PATH');
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

      final userDataTool =
          p.join(exeDir, 'UserData', 'tools', userDataSubDir, '$toolName.exe');
      if (File(userDataTool).existsSync()) {
        print('✅ Using UserData $toolName: $userDataTool');
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
        print('✅ Using custom $toolName: $binPath');
        return binPath;
      }

      // Try direct path in folder
      final directPath = p.join(customPath, '$toolName.exe');
      if (File(directPath).existsSync()) {
        print('✅ Using custom $toolName: $directPath');
        return directPath;
      }
    }

    // 2. Try bundled tool in app directory (deprecated - will be removed)
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final bundledTool = p.join(exeDir, '$toolName.exe');

      if (File(bundledTool).existsSync()) {
        print('✅ Using bundled $toolName: $bundledTool');
        return bundledTool;
      }
    } catch (e) {
      // Tool not found
    }

    // Tool not found - return null to trigger FFmpeg fallback
    return null;
  }

  /// Resolve mkvpropedit path (custom → bundled → PATH)
  static Future<String?> _resolveMkvpropedit(
      {SettingsService? settings}) async {
    return _resolveToolPath('mkvpropedit', settings?.mkvpropeditPath);
  }

  /// Resolve AtomicParsley path (custom → bundled → PATH)
  static Future<String?> _resolveAtomicParsley(
      {SettingsService? settings}) async {
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
  static Future<MatchResult?> readMetadata(String filePath,
      {SettingsService? settings}) async {
    print("\n" + "=" * 60);
    print("📖 READING METADATA: ${p.basename(filePath)}");
    print("=" * 60);

    // Validate input file
    if (!File(filePath).existsSync()) {
      print("❌ File doesn't exist: $filePath");
      print("=" * 60 + "\n");
      return null;
    }

    String ext = p.extension(filePath).toLowerCase();
    if (ext != '.mp4' && ext != '.mkv') {
      print("⚠️  Unsupported format (only .mp4 and .mkv supported)");
      print("=" * 60 + "\n");
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
        print('✅ Using custom FFprobe: $ffprobePath');
      } else {
        // Try without bin/ subdirectory (in case user pointed directly to bin folder)
        final directPath = p.join(settings.ffmpegPath, 'ffprobe.exe');
        if (File(directPath).existsSync()) {
          ffprobePath = directPath;
          print('✅ Using custom FFprobe: $ffprobePath');
        } else {
          print('⚠️  FFprobe not found in: ${settings.ffmpegPath}');
          print('    Expected: $binPath or $directPath');
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
          print('✅ Using bundled FFprobe: $bundledFfprobe');
        }
      } catch (e) {
        print('⚠️  Could not locate bundled FFprobe: $e');
      }
    }

    // 3. If still not found, just try "ffprobe" (assume it's in PATH)
    if (ffprobePath == null) {
      ffprobePath = 'ffprobe';
      print(
          '⚠️  FFprobe not found in custom/bundled paths, trying system PATH...');
    }

    // Run FFprobe to get metadata
    try {
      var result = await Process.run(
        ffprobePath!, // Already checked for null above
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          filePath,
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        print("❌ FFprobe failed (exit ${result.exitCode})");
        print("=" * 60 + "\n");
        return null;
      }

      // Parse JSON output
      final jsonData = json.decode(result.stdout);
      final format = jsonData['format'];

      if (format == null || format['tags'] == null) {
        print("ℹ️  No metadata tags found");
        print("=" * 60 + "\n");
        return null;
      }

      final tags = format['tags'];

      // DEBUG: Print ALL tags found
      print("🔍 ALL TAGS FOUND:");
      tags.forEach((key, value) {
        print("   $key: $value");
      });
      print("");

      // Extract metadata - check multiple variations
      String? title = tags['title'] ?? tags['TITLE'];
      String? yearStr =
          tags['year'] ?? tags['date'] ?? tags['YEAR'] ?? tags['DATE'];
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

      String? contentRating = tags['content_rating'] ?? tags['CONTENT_RATING'];

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

      // Determine type
      String type = (season != null && episode != null) ? 'episode' : 'movie';

      print("📊 Found metadata:");
      print("   Title: ${title ?? 'N/A'}");
      print("   Year: ${year ?? 'N/A'}");
      print("   Type: $type");
      if (type == 'episode') {
        print("   Show: ${show ?? 'N/A'}");
        print("   Season: ${season ?? 'N/A'}");
        print("   Episode: ${episode ?? 'N/A'}");
        print("   Episode Title: ${episodeTitle ?? 'N/A'}");
      }
      print("=" * 60 + "\n");

      // Generate newName using user format settings (if provided)
      String newName;
      final ext = p.extension(filePath);

      if (type == 'episode' && season != null && episode != null) {
        // TV Show format - use user's series format template
        final String formatTemplate = settings?.seriesFormat ??
            "{series_name} - S{season_number}E{episode_number} - {episode_title}";

        Map<String, dynamic> context = {
          'series_name': title ?? show ?? 'Unknown Show',
          'season_number': season.toString().padLeft(2, '0'),
          'episode_number': episode.toString().padLeft(2, '0'),
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

      print("📝 Generated newName: $newName");
      print("=" * 60 + "\n");

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
      print("❌ Error reading metadata: $e");
      print("=" * 60 + "\n");
      return null;
    }
  }

  /// Download cover art from URL
  static Future<void> downloadCover(String url, String savePath) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        File(savePath).writeAsBytesSync(response.bodyBytes);
        print('✅ Cover downloaded: $savePath');
      } else {
        print('❌ Failed to download cover: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error downloading cover: $e');
    }
  }

  /// Extract cover bytes from media file (wrapper around CoverExtractor)
  static Future<Uint8List?> extractCover(String filePath,
      {SettingsService? settings}) async {
    return await CoverExtractor.extractCoverBytes(filePath, settings: settings);
  }

  /// Extract embedded cover art from media file and save to disk
  static Future<String?> extractCoverArt(String filePath,
      {SettingsService? settings}) async {
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
          .where((f) =>
              f.path.toLowerCase().endsWith('.jpg') ||
              f.path.toLowerCase().endsWith('.png') ||
              f.path.toLowerCase().endsWith('.jpeg'))
          .toList();

      if (extractedFiles.isNotEmpty) {
        // Rename first extracted image to our standard name
        final extractedFile = File(extractedFiles.first.path);
        extractedFile.renameSync(coverPath);
        if (File(coverPath).existsSync() &&
            File(coverPath).lengthSync() > 5000) {
          print('✅ Extracted cover via attachment: $coverPath');
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
        runInShell: true,
      );

      if (result.exitCode == 0 && File(coverPath).existsSync()) {
        final fileSize = File(coverPath).lengthSync();
        if (fileSize > 5000) {
          // At least 5KB to ensure it's a real image
          print('✅ Extracted cover via video frame: $coverPath');
          return coverPath;
        } else {
          print(
              '⚠️  Extracted file too small ($fileSize bytes), probably empty');
        }
      }
    } catch (e) {
      print('❌ Error extracting cover: $e');
    }

    return null;
  }

  /// Embed metadata into MKV file using mkvpropedit with XML tags (fast in-place)
  static Future<bool> _embedMetadataMkv(
      String filePath, String? coverPath, MatchResult metadata,
      {SettingsService? settings}) async {
    String? toolPath = await _resolveMkvpropedit(settings: settings);
    if (toolPath == null) {
      print('mkvpropedit not available');
      return false;
    }
    if (!File(filePath).existsSync()) {
      print('MKV file not found');
      return false;
    }

    try {
      bool hasAttachment = false;
      bool hasTags = false;

      // Step 1: Attach cover
      if (coverPath != null && File(coverPath).existsSync()) {
        var result = await Process.run(
            toolPath,
            [
              filePath,
              '--attachment-name',
              'cover.jpg',
              '--attachment-mime-type',
              'image/jpeg',
              '--add-attachment',
              coverPath
            ],
            runInShell: false);
        if (result.exitCode == 0) {
          print('Cover attached');
          hasAttachment = true;
        } else {
          print('Cover failed: ${result.stderr}');
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
              '<Simple><Name>$name</Name><String>$escaped</String></Simple>');
          tagCount++;
        }
      }

      // DEBUG: Show what values we're writing
      print('📝 VALUES BEING WRITTEN:');
      print('   Title: "${metadata.title}"');
      print('   Year: ${metadata.year}');
      print(
          '   Description: "${metadata.description?.substring(0, (metadata.description?.length ?? 0) > 50 ? 50 : metadata.description?.length ?? 0)}..."');

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
            cacheDir, 'tags_${DateTime.now().millisecondsSinceEpoch}.xml');
        await File(xmlPath).writeAsString(xml.toString());
        print('Writing $tagCount tags (in-place)...');
        var result = await Process.run(
            toolPath, [filePath, '--tags', 'all:$xmlPath'],
            runInShell: false);
        try {
          await File(xmlPath).delete();
        } catch (e) {}
        if (result.exitCode == 0) {
          print('$tagCount tags written');
          hasTags = true;
        } else {
          print('Tags failed: ${result.stderr}');
        }
      }

      if (hasAttachment || hasTags) {
        print('MKV complete (fast in-place)');
        return true;
      }
      return true;
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  /// Embed metadata into MP4 file using AtomicParsley (fast single-pass editing)
  static Future<bool> _embedMetadataMp4(
      String filePath, String? coverPath, MatchResult metadata,
      {SettingsService? settings}) async {
    String? toolPath = await _resolveAtomicParsley(settings: settings);
    if (toolPath == null) {
      print('⚠️  AtomicParsley not available');
      return false;
    }

    List<String> args = [filePath];

    // Map metadata fields to AtomicParsley arguments
    if (metadata.title != null && metadata.title!.isNotEmpty) {
      args.addAll(['--title', metadata.title!]);
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
    print('🔧 ATOMICPARSLEY COMMAND:');
    print('   Tool: $toolPath');
    print('   File: $filePath');
    print('   Args: ${args.join(' | ')}');
    print('   Full: "$toolPath" ${args.map((a) => '"$a"').join(' ')}');

    // Check file before
    File targetFile = File(filePath);
    DateTime beforeTime = targetFile.lastModifiedSync();
    int beforeSize = targetFile.lengthSync();
    print(
        '📊 BEFORE: Modified=${beforeTime.toIso8601String()}, Size=$beforeSize');

    try {
      // Use runInShell: false to avoid path quoting issues with spaces
      var result = await Process.run(toolPath, args, runInShell: false);

      print('📤 Exit Code: ${result.exitCode}');

      // ALWAYS log stdout and stderr
      String stdout = result.stdout.toString().trim();
      String stderr = result.stderr.toString().trim();

      if (stdout.isNotEmpty) {
        print('📄 STDOUT:');
        print(stdout);
      }

      if (stderr.isNotEmpty) {
        print('⚠️  STDERR:');
        print(stderr);
      }

      // Wait for file system to sync
      await Future.delayed(Duration(milliseconds: 500));

      // Check file after
      if (targetFile.existsSync()) {
        DateTime afterTime = targetFile.lastModifiedSync();
        int afterSize = targetFile.lengthSync();
        print(
            '📊 AFTER: Modified=${afterTime.toIso8601String()}, Size=$afterSize');

        bool timeChanged = afterTime.isAfter(beforeTime);
        bool sizeChanged = afterSize != beforeSize;

        print('   Time changed: $timeChanged');
        print('   Size changed: $sizeChanged');

        if (!timeChanged && !sizeChanged) {
          print('❌ FILE NOT MODIFIED - AtomicParsley did NOT write metadata!');
          print('   This means the command failed silently');
          return false;
        }
      }

      if (result.exitCode == 0) {
        print('✅ MP4 metadata embedded with AtomicParsley');
        return true;
      } else {
        print('❌ AtomicParsley failed (exit ${result.exitCode})');
        return false;
      }
    } catch (e) {
      print('❌ Error running AtomicParsley: $e');
      return false;
    }
  }

  /// Main metadata embedding dispatcher - tries format-specific tools first, falls back to FFmpeg
  static Future<void> embedMetadata(
      String filePath, String? coverPath, MatchResult metadata,
      {SettingsService? settings}) async {
    print("\n" + "=" * 60);
    print("🎬 EMBEDDING: ${p.basename(filePath)}");
    print("=" * 60);

    // Validate input file
    if (!File(filePath).existsSync()) {
      print("❌ Input file doesn't exist: $filePath");
      print("=" * 60 + "\n");
      return;
    }

    String ext = p.extension(filePath).toLowerCase();
    bool hasCover = coverPath != null && File(coverPath).existsSync();

    print("📁 Extension: $ext");
    print("🖼️  Cover: ${hasCover ? '✅ ' + coverPath : '❌ None'}");

    // Check supported formats
    if (ext != '.mp4' && ext != '.mkv') {
      print("⚠️  Unsupported format (only .mp4 and .mkv supported)");
      print("=" * 60 + "\n");
      return;
    }

    bool success = false;

    // Try format-specific tool first for maximum speed
    if (ext == '.mkv') {
      print("🔧 Using mkvpropedit with XML tags (fast in-place)...");
      success = await _embedMetadataMkv(filePath, coverPath, metadata,
          settings: settings);
    } else if (ext == '.mp4') {
      print("🔧 Attempting AtomicParsley (fast single-pass)...");
      success = await _embedMetadataMp4(filePath, coverPath, metadata,
          settings: settings);
    }

    // Fall back to FFmpeg if specialized tool failed or unavailable
    if (!success) {
      print("⚠️  Falling back to FFmpeg (slower but reliable)...");
      await _embedMetadataFFmpeg(filePath, coverPath, metadata,
          settings: settings);
    }

    print("=" * 60 + "\n");
  }

  /// Embed metadata using FFmpeg (fallback method - slower but universal)
  static Future<void> _embedMetadataFFmpeg(
      String filePath, String? coverPath, MatchResult metadata,
      {SettingsService? settings}) async {
    String ext = p.extension(filePath).toLowerCase();
    bool hasCover = coverPath != null && File(coverPath).existsSync();

    // Check FFmpeg (with settings)
    if (!await _checkFFmpegAvailable(settings: settings)) {
      print("❌ FFmpeg not found - Configure in Settings or add to PATH");
      print("=" * 60 + "\n");
      return;
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
        print("✅ MP4 cover will be embedded as attached_pic");
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
        print("✅ MKV cover will be attached");
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

    // Basic Info
    addMeta('title', metadata.title);
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

    print("📊 Metadata fields: $metaCount");
    print("🔧 Command: ffmpeg ${args.take(10).join(' ')}...");

    // === EXECUTE ===
    try {
      // Use runInShell: false to avoid path quoting issues with spaces
      var result =
          await Process.run(_ffmpegPath ?? 'ffmpeg', args, runInShell: false);

      if (result.exitCode == 0) {
        // Verify temp file
        if (!File(tempPath).existsSync()) {
          print("❌ Temp file not created!");
          print("=" * 60 + "\n");
          return;
        }

        var tempSize = File(tempPath).lengthSync();
        var origSize = File(filePath).lengthSync();

        if (tempSize == 0) {
          print("❌ Temp file is empty!");
          File(tempPath).deleteSync();
          print("=" * 60 + "\n");
          return;
        }

        print(
            "📦 Size: ${(origSize / 1048576).toStringAsFixed(1)} MB → ${(tempSize / 1048576).toStringAsFixed(1)} MB");

        // Replace original
        try {
          File(filePath).deleteSync();
          File(tempPath).renameSync(filePath);
          print(
              "✅ SUCCESS! Embedded ${hasCover ? 'cover + ' : ''}$metaCount metadata fields");
        } catch (e) {
          print("❌ Could not replace file: $e");
          if (File(tempPath).existsSync()) File(tempPath).deleteSync();
        }
      } else {
        print("❌ FFmpeg failed (exit ${result.exitCode})");
        if (result.stderr.toString().isNotEmpty) {
          print("Error: ${result.stderr}");
        }
        if (File(tempPath).existsSync()) File(tempPath).deleteSync();
      }
    } catch (e) {
      print("❌ Exception: $e");
      if (File(tempPath).existsSync()) {
        try {
          File(tempPath).deleteSync();
        } catch (_) {}
      }
    }
  }
}
