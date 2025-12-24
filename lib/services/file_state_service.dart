import 'package:flutter/material.dart';
import '../backend/media_record.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import 'package:cross_file/cross_file.dart';
import 'settings_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class FileStateService with ChangeNotifier {
  final List<MediaRecord> _inputFiles = [];
  final List<MatchResult> _matchResults =
      []; // aligned with _inputFiles by index (null or empty if not matched)

  bool _isLoading = false;
  bool _isAddingFiles = false;
  bool _canUndo = false;
  List<String> _lastRenamedOldPaths = [];
  List<String> _lastRenamedNewNames = [];

  List<MediaRecord> get inputFiles => _inputFiles;
  List<MatchResult> get matchResults => _matchResults;
  bool get isLoading => _isLoading;
  bool get isAddingFiles => _isAddingFiles;
  bool get canUndo => _canUndo;

  /// Sanitize filename by removing invalid Windows characters
  String _sanitizeFilename(String filename) {
    // Characters not allowed in Windows filenames: \ / : * ? " < > |
    return filename
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
        .trim();
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

    // Validation: Check if at least one API is configured
    bool hasAnyApi = settings.tmdbApiKey.isNotEmpty ||
        settings.omdbApiKey.isNotEmpty ||
        settings.anidbClientId.isNotEmpty;

    if (!hasAnyApi) {
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
    int? overrideSeason,
    int? overrideEpisode,
  }) async {
    if (index < 0 || index >= _inputFiles.length) return;

    // Validation: Check if at least one API is configured
    bool hasAnyApi = settings.tmdbApiKey.isNotEmpty ||
        settings.omdbApiKey.isNotEmpty ||
        settings.anidbClientId.isNotEmpty;

    if (!hasAnyApi) {
      debugPrint('⚠️ No API keys configured for metadata search');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Get the original file
      final originalFile = _inputFiles[index];

      // Create a MediaRecord with overridden season/episode if provided
      final MediaRecord fileToMatch;
      if (overrideSeason != null || overrideEpisode != null) {
        debugPrint(
            '🔄 Using overridden season/episode for search: S${overrideSeason ?? originalFile.season}E${overrideEpisode ?? originalFile.episode}');
        // Create a copy with overridden values
        fileToMatch = MediaRecord.withOverrides(
          originalFile.fullFilePath,
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
        metadataSource: settings.metadataSource,
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
          try {
            debugPrint("📥 Downloading cover for: ${result.title}");
            final response = await http.get(Uri.parse(result.posterUrl!));
            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              // Use copyWith to preserve all fields while adding cover bytes
              result = result.copyWith(coverBytes: response.bodyBytes);
              debugPrint(
                  "✅ Cover downloaded (${response.bodyBytes.length} bytes)");
            }
          } catch (e) {
            debugPrint("⚠️  Failed to download cover: $e");
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
    notifyListeners();

    try {
      List<String> oldPaths = _inputFiles.map((m) => m.fullFilePath).toList();
      // Sanitize all filenames
      List<String> newNames =
          _matchResults.map((r) => _sanitizeFilename(r.newName)).toList();

      // Update match results with sanitized names
      for (int i = 0; i < _matchResults.length; i++) {
        _matchResults[i].newName = newNames[i];
      }

      // Perform Rename
      CoreBackend.performFileRenaming(oldPaths, newNames);

      // Create UserData/Cache folder for temporary cover files
      final exePath = Platform.resolvedExecutable;
      final appDir = p.dirname(exePath);
      final cacheDir = Directory(p.join(appDir, 'UserData', 'Cache'));

      // Create cache directory if it doesn't exist
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
        debugPrint("📁 Created cache directory: ${cacheDir.path}");
      }

      // Download or Copy Posters and Embed
      // Track which cover files we've created so we can clean them up later
      Set<String> coverFilesCreated = {};

      for (int i = 0; i < _inputFiles.length; i++) {
        String parentDir = p.dirname(oldPaths[i]);
        String newName = newNames[i];
        String newFullPath = p.join(parentDir, newName);

        // Use filename as unique identifier for the cover (avoid conflicts)
        final fileName = p.basenameWithoutExtension(newName);
        File coverFile = File(p.join(cacheDir.path, '${fileName}_cover.jpg'));

        // Priority 1: Use coverBytes if available
        if (_matchResults[i].coverBytes != null) {
          try {
            coverFile.writeAsBytesSync(_matchResults[i].coverBytes!);
            if (coverFile.existsSync()) {
              coverFilesCreated.add(coverFile.path);
              debugPrint("✅ Cover written from bytes: ${coverFile.path}");
            }
          } catch (e) {
            debugPrint("⚠️  Failed to write cover from bytes: $e");
          }
        }
        // Priority 2: Download/copy from posterUrl
        else {
          String? posterUrl = _matchResults[i].posterUrl;
          if (posterUrl != null && posterUrl.isNotEmpty) {
            // If cover URL provided, download/copy it
            if (posterUrl.startsWith('http')) {
              // Download
              await CoreBackend.downloadCover(posterUrl, coverFile.path);
              if (coverFile.existsSync()) {
                coverFilesCreated.add(coverFile.path);
              }
            } else if (File(posterUrl).existsSync()) {
              // Copy local file
              File(posterUrl).copySync(coverFile.path);
              if (coverFile.existsSync()) {
                coverFilesCreated.add(coverFile.path);
              }
            } else {
              debugPrint("⚠️  Poster URL not accessible: $posterUrl");
            }
          }
        }

        // Embed Metadata (cover file is now guaranteed to exist if it should)
        debugPrint("🎬 Embedding metadata for: $newName");
        await CoreBackend.embedMetadata(
          newFullPath,
          coverFile.existsSync() ? coverFile.path : null,
          _matchResults[i],
          settings: settings, // Pass settings
        );

        // Mark as renamed
        _inputFiles[i].renamedPath = newFullPath;
      }

      // NOW clean up all cover files we created
      for (String coverPath in coverFilesCreated) {
        try {
          File(coverPath).deleteSync();
          debugPrint("🗑️  Cleaned up cover: $coverPath");
        } catch (e) {
          debugPrint("⚠️  Failed to delete cover file: $e");
        }
      }

      // Save Undo State
      _lastRenamedOldPaths = List.from(oldPaths);
      _lastRenamedNewNames = List.from(newNames);
      _canUndo = true;

      // Do not clear list automatically. User must acknowledge.
    } catch (e) {
      debugPrint("Error during rename: $e");
    } finally {
      _isLoading = false;
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

      String parentDir = p.dirname(oldPath);
      String newFullPath = p.join(parentDir, newName);

      debugPrint("📂 Renaming: $oldPath");
      debugPrint("📂 To: $newFullPath");

      // Verify the source file exists
      if (!File(oldPath).existsSync()) {
        debugPrint("❌ Source file does not exist: $oldPath");
        return false;
      }

      // Perform Rename
      CoreBackend.performFileRenaming([oldPath], [newName]);

      // Create UserData/Cache folder for temporary cover files
      final exePath = Platform.resolvedExecutable;
      final appDir = p.dirname(exePath);
      final cacheDir = Directory(p.join(appDir, 'UserData', 'Cache'));

      // Create cache directory if it doesn't exist
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
        debugPrint("📁 Created cache directory: ${cacheDir.path}");
      }

      // Use filename as unique identifier for the cover (avoid conflicts)
      final fileName = p.basenameWithoutExtension(newName);
      File coverFile = File(p.join(cacheDir.path, '${fileName}_cover.jpg'));
      bool coverCreated = false;

      // Priority 1: Use coverBytes if already available (from search or existing metadata)
      if (_matchResults[index].coverBytes != null) {
        try {
          coverFile.writeAsBytesSync(_matchResults[index].coverBytes!);
          if (coverFile.existsSync()) {
            coverCreated = true;
            debugPrint("✅ Cover written from bytes: ${coverFile.path}");
          }
        } catch (e) {
          debugPrint("⚠️  Failed to write cover from bytes: $e");
        }
      }

      // Priority 2: Download or copy from posterUrl if coverBytes not available
      if (!coverCreated) {
        String? posterUrl = _matchResults[index].posterUrl;
        if (posterUrl != null && posterUrl.isNotEmpty) {
          if (posterUrl.startsWith('http')) {
            await CoreBackend.downloadCover(posterUrl, coverFile.path);
            if (coverFile.existsSync()) {
              coverCreated = true;
              debugPrint("✅ Cover downloaded from URL: ${coverFile.path}");
            }
          } else if (File(posterUrl).existsSync()) {
            File(posterUrl).copySync(coverFile.path);
            if (coverFile.existsSync()) {
              coverCreated = true;
              debugPrint("✅ Cover copied from file: ${coverFile.path}");
            }
          }
        }
      }

      // Embed Metadata with cover if available
      debugPrint("🎬 Embedding metadata for: $newName");
      await CoreBackend.embedMetadata(
        newFullPath,
        coverFile.existsSync() ? coverFile.path : null,
        _matchResults[index],
        settings: settings,
      );

      // Clean up cover file if we created it
      if (coverCreated && coverFile.existsSync()) {
        try {
          coverFile.deleteSync();
          debugPrint("🗑️  Cleaned up cover: ${coverFile.path}");
        } catch (e) {
          debugPrint("⚠️  Failed to delete cover file: $e");
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

  Future<void> addFiles(List<XFile> files, {SettingsService? settings}) async {
    _isAddingFiles = true;
    notifyListeners();

    int filesWithMetadata = 0;
    int filesAdded = 0;

    debugPrint("\n📁 Adding ${files.length} files...");

    try {
      for (var file in files) {
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

  // Update specific record (e.g. manual edit)
  void updateRecordMetadata(int index, String? newTitle, int? newSeason,
      int? newEpisode, int? newYear) {
    // We can't easily update MediaRecord internal metadata since it's final in some parts or parsed.
    // But we can update the 'override' fields if we had them or re-create the record.
    // Actually MediaRecord uses ParsedMetadata.
    // Let's make MediaRecord mutable or wrap it.
    // For now, let's just trigger a re-parse or add a way to override.
    // We will handle this by creating a new MediaRecord or modifying it if we make it mutable.
  }
}
