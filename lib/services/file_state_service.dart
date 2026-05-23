import 'dart:async';
import 'package:flutter/material.dart';
import '../backend/media_record.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../constants/app_constants.dart';
import '../utils/http_client.dart';
import 'package:cross_file/cross_file.dart';
import 'settings_service.dart';
import 'poster_cache_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class FileStateService with ChangeNotifier {
  final List<MediaRecord> _inputFiles = [];
  final List<MatchResult> _matchResults =
      []; // aligned with _inputFiles by index (null or empty if not matched)

  bool _isLoading = false;
  bool _isAddingFiles = false;
  bool _canUndo = false;
  int _applyProgress = 0;
  int _applyTotal = 0;
  List<String> _lastRenamedOldPaths = [];
  List<String> _lastRenamedNewNames = [];

  List<MediaRecord> get inputFiles => _inputFiles;
  List<MatchResult> get matchResults => _matchResults;
  bool get isLoading => _isLoading;
  bool get isAddingFiles => _isAddingFiles;
  bool get canUndo => _canUndo;
  int get applyProgress => _applyProgress;
  int get applyTotal => _applyTotal;

  /// Sanitize filename by removing/replacing invalid Windows characters.
  /// Colons become " - " (preserves readability for titles like "Show: Subtitle").
  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(':', ' - ')
        .replaceAll(FileConfig.invalidFilenameChars, '')
        .replaceAll(FileConfig.multipleSpaces, ' ')
        .trim();
  }

  /// Prepare a cover image for embedding by walking the priority chain:
  ///   1. In-memory `coverBytes` already on the [MatchResult] — written to
  ///      [tempCoverFile].
  ///   2. Locally cached, resized poster from [PosterCacheService]. Also
  ///      updates `cachedPosterPath` on the result.
  ///   3. Direct HTTP download of `posterUrl` into [tempCoverFile].
  ///   4. Local file referenced by `posterUrl` — copied into [tempCoverFile].
  ///
  /// Returns the path to a usable cover file, or `null` when no cover could
  /// be prepared (caller should still embed metadata without artwork).
  Future<String?> _prepareCoverPath(int index, File tempCoverFile) async {
    final match = _matchResults[index];

    if (match.coverBytes != null) {
      try {
        tempCoverFile.writeAsBytesSync(match.coverBytes!);
        if (tempCoverFile.existsSync()) return tempCoverFile.path;
      } catch (e) {
        debugPrint("⚠️  Failed to write cover from bytes: $e");
      }
    }

    final posterUrl = match.posterUrl;
    if (posterUrl == null || posterUrl.isEmpty) return null;

    final cachedPath = await PosterCacheService.downloadAndCachePoster(
      posterUrl: posterUrl,
      title: match.title ?? 'unknown',
      year: match.year,
      mediaType: match.season != null ? 'tv' : 'movie',
      season: match.season,
    );
    if (cachedPath != null) {
      _matchResults[index] = match.copyWith(cachedPosterPath: cachedPath);
      return cachedPath;
    }

    if (posterUrl.startsWith('http')) {
      await CoreBackend.downloadCover(posterUrl, tempCoverFile.path);
      if (tempCoverFile.existsSync() && tempCoverFile.lengthSync() > 1000) {
        return tempCoverFile.path;
      }
      return null;
    }

    if (File(posterUrl).existsSync()) {
      File(posterUrl).copySync(tempCoverFile.path);
      if (tempCoverFile.existsSync()) return tempCoverFile.path;
    }
    return null;
  }

  // Manual Override Support
  void updateManualMatch(int index, MatchResult result) {
    if (index >= 0 && index < _inputFiles.length) {
      // Ensure matchResults has enough slots
      while (_matchResults.length <= index) {
        _matchResults.add(MatchResult(newName: "")); // Placeholder
      }
      _matchResults[index] = result;
      notifyListeners();
    }
  }

  // Reset renamed status so user can re-apply metadata
  void resetRenamedStatus(int index) {
    if (index >= 0 && index < _inputFiles.length) {
      _inputFiles[index].renamedPath = null;
      notifyListeners();
    }
  }

  Future<void> matchFiles(SettingsService settings) async {
    if (_inputFiles.isEmpty) return;

    if (!settings.hasAnyMetadataKey) {
      debugPrint('⚠️ No API keys configured for batch matching');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Re-map inputFiles to ensure parsing is fresh if needed? No, MediaRecord is static once created.

      List<MatchResult> results = await CoreBackend.matchTitles(
        _inputFiles,
        seriesFormat: settings.seriesFormat,
        movieFormat: settings.movieFormat,
        tmdbApiKey: settings.tmdbApiKey,
        omdbApiKey: settings.omdbApiKey,
        anidbClientId: settings.anidbClientId,
        metadataSource: settings.metadataSource,
        useSeasonPoster: settings.useSeasonPoster,
        episodeDigits: settings.episodeDigits,
        seasonDigits: settings.seasonDigits,
      );

      _matchResults.clear();
      _matchResults.addAll(results);

      // Note: Statistics are incremented only on successful renames,
      // not on matches. See renameSingleFile in renamer_page.dart
    } catch (e) {
      debugPrint("Error matching: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Match a single file by index
  Future<void> matchSingleFile(
    int index,
    SettingsService settings, {
    String? overrideTitle,
    int? overrideSeason,
    int? overrideEpisode,
    String? overrideSource,
  }) async {
    if (index < 0 || index >= _inputFiles.length) return;

    if (!settings.hasAnyMetadataKey) {
      debugPrint('⚠️ No API keys configured for metadata search');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Get the original file
      final originalFile = _inputFiles[index];

      // Create a MediaRecord with overridden title/season/episode if provided
      final MediaRecord fileToMatch;
      if (overrideTitle != null || overrideSeason != null || overrideEpisode != null) {
        debugPrint(
            '🔄 Using overridden values for search: Title="${overrideTitle ?? originalFile.title}" S${overrideSeason ?? originalFile.season}E${overrideEpisode ?? originalFile.episode}');
        // Create a copy with overridden values
        fileToMatch = MediaRecord.withOverrides(
          originalFile.fullFilePath,
          title: overrideTitle,
          season: overrideSeason,
          episode: overrideEpisode,
        );
      } else {
        fileToMatch = originalFile;
      }

      // Match just this one file
      List<MatchResult> results = await CoreBackend.matchTitles(
        [fileToMatch], // Match with potentially overridden values
        seriesFormat: settings.seriesFormat,
        movieFormat: settings.movieFormat,
        tmdbApiKey: settings.tmdbApiKey,
        omdbApiKey: settings.omdbApiKey,
        anidbClientId: settings.anidbClientId,
        metadataSource: overrideSource ?? settings.metadataSource,
        useSeasonPoster: settings.useSeasonPoster,
        episodeDigits: settings.episodeDigits,
        seasonDigits: settings.seasonDigits,
      );

      if (results.isNotEmpty) {
        // Ensure matchResults has enough slots
        while (_matchResults.length <= index) {
          _matchResults.add(MatchResult(newName: ""));
        }

        MatchResult result = results.first;

        // Download cover immediately if posterUrl is available
        if (result.posterUrl != null &&
            result.posterUrl!.isNotEmpty &&
            result.posterUrl!.startsWith('http')) {
          debugPrint("📥 Downloading cover for: ${result.title}");
          final bytes = await ApiClient.getImageBytes(result.posterUrl!);
          if (bytes != null && bytes.isNotEmpty) {
            result = result.copyWith(coverBytes: bytes);
            debugPrint("✅ Cover downloaded (${bytes.length} bytes)");
          }
        }

        _matchResults[index] = result;

        // Note: Statistics are incremented only on successful renames,
        // not on matches. See renameSingleFile in renamer_page.dart
      }
    } catch (e) {
      debugPrint("Error matching single file: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> renameFiles({SettingsService? settings}) async {
    if (_inputFiles.length != _matchResults.length) return;

    _isLoading = true;
    _applyProgress = 0;
    _applyTotal = _inputFiles.length;
    notifyListeners();

    try {
      List<String> oldPaths = _inputFiles.map((m) => m.fullFilePath).toList();
      List<String> newNames =
          _matchResults.map((r) => _sanitizeFilename(r.newName)).toList();

      for (int i = 0; i < _matchResults.length; i++) {
        _matchResults[i].newName = newNames[i];
      }

      final doRename      = settings?.doRename      ?? true;
      final doCover       = settings?.doCover        ?? true;
      final doEmbedFields = settings?.doEmbedFields  ?? true;

      if (doRename) {
        CoreBackend.performFileRenaming(oldPaths, newNames);
      }

      final exePath = Platform.resolvedExecutable;
      final appDir = p.dirname(exePath);
      final cacheDir = Directory(p.join(appDir, 'UserData', 'Cache'));
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      // Process up to 3 files concurrently — each file runs an independent
      // external process (mkvpropedit / AtomicParsley) with a unique temp path.
      int nextIndex = 0;

      Future<void> worker() async {
        while (true) {
          final i = nextIndex++;
          if (i >= _inputFiles.length) break;

          final parentDir = p.dirname(oldPaths[i]);
          final newName = newNames[i];
          final newFullPath = doRename ? p.join(parentDir, newName) : oldPaths[i];

          if (!doCover && !doEmbedFields) {
            _inputFiles[i].renamedPath = newFullPath;
            _applyProgress++;
            notifyListeners();
            continue;
          }

          final fileName = p.basenameWithoutExtension(newName);
          final tempCoverFile =
              File(p.join(cacheDir.path, '${fileName}_cover.jpg'));
          String? coverPathForEmbedding;

          if (doCover) {
            coverPathForEmbedding = await _prepareCoverPath(i, tempCoverFile);
          }

          await CoreBackend.embedMetadata(
            newFullPath,
            coverPathForEmbedding,
            _matchResults[i],
            settings: settings,
            embedFields: doEmbedFields,
          );

          _inputFiles[i].renamedPath = newFullPath;

          if (coverPathForEmbedding == tempCoverFile.path &&
              tempCoverFile.existsSync()) {
            try {
              tempCoverFile.deleteSync();
            } catch (e) {
              debugPrint("⚠️  Failed to delete temp cover file: $e");
            }
          }

          _applyProgress++;
          notifyListeners();
        }
      }

      await Future.wait(List.generate(3, (_) => worker()));

      if (doRename) {
        _lastRenamedOldPaths = List.from(oldPaths);
        _lastRenamedNewNames = List.from(newNames);
        _canUndo = true;
      }
    } catch (e) {
      debugPrint("Error during rename: $e");
    } finally {
      _isLoading = false;
      _applyProgress = 0;
      _applyTotal = 0;
      notifyListeners();
    }
  }

  /// Rename a single file at the given index
  /// Returns true if successful, false otherwise
  Future<bool> renameSingleFile(int index, {SettingsService? settings}) async {
    if (index < 0 || index >= _inputFiles.length) {
      debugPrint("❌ Invalid index: $index");
      return false;
    }
    if (index >= _matchResults.length) {
      debugPrint("❌ No match result for index: $index");
      return false;
    }
    if (_inputFiles[index].isRenamed) {
      debugPrint("ℹ️ Already renamed");
      return true; // Already renamed is considered success
    }

    _isLoading = true;
    notifyListeners();

    try {
      String oldPath = _inputFiles[index].fullFilePath;
      String newName = _matchResults[index].newName;

      // Validate the new name
      if (newName.isEmpty) {
        debugPrint("❌ New name is empty");
        return false;
      }

      // Sanitize the filename - remove invalid Windows characters
      newName = _sanitizeFilename(newName);

      // Update the match result with sanitized name
      _matchResults[index].newName = newName;

      final doRename      = settings?.doRename      ?? true;
      final doCover       = settings?.doCover        ?? true;
      final doEmbedFields = settings?.doEmbedFields  ?? true;

      String parentDir = p.dirname(oldPath);
      String newFullPath = doRename ? p.join(parentDir, newName) : oldPath;

      if (!doRename) {
        debugPrint("📂 Rename disabled: embedding into $oldPath");
      } else {
        debugPrint("📂 Renaming: $oldPath");
        debugPrint("📂 To: $newFullPath");
      }

      // Verify the source file exists
      if (!File(oldPath).existsSync()) {
        debugPrint("❌ Source file does not exist: $oldPath");
        return false;
      }

      if (doRename) {
        CoreBackend.performFileRenaming([oldPath], [newName]);
      }

      // Create UserData/Cache folder for temporary cover files
      final exePath = Platform.resolvedExecutable;
      final appDir = p.dirname(exePath);
      final cacheDir = Directory(p.join(appDir, 'UserData', 'Cache'));

      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
        debugPrint("📁 Created cache directory: ${cacheDir.path}");
      }

      final fileName = p.basenameWithoutExtension(newName);
      File tempCoverFile = File(p.join(cacheDir.path, '${fileName}_cover.jpg'));
      String? coverPathForEmbedding;

      if (doCover) {
        coverPathForEmbedding = await _prepareCoverPath(index, tempCoverFile);
        if (coverPathForEmbedding != null) {
          debugPrint("✅ Cover prepared: $coverPathForEmbedding");
        }
      }

      if (doCover || doEmbedFields) {
        debugPrint("🎬 Embedding metadata for: $newName");
        await CoreBackend.embedMetadata(
          newFullPath,
          coverPathForEmbedding,
          _matchResults[index],
          settings: settings,
          embedFields: doEmbedFields,
        );
      }

      // Clean up temporary cover file (not cached files)
      if (coverPathForEmbedding == tempCoverFile.path && tempCoverFile.existsSync()) {
        try {
          tempCoverFile.deleteSync();
          debugPrint("🗑️  Cleaned up temp cover: ${tempCoverFile.path}");
        } catch (e) {
          debugPrint("⚠️  Failed to delete temp cover file: $e");
        }
      }

      // Mark as renamed
      _inputFiles[index].renamedPath = newFullPath;
      debugPrint("✅ Rename successful!");
      return true;
    } catch (e) {
      debugPrint("❌ Error renaming single file: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearRenamedFiles() {
    // Remove files backwards to maintain indices alignment
    for (int i = _inputFiles.length - 1; i >= 0; i--) {
      if (_inputFiles[i].isRenamed) {
        _inputFiles.removeAt(i);
        if (i < _matchResults.length) {
          _matchResults.removeAt(i);
        }
      }
    }
    notifyListeners();
  }

  void undo() {
    if (!_canUndo) return;
    try {
      List<String> currentFullPaths = [];
      List<String> originalFilenames = [];

      for (int i = 0; i < _lastRenamedOldPaths.length; i++) {
        String oldFullPath = _lastRenamedOldPaths[i];
        String newName = _lastRenamedNewNames[i];

        int lastSep = oldFullPath.lastIndexOf(RegExp(r'[/\\]'));
        String parent = oldFullPath.substring(0, lastSep);
        String sep = oldFullPath.contains('\\') ? '\\' : '/';
        String currentPath = "$parent$sep$newName";
        String originalName = oldFullPath.substring(lastSep + 1);

        currentFullPaths.add(currentPath);
        originalFilenames.add(originalName);
      }

      CoreBackend.performFileRenaming(currentFullPaths, originalFilenames);

      _canUndo = false;
      _inputFiles.clear();
      _matchResults.clear();
      notifyListeners();
    } catch (e) {
      debugPrint("Undo error: $e");
    }
  }

  /// Recursively lists video files inside a directory.
  List<String> _listVideoFiles(String dirPath) {
    try {
      return Directory(dirPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => FileConfig.isVideoFile(f.path))
          .map((f) => f.path)
          .toList()
        ..sort();
    } catch (e) {
      debugPrint("⚠️  Failed to scan directory '$dirPath': $e");
      return [];
    }
  }

  Future<void> addFiles(List<XFile> files, {SettingsService? settings}) async {
    _isAddingFiles = true;
    notifyListeners();

    // Expand any dropped directories to their contained video files
    final expanded = <XFile>[];
    for (final file in files) {
      if (FileSystemEntity.isDirectorySync(file.path)) {
        final found = _listVideoFiles(file.path);
        expanded.addAll(found.map((f) => XFile(f)));
        debugPrint(
            "📂 Expanded '${p.basename(file.path)}': ${found.length} video file(s)");
      } else {
        expanded.add(file);
      }
    }
    final effectiveFiles = expanded;

    int filesWithMetadata = 0;
    int filesAdded = 0;

    debugPrint("\n📁 Adding ${effectiveFiles.length} files...");

    try {
      for (var file in effectiveFiles) {
        // Avoid duplicates
        bool exists = _inputFiles.any((f) => f.fullFilePath == file.path);
        if (!exists) {
          _inputFiles.add(MediaRecord(file.path));
          filesAdded++;

          debugPrint("  Processing: ${p.basename(file.path)}");

          // Try to read existing metadata
          try {
            MatchResult? existingMetadata = await CoreBackend.readMetadata(
              file.path,
              settings: settings,
            );
            if (existingMetadata != null) {
              // Ensure matchResults has enough slots
              while (_matchResults.length < _inputFiles.length) {
                _matchResults.add(MatchResult(newName: ""));
              }
              // Update the last added file's metadata
              _matchResults[_inputFiles.length - 1] = existingMetadata;
              filesWithMetadata++;
              debugPrint("    ✓ Metadata found: ${existingMetadata.title}");
              debugPrint(
                  "    📷 PosterURL: ${existingMetadata.posterUrl ?? 'NONE'}");
            } else {
              // Add placeholder if no metadata
              while (_matchResults.length < _inputFiles.length) {
                _matchResults.add(MatchResult(newName: ""));
              }
              debugPrint("    ✗ No metadata found");
            }
          } catch (e) {
            debugPrint("    ❌ Error reading metadata: $e");
            // Add placeholder on error
            while (_matchResults.length < _inputFiles.length) {
              _matchResults.add(MatchResult(newName: ""));
            }
          }
        } else {
          debugPrint("  ⊘ Skipped (duplicate): ${p.basename(file.path)}");
        }
      }

      debugPrint(
          "📊 Summary: Added $filesAdded files, $filesWithMetadata with metadata\n");

      // Return info for snackbar (will be used by UI)
      _lastAddResult = {
        'added': filesAdded,
        'withMetadata': filesWithMetadata,
      };
    } finally {
      _isAddingFiles = false;
      notifyListeners();
    }
  }

  Map<String, int>? _lastAddResult;
  Map<String, int>? get lastAddResult => _lastAddResult;

  void clearLastAddResult() {
    _lastAddResult = null;
  }

  /// Extract covers in background for all files that don't have them yet
  Future<void> extractCoversInBackground({SettingsService? settings}) async {
    debugPrint("\n🖼️  Starting background cover extraction...");

    for (int i = 0; i < _inputFiles.length; i++) {
      // Skip if already has cover bytes or is renamed
      if (i < _matchResults.length) {
        final match = _matchResults[i];
        if (match.coverBytes != null || _inputFiles[i].isRenamed) {
          continue;
        }

        // Extract cover for this file
        try {
          final String filePath = _inputFiles[i].fullFilePath;
          debugPrint("  Extracting cover for: ${p.basename(filePath)}");

          final coverBytes =
              await CoreBackend.extractCover(filePath, settings: settings);

          if (coverBytes != null) {
            // Update match result with cover bytes using copyWith to preserve all fields
            _matchResults[i] = match.copyWith(coverBytes: coverBytes);

            // Notify UI to update this card
            notifyListeners();
            debugPrint("    ✅ Cover extracted");
          } else {
            debugPrint("    ⚠️  No cover found");
          }
        } catch (e) {
          debugPrint("    ❌ Error extracting cover: $e");
        }
      }
    }

    debugPrint("🖼️  Background cover extraction complete\n");
  }

  void setMatchResults(List<MatchResult> results) {
    _matchResults.clear();
    _matchResults.addAll(results);
    notifyListeners();
  }

  void clearAll() {
    _inputFiles.clear();
    _matchResults.clear();
    ApiClient.clearCache();
    notifyListeners();
  }

  void removeFileAt(int index) {
    if (index < _inputFiles.length) {
      _inputFiles.removeAt(index);
      if (index < _matchResults.length) {
        _matchResults.removeAt(index);
      }
      notifyListeners();
    }
  }

}
