import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';
import '../services/file_state_service.dart';
import '../backend/media_record.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../widgets/inline_metadata_editor.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';
import 'package:path/path.dart' as p;

class RenamerPage extends StatefulWidget {
  const RenamerPage({super.key});

  @override
  State<RenamerPage> createState() => _RenamerPageState();
}

class _RenamerPageState extends State<RenamerPage> {
  int? _expandedIndex;
  final Set<int> _searchedIndices =
      {}; // Track which items have successful metadata searches
  final Set<int> _renamingIndices =
      {}; // Track which items are currently being renamed
  final Set<int> _autoMatchedIndices =
      {}; // Track which items were auto-matched via "Search All"

  Future<void> _pickFiles(BuildContext context) async {
    // Read context values BEFORE any async operations
    final fileState = context.read<FileStateService>();
    final settings = context.read<SettingsService>();

    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      List<XFile> xFiles = result.paths.map((path) => XFile(path!)).toList();
      await fileState.addFiles(xFiles, settings: settings);

      // Check for FFmpeg warning (important for functionality)
      if (context.mounted && fileState.lastAddResult != null) {
        final addResult = fileState.lastAddResult!;
        final added = addResult['added'] ?? 0;
        final withMetadata = addResult['withMetadata'] ?? 0;
        final ffmpegMissing = (addResult['ffmpegMissing'] ?? 0) > 0;

        // Show warning if FFmpeg is missing and files don't have metadata
        if (ffmpegMissing && added > withMetadata) {
          SnackbarHelper.showWarning(
            context,
            'FFmpeg not found. Configure in Settings → FFmpeg to read embedded metadata.',
          );
        }

        // Extract covers in background (non-blocking)
        if (added > 0) {
          fileState.extractCoversInBackground(settings: settings);
        }

        fileState.clearLastAddResult();
      }
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  void _removeSearchedIndex(int index) {
    setState(() {
      // Shift all indices greater than the removed one
      final toRemoveSearched = <int>{};
      final toAddSearched = <int>{};
      final toRemoveRenaming = <int>{};
      final toAddRenaming = <int>{};
      final toRemoveAutoMatched = <int>{};
      final toAddAutoMatched = <int>{};

      for (int idx in _searchedIndices) {
        if (idx == index) {
          toRemoveSearched.add(idx);
        } else if (idx > index) {
          toRemoveSearched.add(idx);
          toAddSearched.add(idx - 1);
        }
      }

      for (int idx in _renamingIndices) {
        if (idx == index) {
          toRemoveRenaming.add(idx);
        } else if (idx > index) {
          toRemoveRenaming.add(idx);
          toAddRenaming.add(idx - 1);
        }
      }

      for (int idx in _autoMatchedIndices) {
        if (idx == index) {
          toRemoveAutoMatched.add(idx);
        } else if (idx > index) {
          toRemoveAutoMatched.add(idx);
          toAddAutoMatched.add(idx - 1);
        }
      }

      _searchedIndices.removeAll(toRemoveSearched);
      _searchedIndices.addAll(toAddSearched);
      _renamingIndices.removeAll(toRemoveRenaming);
      _renamingIndices.addAll(toAddRenaming);
      _autoMatchedIndices.removeAll(toRemoveAutoMatched);
      _autoMatchedIndices.addAll(toAddAutoMatched);
    });
  }

  // Handle drag and drop with snackbar
  Future<void> _handleDragDrop(BuildContext context, List<XFile> files) async {
    final fileState = context.read<FileStateService>();
    final settings = context.read<SettingsService>();
    await fileState.addFiles(files, settings: settings);

    // Show snackbar with results
    if (context.mounted && fileState.lastAddResult != null) {
      final addResult = fileState.lastAddResult!;
      final added = addResult['added'] ?? 0;
      final withMetadata = addResult['withMetadata'] ?? 0;
      final ffmpegMissing = (addResult['ffmpegMissing'] ?? 0) > 0;

      if (added > 0) {
        String message = 'Added $added file${added > 1 ? 's' : ''}';
        if (withMetadata > 0) {
          message += ' ($withMetadata with existing metadata)';
        }

        SnackbarHelper.showSuccess(context, message);

        // Show FFmpeg warning if needed
        if (ffmpegMissing && added > withMetadata) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              SnackbarHelper.showWarning(
                context,
                'FFmpeg not found. Configure in Settings → FFmpeg to read embedded metadata.',
              );
            }
          });
        }

        // Extract covers in background (non-blocking)
        fileState.extractCoversInBackground(settings: settings);
      }

      fileState.clearLastAddResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileState = context.watch<FileStateService>();
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasFiles = fileState.inputFiles.isNotEmpty;
    final hasUnrenamedFiles = fileState.inputFiles.any((f) => !f.isRenamed);
    final canRename =
        hasFiles && fileState.matchResults.isNotEmpty && hasUnrenamedFiles;

    return Stack(
      children: [
        // Main content - Full screen list
        DropTarget(
          onDragDone: (detail) => _handleDragDrop(context, detail.files),
          child: ListView.builder(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              // Increased top padding to avoid intersection with the retractable tab bar
              top: AppDimensions.tabBarHeight + AppSpacing.md,
              bottom: 80, // Extra padding for floating buttons
            ),
            itemCount: fileState.inputFiles.length + 1, // +1 for add button
            itemBuilder: (context, index) {
              // Add Files Card (Inline)
              if (index == fileState.inputFiles.length) {
                return _buildAddFilesCard(context, isDark);
              }

              final input = fileState.inputFiles[index];
              MatchResult? output;
              if (index < fileState.matchResults.length) {
                output = fileState.matchResults[index];
              }

              bool isRenamed = input.isRenamed;
              bool isExpanded = _expandedIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildFileCard(
                  context,
                  index,
                  input,
                  output,
                  isRenamed,
                  isExpanded,
                  fileState,
                ),
              );
            },
          ),
        ),

        // Floating Action Buttons (bottom right) - only when files exist
        if (hasFiles && !fileState.isLoading)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search All Button - only if there are files without metadata
                if (hasFiles) ...[
                  _buildMinimalIconButton(
                    context,
                    icon: Icons.cloud_download_outlined,
                    tooltip: 'Search All Metadata',
                    onPressed: () async {
                      // Smart API selection - use any available API
                      final hasTmdb = settings.tmdbApiKey.isNotEmpty;
                      final hasOmdb = settings.omdbApiKey.isNotEmpty;
                      final hasAnidb = settings.anidbClientId.isNotEmpty;

                      if (!hasTmdb && !hasOmdb && !hasAnidb) {
                        SnackbarHelper.showWarning(
                          context,
                          'No API keys configured. Go to Settings to add at least one (TMDB, OMDb, or AniDB).',
                        );
                        return;
                      }

                      // Show confirmation modal before searching
                      final confirmedTitles = await _showSearchAllConfirmationModal(context, settings);

                      if (confirmedTitles == null) {
                        // User cancelled
                        return;
                      }

                      setState(() => _expandedIndex = null);

                      SnackbarHelper.showInfo(
                        context,
                        'Searching metadata for all files...',
                      );

                      // Search each file using its (possibly user-edited) title
                      int foundCount = 0;
                      int unmatchedIdx = 0;
                      for (int i = 0; i < fileState.inputFiles.length; i++) {
                        if (!fileState.inputFiles[i].isRenamed) {
                          final override = unmatchedIdx < confirmedTitles.length
                              ? confirmedTitles[unmatchedIdx].trim()
                              : null;
                          unmatchedIdx++;
                          await fileState.matchSingleFile(
                            i,
                            settings,
                            overrideTitle: (override != null && override.isNotEmpty) ? override : null,
                          );

                          // Check if metadata was found
                          if (i < fileState.matchResults.length) {
                            final result = fileState.matchResults[i];
                            if (result.title != null &&
                                result.title!.isNotEmpty) {
                              foundCount++;
                              setState(() {
                                _searchedIndices.add(i);
                                _autoMatchedIndices
                                    .add(i); // Track as auto-matched
                              });
                            }
                          }
                        }
                      }

                      if (context.mounted) {
                        if (foundCount > 0) {
                          SnackbarHelper.showSuccess(
                            context,
                            'Found metadata for $foundCount file${foundCount > 1 ? 's' : ''}',
                          );
                        } else {
                          SnackbarHelper.showWarning(
                            context,
                            'No metadata found. Try editing manually.',
                          );
                        }
                      }
                    },
                    isDark: isDark,
                    iconColor: settings.accentColor,
                  ),
                  const SizedBox(width: 8),
                ],

                // Metadata-Only toggle
                if (hasFiles) ...[
                  _buildMetadataOnlyToggle(context, settings, isDark),
                  const SizedBox(width: 8),
                ],

                // Apply All Button - only if there are files to apply
                if (canRename) ...[
                  _buildMinimalIconButton(
                    context,
                    icon: Icons.check,
                    tooltip: settings.metadataOnly
                        ? 'Embed Metadata Only (no rename)'
                        : 'Apply Metadata to All Files',
                    onPressed: () {
                      setState(() => _expandedIndex = null);
                      final settings = context.read<SettingsService>();
                      fileState.renameFiles(settings: settings);
                    },
                    isDark: isDark,
                    isPrimary: false,
                    accentColor: settings.accentColor,
                  ),
                  const SizedBox(width: 8),
                ],

                // Clear All Button
                _buildMinimalIconButton(
                  context,
                  icon: Icons.close,
                  tooltip: 'Clear All',
                  onPressed: () {
                    setState(() => _expandedIndex = null);
                    fileState.clearAll();
                  },
                  isDark: isDark,
                  isDestructive: false, // Make it grey instead of red
                ),
              ],
            ),
          ),

        // Processing indicator
        if (fileState.isLoading)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: settings.accentColor.withAlpha(100),
                ),
                boxShadow:
                    isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow,
              ),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    settings.accentColor,
                  ),
                ),
              ),
            ),
          ),

        // Loading Overlay when adding files
        if (fileState.isAddingFiles)
          Positioned.fill(
            child: Container(
              color: (isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground)
                  .withAlpha(200),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark
                        ? AppTheme.darkCardShadow
                        : AppTheme.lightCardShadow,
                    border: Border.all(
                      color: settings.accentColor.withAlpha(75),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            settings.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading files...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reading metadata',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a minimal icon button for the floating action area
  Widget _buildMinimalIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
    bool isPrimary = false,
    bool isDestructive = false,
    Color? accentColor,
    Color? iconColor,
  }) {
    final Color buttonColor = isPrimary
        ? (accentColor ?? Theme.of(context).colorScheme.primary)
        : (isDestructive
            ? AppColors.lightDanger
            : (isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary));

    final Color effectiveIconColor =
        iconColor ?? (isPrimary ? Colors.white : buttonColor);

    final Color bgColor = isPrimary
        ? buttonColor
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        elevation: isPrimary ? 2 : 1,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isPrimary
                  ? null
                  : Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: effectiveIconColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Toggle button for metadata-only mode (embed without renaming).
  Widget _buildMetadataOnlyToggle(
      BuildContext context, SettingsService settings, bool isDark) {
    final isActive = settings.metadataOnly;
    final accent = settings.accentColor;
    final bgColor = isActive ? accent : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final iconColor = isActive ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Tooltip(
      message: isActive
          ? 'Metadata Only: ON — files will not be renamed'
          : 'Metadata Only: OFF — files will be renamed',
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        elevation: isActive ? 2 : 1,
        child: InkWell(
          onTap: () => settings.setMetadataOnly(!isActive),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? null
                  : Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
            ),
            child: Icon(
              Icons.drive_file_rename_outline,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  // Inline Add Files Card
  Widget _buildAddFilesCard(BuildContext context, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: () => _pickFiles(context),
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                "Add Files",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                "or drop here",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    int index,
    MediaRecord input,
    MatchResult? output,
    bool isRenamed,
    bool isExpanded,
    FileStateService fileState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.read<SettingsService>();

    return Card(
      elevation: isExpanded ? 2 : 0,
      color: isRenamed
          ? AppColors.lightSuccess.withOpacity(0.1)
          : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        side: BorderSide(
          color: isRenamed
              ? AppColors.lightSuccess.withOpacity(0.3)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Main Row
          InkWell(
            onTap: () => _toggleExpanded(index),
            borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cover Image Thumbnail - use coverBytes if available, posterUrl as fallback
                  if (output?.coverBytes != null || output?.posterUrl != null)
                    Container(
                      width: 40,
                      height: 60,
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.inputBorderRadius),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.inputBorderRadius),
                        child: output!.coverBytes != null
                            ? Image.memory(
                                output.coverBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.broken_image, size: 20);
                                },
                              )
                            : (output.posterUrl != null &&
                                    output.posterUrl!.startsWith('http'))
                                ? Image.network(
                                    output.posterUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.broken_image, size: 20);
                                    },
                                  )
                                : Icon(Icons.image_not_supported, size: 20),
                      ),
                    ),

                  // File Info (Left side)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          input.fileName,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isRenamed
                                        ? (isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.lightTextTertiary)
                                        : (isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary),
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (output != null &&
                            output.title != null &&
                            output.title!.isNotEmpty)
                          Text(
                            _buildMetadataPreview(output, seasonDigits: settings.seasonDigits, episodeDigits: settings.episodeDigits),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            "No metadata • Click to edit manually or use Match button",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.lightTextTertiary,
                                      fontStyle: FontStyle.italic,
                                    ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Arrow Icon - always forward arrow for consistency
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Output Name (Right side)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isRenamed
                              ? p.basename(input.renamedPath!)
                              : (output?.newName ?? "Pending..."),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isRenamed
                                        ? AppColors.lightSuccess
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Subheader with metadata preview
                        if (output != null &&
                            output.title != null &&
                            output.title!.isNotEmpty)
                          Text(
                            _buildMetadataPreview(output, seasonDigits: settings.seasonDigits, episodeDigits: settings.episodeDigits),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: isRenamed
                                      ? AppColors.lightSuccess.withOpacity(0.7)
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            isRenamed ? "Completed" : "Ready to rename",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.lightTextTertiary,
                                      fontStyle: FontStyle.italic,
                                    ),
                          ),
                      ],
                    ),
                  ),

                  // Search/Fix Match Button - shows different icon for auto-matched files
                  IconButton(
                    icon: Icon(
                      _autoMatchedIndices.contains(index)
                          ? Icons.change_circle_outlined
                          : Icons.cloud_download_outlined,
                      size: 20,
                    ),
                    color: settings.accentColor,
                    onPressed: () async {
                      if (isRenamed) {
                        fileState.resetRenamedStatus(index);
                      }

                      await _showSearchModal(
                        context,
                        index,
                        input,
                        fileState,
                        settings,
                        initialResults: output?.searchResults,
                      );
                    },
                    tooltip: _autoMatchedIndices.contains(index)
                        ? "Fix Match - Select different result"
                        : "Search online metadata",
                  ),

                  // Apply Button (checkmark - shows spinner when processing, green when done)
                  _buildApplyButton(context, index, isRenamed, fileState),

                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    onPressed: () {
                      if (isExpanded) _toggleExpanded(index);
                      _removeSearchedIndex(index);
                      fileState.removeFileAt(index);
                    },
                    tooltip: "Remove",
                  ),
                ],
              ),
            ),
          ),

          // Expanded Metadata Editor
          if (isExpanded)
            InlineMetadataEditor(
              originalName: input.fileName,
              initialResult: output ?? MatchResult(newName: input.fileName),
              onSave: (newResult) {
                fileState.updateManualMatch(index, newResult);
              },
              onCancel: () => _toggleExpanded(index),
              onSearch: () {
                final settings = context.read<SettingsService>();
                _showSearchModal(context, index, input, fileState, settings);
              },
              onRename: (MatchResult result) async {
                // Update the match result and apply to file
                fileState.updateManualMatch(index, result);
                // Then rename
                final settings = context.read<SettingsService>();
                final success =
                    await fileState.renameSingleFile(index, settings: settings);
                if (context.mounted) {
                  _toggleExpanded(index);
                  if (success) {
                    SnackbarHelper.showSuccess(
                        context, 'File renamed successfully!');
                  } else {
                    SnackbarHelper.showError(context,
                        'Failed to rename file. Check console for details.');
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  String _buildMetadataPreview(MatchResult output, {int seasonDigits = 2, int episodeDigits = 2}) {
    if (output.type == 'episode') {
      String season = output.season != null
          ? 'S${output.season.toString().padLeft(seasonDigits, '0')}'
          : 'S??';
      String episode = output.episode != null
          ? 'E${output.episode.toString().padLeft(episodeDigits, '0')}'
          : 'E??';
      String year = output.year != null ? ' • ${output.year}' : '';
      return "${output.title ?? 'Unknown'} • $season$episode$year";
    } else {
      String year = output.year != null ? ' • ${output.year}' : '';
      String genres = output.genres != null && output.genres!.isNotEmpty
          ? ' • ${output.genres!.take(2).join(', ')}'
          : '';
      return "${output.title ?? 'Unknown Movie'}$year$genres";
    }
  }

  /// Builds the apply button (checkmark icon)
  /// Shows spinner when processing, green checkmark when done
  Widget _buildApplyButton(
    BuildContext context,
    int index,
    bool isRenamed,
    FileStateService fileState,
  ) {
    final settings = context.read<SettingsService>();

    // Show green checkmark when successfully renamed
    if (isRenamed) {
      return IconButton(
        icon: const Icon(Icons.check_circle, size: 20),
        color: AppColors.lightSuccess,
        onPressed: null,
        tooltip: "Applied successfully",
      );
    }

    // Show spinner when processing
    if (_renamingIndices.contains(index)) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Show checkmark to apply
    return IconButton(
      icon: const Icon(Icons.check, size: 20),
      color: iconColor,
      onPressed: () async {
        setState(() => _renamingIndices.add(index));

        final success =
            await fileState.renameSingleFile(index, settings: settings);

        if (!context.mounted) return;

        setState(() {
          _renamingIndices.remove(index);
          if (success) {
            _searchedIndices.remove(index);
          }
        });

        if (success) {
          // Increment statistics for successfully renamed files
          final output = fileState.matchResults[index];
          if (output.type == 'episode') {
            await settings.incrementTvShowMatches(1);
          } else if (output.type == 'movie') {
            await settings.incrementMovieMatches(1);
          }

          SnackbarHelper.showSuccess(context, 'Applied successfully!');
        } else {
          SnackbarHelper.showError(context, 'Failed to apply.');
        }
      },
      tooltip: "Apply metadata to file",
    );
  }

  /// Resolves the active metadata API source and key from settings.
  static ({String source, String apiKey})? _resolveApi(SettingsService settings) {
    final preferred = settings.metadataSource;
    final keys = {
      'tmdb': settings.tmdbApiKey,
      'omdb': settings.omdbApiKey,
      'anidb': settings.anidbClientId,
    };
    if (keys[preferred]?.isNotEmpty == true) {
      return (source: preferred, apiKey: keys[preferred]!);
    }
    for (final entry in keys.entries) {
      if (entry.value.isNotEmpty) return (source: entry.key, apiKey: entry.value);
    }
    return null;
  }

  /// Unified search modal — used for both first-time search and Fix Match.
  /// Shows a text field for the query, a search button, and a results list.
  Future<void> _showSearchModal(
    BuildContext context,
    int index,
    MediaRecord input,
    FileStateService fileState,
    SettingsService settings, {
    List<MatchResult>? initialResults,
  }) async {
    final api = _resolveApi(settings);
    if (api == null) {
      SnackbarHelper.showWarning(
        context,
        'No API keys configured. Go to Settings to add at least one (TMDB, OMDb, or AniDB).',
      );
      return;
    }

    final searchController = TextEditingController(
      text: input.title ?? input.fileName,
    );

    List<MatchResult> results = List.from(initialResults ?? []);
    bool isSearching = false;
    String? errorMessage;

    // Get season/episode context from current match or file
    final currentMatch = fileState.matchResults.length > index
        ? fileState.matchResults[index]
        : null;
    final season = currentMatch?.season ?? input.season;
    final episode = currentMatch?.episode ?? input.episode;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        // Auto-search on open when there are no initial results
        bool didAutoSearch = initialResults != null && initialResults.isNotEmpty;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Trigger auto-search once
            if (!didAutoSearch) {
              didAutoSearch = true;
              Future.microtask(() async {
                setModalState(() => isSearching = true);
                try {
                  final newResults = await CoreBackend.searchMetadata(
                    title: searchController.text.trim(),
                    year: input.year,
                    isMovie: input.type == 'movie',
                    source: api.source,
                    apiKey: api.apiKey,
                    season: season,
                    episode: episode,
                    useSeasonPoster: settings.useSeasonPoster,
                  );
                  setModalState(() {
                    results = newResults;
                    isSearching = false;
                    if (newResults.isEmpty) {
                      errorMessage = 'No results found';
                    }
                  });
                } catch (e) {
                  setModalState(() {
                    isSearching = false;
                    errorMessage = 'Search failed: $e';
                  });
                }
              });
            }

            Future<void> doSearch() async {
              final query = searchController.text.trim();
              if (query.isEmpty) return;
              setModalState(() {
                isSearching = true;
                errorMessage = null;
              });
              try {
                final newResults = await CoreBackend.searchMetadata(
                  title: query,
                  year: null, // Don't constrain re-searches by year
                  isMovie: input.type == 'movie',
                  source: api.source,
                  apiKey: api.apiKey,
                  season: season,
                  episode: episode,
                  useSeasonPoster: settings.useSeasonPoster,
                );
                setModalState(() {
                  results = newResults;
                  isSearching = false;
                  if (newResults.isEmpty) {
                    errorMessage = 'No results found for "$query"';
                  }
                });
              } catch (e) {
                setModalState(() {
                  isSearching = false;
                  errorMessage = 'Search failed: $e';
                });
              }
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              child: Container(
                width: 700,
                height: 600,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.search, color: settings.accentColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select Match',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'Search title...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: settings.accentColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => doSearch(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isSearching ? null : doSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: settings.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Search'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Results / loading / error
                    Expanded(
                      child: isSearching
                          ? Center(
                              child: CircularProgressIndicator(
                                color: settings.accentColor,
                              ),
                            )
                          : errorMessage != null && results.isEmpty
                              ? Center(
                                  child: Text(
                                    errorMessage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final result = results[i];
                                    final subtitle = [
                                      if (result.year != null) '${result.year}',
                                      result.type ?? 'Unknown',
                                      if (result.rating != null)
                                        '\u2605 ${result.rating!.toStringAsFixed(1)}',
                                      if (result.genres != null &&
                                          result.genres!.isNotEmpty)
                                        result.genres!.take(2).join(', '),
                                    ].join(' \u2022 ');

                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: result.posterUrl != null
                                            ? Image.network(
                                                result.posterUrl!,
                                                width: 40,
                                                height: 56,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox(
                                                  width: 40,
                                                  height: 56,
                                                  child: Icon(Icons.movie),
                                                ),
                                              )
                                            : const SizedBox(
                                                width: 40,
                                                height: 56,
                                                child: Icon(Icons.movie),
                                              ),
                                      ),
                                      title: Text(result.title ?? 'Unknown'),
                                      subtitle: Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _applyFixMatchResult(
                                          index,
                                          result,
                                          results,
                                          input,
                                          fileState,
                                          settings,
                                        );
                                        setState(() {
                                          _autoMatchedIndices.remove(index);
                                          _searchedIndices.add(index);
                                        });
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  /// Applies a Fix Match result with complete metadata (cover download + formatted name)
  Future<void> _applyFixMatchResult(
    int index,
    MatchResult selectedResult,
    List<MatchResult> searchResults,
    MediaRecord input,
    FileStateService fileState,
    SettingsService settings,
  ) async {
    debugPrint("🔄 Applying Fix Match result: ${selectedResult.title}");

    MatchResult completeResult = selectedResult;

    // Download cover art if not already present
    if (completeResult.coverBytes == null &&
        completeResult.posterUrl != null &&
        completeResult.posterUrl!.startsWith('http')) {
      try {
        debugPrint("📥 Downloading cover for Fix Match result...");
        final response = await http.get(Uri.parse(completeResult.posterUrl!));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          completeResult =
              completeResult.copyWith(coverBytes: response.bodyBytes);
          debugPrint("✅ Cover downloaded");
        }
      } catch (e) {
        debugPrint("⚠️ Failed to download cover: $e");
      }
    }

    // Generate formatted filename based on the new metadata
    String format = (completeResult.type == 'episode')
        ? settings.seriesFormat
        : settings.movieFormat;

    Map<String, dynamic> contextData = {};
    if (completeResult.type == 'episode') {
      contextData = {
        "series_name": completeResult.title,
        "year": completeResult.year,
        "season_number":
            completeResult.season?.toString().padLeft(settings.seasonDigits, '0') ?? "00",
        "episode_number":
            completeResult.episode?.toString().padLeft(settings.episodeDigits, '0') ?? "00",
        "episode_title": completeResult.episodeTitle ?? "",
      };
    } else {
      contextData = {
        "movie_name": completeResult.title,
        "year": completeResult.year,
      };
    }

    // Get original file extension
    String extension = "";
    if (input.fileName.contains('.')) {
      extension = input.fileName.split('.').last;
    }

    String newName = CoreBackend.createFormattedTitle(format, contextData);
    if (extension.isNotEmpty) {
      newName += ".$extension";
    }

    // Create final result with formatted name and preserved search results
    completeResult = completeResult.copyWith(
      newName: newName,
      searchResults: searchResults,
    );

    debugPrint("📋 Final Fix Match result:");
    debugPrint("   Title: ${completeResult.title}");
    debugPrint("   NewName: ${completeResult.newName}");
    debugPrint("   Cover: ${completeResult.coverBytes != null}");

    // Update the match in file state
    fileState.updateManualMatch(index, completeResult);
  }

  /// Shows a confirmation modal before bulk searching all metadata.
  /// Returns a list of (possibly user-edited) search titles — one per unmatched
  /// file — or null if the user cancelled.
  Future<List<String>?> _showSearchAllConfirmationModal(
    BuildContext context,
    SettingsService settings,
  ) async {
    final fileState = context.read<FileStateService>();
    final unmatched = fileState.inputFiles.where((f) => !f.isRenamed).toList();

    // Pre-fill one controller per file with its parsed title
    final controllers = unmatched
        .map((r) => TextEditingController(text: r.title ?? r.fileName))
        .toList();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.cloud_download_outlined, color: settings.accentColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search All Metadata',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Edit any title before searching. Each file is searched independently.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Editable file list
              if (unmatched.isNotEmpty) ...[
                Text(
                  '${unmatched.length} file${unmatched.length > 1 ? 's' : ''} to search:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: unmatched.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: controllers[i],
                                style: Theme.of(context).textTheme.bodySmall,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  hintText: unmatched[i].fileName,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: settings.accentColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      controllers.map((c) => c.text).toList(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: settings.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('Search All'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    for (final c in controllers) {
      c.dispose();
    }
    return result;
  }
}
