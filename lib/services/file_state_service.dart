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
  bool _canUndo = false;
  List<String> _lastRenamedOldPaths = [];
  List<String> _lastRenamedNewNames = [];

  List<MediaRecord> get inputFiles => _inputFiles;
  List<MatchResult> get matchResults => _matchResults;
  bool get isLoading => _isLoading;
  bool get canUndo => _canUndo;

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

  Future<void> renameFiles() async {
    if (_inputFiles.length != _matchResults.length) return;

    _isLoading = true;
    notifyListeners();

    try {
      List<String> oldPaths = _inputFiles.map((m) => m.fullFilePath).toList();
      List<String> newNames = _matchResults.map((r) => r.newName).toList();

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

        File coverFile = File(p.join(parentDir, "cover.jpg"));

        // Download/copy cover if needed
        if (posterUrl != null && posterUrl.isNotEmpty) {
          if (!coverFile.existsSync()) {
            debugPrint("📥 Downloading cover for: ${newName}");
            try {
              if (posterUrl.startsWith('http')) {
                var response = await http.get(Uri.parse(posterUrl));
                if (response.statusCode == 200) {
                  coverFile.writeAsBytesSync(response.bodyBytes);
                  coverFilesCreated.add(coverFile.path);
                  debugPrint("✅ Cover downloaded: ${coverFile.path}");
                } else {
                  debugPrint(
                      "❌ Failed to download cover: HTTP ${response.statusCode}");
                }
              } else {
                File source = File(posterUrl);
                if (source.existsSync()) {
                  source.copySync(coverFile.path);
                  coverFilesCreated.add(coverFile.path);
                  debugPrint("✅ Cover copied: ${coverFile.path}");
                }
              }
            } catch (e) {
              debugPrint("❌ Error saving cover: $e");
            }
          } else {
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
      debugPrint("Rename Error: $e");
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

  void addFiles(List<XFile> files) {
    for (var file in files) {
      // Avoid duplicates if needed, or allow
      bool exists = _inputFiles.any((f) => f.fullFilePath == file.path);
      if (!exists) {
        _inputFiles.add(MediaRecord(file.path));
      }
    }
    // If we add files, old matches are invalid for the new set unless we keep them partial?
    // Simpler to clear matches or mark them dirty.
    // User requested persistence, but if we add new files, we usually want to match everything again or just the new ones.
    // For now, let's keep it simple: mismatch count means re-match needed.
    notifyListeners();
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
