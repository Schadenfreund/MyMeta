import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';
import 'tool_resolver.dart';

/// Service for downloading and managing third-party tools
class ToolDownloaderService {
  /// Get the portable tools directory in UserData
  static Future<Directory> getToolsDirectory() async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    final toolsDir = Directory(p.join(exeDir, 'UserData', 'tools'));

    if (!toolsDir.existsSync()) {
      toolsDir.createSync(recursive: true);
    }
    return toolsDir;
  }

  /// Check if a tool is installed
  static Future<bool> isToolInstalled(String toolName) async {
    final path = await getToolPath(toolName);
    return path != null;
  }

  /// Path to the installed executable for [toolName] under `UserData/tools`,
  /// or `null` when the tool is not installed. Thin wrapper around
  /// [ToolResolver] preserved for backwards compatibility with existing
  /// callers — note that [ToolResolver] also consults custom-configured
  /// paths and the bundled location.
  static Future<String?> getToolPath(String toolName) =>
      ToolResolver.resolveExe(toolName);

  /// Download and extract a tool with progress callback
  static Future<bool> downloadTool(
    String toolName,
    String url, {
    Function(int, int, String)? progressCallback,
  }) async {
    try {
      final toolsDir = await getToolsDirectory();
      final bool is7z = url.toLowerCase().endsWith('.7z');

      if (!ToolConfig.toolSubdirectories.containsKey(toolName.toLowerCase())) {
        throw Exception('Unknown tool: $toolName');
      }
      final subDir = ToolConfig.getSubdirectory(toolName);

      final targetDir = Directory(p.join(toolsDir.path, subDir));
      if (targetDir.existsSync()) {
        // Retry logic for deletion in case of locks
        try {
          targetDir.deleteSync(recursive: true);
        } catch (e) {
          // Wait a bit and try again
          await Future.delayed(Duration(milliseconds: 500));
          if (targetDir.existsSync()) {
            targetDir.deleteSync(recursive: true);
          }
        }
      }
      targetDir.createSync(recursive: true);

      // Check if we need to bootstrap 7zip for .7z files
      if (is7z) {
        progressCallback?.call(0, 100, 'Checking 7-Zip...');
        await _ensure7Zip();
      }

      // Download the file
      progressCallback?.call(0, 100, 'Connecting...');

      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'MyMeta/1.0';

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final chunks = <int>[];

      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
        downloadedBytes += chunk.length;
        progressCallback?.call(
          downloadedBytes,
          totalBytes,
          'Downloading... ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB',
        );
      }

      // Save to temp file
      final tempFile = File(p.join(
        Directory.systemTemp.path,
        'mymeta_download_${toolName}_${DateTime.now().millisecondsSinceEpoch}${is7z ? '.7z' : '.zip'}',
      ));
      await tempFile.writeAsBytes(chunks);

      progressCallback?.call(totalBytes, totalBytes, 'Extracting...');

      // Extract based on file type
      if (is7z) {
        await _extract7z(tempFile.path, targetDir.path);
      } else {
        // Extract zip file
        await _extractZip(tempFile.path, targetDir.path);
      }

      tempFile.deleteSync();

      // Newly-extracted binary supersedes any previously cached location.
      ToolResolver.invalidate(toolName);

      progressCallback?.call(totalBytes, totalBytes, 'Complete!');
      return true;
    } catch (e) {
      debugPrint('Error downloading $toolName: $e');
      rethrow;
    }
  }

  /// Download standalone 7za.exe if needed
  static Future<void> _ensure7Zip() async {
    final toolsDir = await getToolsDirectory();
    final sevenZipPath = p.join(toolsDir.path, '7za.exe');

    if (File(sevenZipPath).existsSync()) return;

    // Download 7za.exe (standalone console version)
    const sevenZipUrl = 'https://www.7-zip.org/a/7za920.zip';

    final request = http.Request('GET', Uri.parse(sevenZipUrl));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) throw Exception('Failed to download 7zip');

    final chunks = <int>[];
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
    }

    final tempZip = File(p.join(Directory.systemTemp.path, '7za920.zip'));
    await tempZip.writeAsBytes(chunks);

    // Extract 7za.exe using PowerShell (since it's a zip)
    final tempDir = Directory(p.join(Directory.systemTemp.path, '7za_temp'));
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync();

    await _extractZip(tempZip.path, tempDir.path);

    // Move 7za.exe to tools dir
    final extracted7za = File(p.join(tempDir.path, '7za.exe'));
    if (extracted7za.existsSync()) {
      extracted7za.copySync(sevenZipPath);
    }

    try {
      tempZip.deleteSync();
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }

  static Future<void> _extract7z(String archivePath, String targetDir) async {
    final toolsDir = await getToolsDirectory();
    final sevenZipPath = p.join(toolsDir.path, '7za.exe');

    if (!File(sevenZipPath).existsSync()) {
      throw Exception('7za.exe not found');
    }

    final result = await Process.run(
      sevenZipPath,
      ['x', archivePath, '-o$targetDir', '-y'],
    );

    if (result.exitCode != 0) {
      throw Exception('7-Zip extraction failed: ${result.stderr}');
    }
  }

  /// Extract a ZIP file
  static Future<void> _extractZip(String zipPath, String targetDir) async {
    // Use PowerShell to extract on Windows
    final result = await Process.run(
      'powershell',
      [
        '-Command',
        'Expand-Archive -Path "$zipPath" -DestinationPath "$targetDir" -Force',
      ],
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to extract: ${result.stderr}');
    }
  }
}
