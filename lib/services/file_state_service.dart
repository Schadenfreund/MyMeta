import 'package:flutter/material.dart';
import '../backend/media_record.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import 'package:cross_file/cross_file.dart';
import 'settings_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

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

  Future<void> matchFiles(SettingsService settings) async {
    if (_inputFiles.isEmpty) return;

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
        metadataSource: settings.metadataSource,
      );

      _matchResults.clear();
      _matchResults.addAll(results);
    } catch (e) {
      debugPrint("Error matching: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Match a single file by index
  Future<void> matchSingleFile(int index, SettingsService settings) async {
    if (index < 0 || index >= _inputFiles.length) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Match just this one file
      List<MatchResult> results = await CoreBackend.matchTitles(
        [_inputFiles[index]], // Match single file
        seriesFormat: settings.seriesFormat,
        movieFormat: settings.movieFormat,
        tmdbApiKey: settings.tmdbApiKey,
        omdbApiKey: settings.omdbApiKey,
        metadataSource: settings.metadataSource,
      );

      if (results.isNotEmpty) {
        // Ensure matchResults has enough slots
        while (_matchResults.length <= index) {
          _matchResults.add(MatchResult(newName: ""));
        }
        _matchResults[index] = results.first;
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

      // Download or Copy Posters and Embed
      // Track which cover files we've created so we can clean them up later
      Set<String> coverFilesCreated = {};

      for (int i = 0; i < _inputFiles.length; i++) {
        String? posterUrl = _matchResults[i].posterUrl;
        String parentDir = p.dirname(oldPaths[i]);
        String newName = newNames[i];
        String newFullPath = p.join(parentDir, newName);

        // Handle cover art
        File coverFile = File(p.join(parentDir, 'cover.jpg'));
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
        } else if (posterUrl != null) {
          // posterUrl is set but empty string - indicates existing cover
          if (coverFile.existsSync()) {
            debugPrint("ℹ️  Cover already exists: ${coverFile.path}");
            coverFilesCreated.add(coverFile.path);
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

      // Handle cover art
      String? posterUrl = _matchResults[index].posterUrl;
      File coverFile = File(p.join(parentDir, 'cover.jpg'));
      bool coverCreated = false;

      if (posterUrl != null && posterUrl.isNotEmpty) {
        if (posterUrl.startsWith('http')) {
          await CoreBackend.downloadCover(posterUrl, coverFile.path);
          if (coverFile.existsSync()) coverCreated = true;
        } else if (File(posterUrl).existsSync()) {
          File(posterUrl).copySync(coverFile.path);
          if (coverFile.existsSync()) coverCreated = true;
        }
      }

      // Embed Metadata
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
    bool ffmpegMissing = false;

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
              // Check if it was due to missing FFmpeg
              if (!ffmpegMissing) {
                // Try to detect if FFmpeg is the issue (rough check)
                try {
                  final result = await Process.run('ffprobe', ['-version']);
                  if (result.exitCode != 0) {
                    ffmpegMissing = true;
                  }
                } catch (e) {
                  ffmpegMissing = true;
                }
              }
            }
          } catch (e) {
            debugPrint("    ❌ Error reading metadata: $e");
            // Add placeholder on error
            while (_matchResults.length < _inputFiles.length) {
              _matchResults.add(MatchResult(newName: ""));
            }
            ffmpegMissing = true;
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
        'ffmpegMissing': ffmpegMissing ? 1 : 0,
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
