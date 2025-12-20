import 'dart:io';
import 'package:path/path.dart' as p;
import 'media_record.dart';
import 'match_result.dart';
import '../services/tmdb_service.dart';
import '../services/omdb_service.dart';
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
                  tmdbId: tmdbId));
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
                  imdbId: imdbId));
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
                  tmdbId: tmdbId));
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
                  imdbId: imdbId));
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
  static Future<bool> _checkFFmpegAvailable() async {
    if (_ffmpegAvailable != null) return _ffmpegAvailable!;

    // First, try bundled ffmpeg.exe in app directory
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

    // Fall back to FFmpeg in PATH
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

  static Future<void> embedMetadata(
      String filePath, String? coverPath, MatchResult metadata) async {
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

    // Check FFmpeg (with caching)
    if (!await _checkFFmpegAvailable()) {
      print("❌ FFmpeg not found - Install FFmpeg and add to PATH");
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
      var result =
          await Process.run(_ffmpegPath ?? 'ffmpeg', args, runInShell: true);

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

    print("=" * 60 + "\n");
  }
}
