import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/file_state_service.dart';
import '../backend/media_record.dart';
import '../backend/match_result.dart';
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

      _searchedIndices.removeAll(toRemoveSearched);
      _searchedIndices.addAll(toAddSearched);
      _renamingIndices.removeAll(toRemoveRenaming);
      _renamingIndices.addAll(toAddRenaming);
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
                      // Check if API keys are configured
                      if (settings.metadataSource == 'tmdb' &&
                          settings.tmdbApiKey.isEmpty) {
                        SnackbarHelper.showWarning(
                          context,
                          'TMDB API key not configured. Go to Settings to add it.',
                        );
                        return;
                      }
                      if (settings.metadataSource == 'omdb' &&
                          settings.omdbApiKey.isEmpty) {
                        SnackbarHelper.showWarning(
                          context,
                          'OMDB API key not configured. Go to Settings to add it.',
                        );
                        return;
                      }

                      setState(() => _expandedIndex = null);

                      SnackbarHelper.showInfo(
                        context,
                        'Searching metadata for all files...',
                      );

                      // Search metadata for all files
                      int foundCount = 0;
                      for (int i = 0; i < fileState.inputFiles.length; i++) {
                        if (!fileState.inputFiles[i].isRenamed) {
                          await fileState.matchSingleFile(i, settings);

                          // Check if metadata was found
                          if (i < fileState.matchResults.length) {
                            final result = fileState.matchResults[i];
                            if (result.title != null &&
                                result.title!.isNotEmpty) {
                              foundCount++;
                              setState(() {
                                _searchedIndices.add(i);
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

                // Apply All Button - only if there are files to apply
                if (canRename) ...[
                  _buildMinimalIconButton(
                    context,
                    icon: Icons.check,
                    tooltip: 'Apply Metadata to All Files',
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
                            _buildMetadataPreview(output),
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
                            _buildMetadataPreview(output),
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

                  // Search Button (cloud icon) - always available, resets status if already applied
                  IconButton(
                    icon: const Icon(Icons.cloud_download_outlined, size: 20),
                    color: settings.accentColor,
                    onPressed: () async {
                      if (isRenamed) {
                        fileState.resetRenamedStatus(index);
                      }
                      await _performSearch(context, index, input, fileState,
                          context.read<SettingsService>());
                    },
                    tooltip: "Search online metadata",
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
                _performSearch(context, index, input, fileState, settings);
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

  String _buildMetadataPreview(MatchResult output) {
    if (output.type == 'episode') {
      String season = output.season != null
          ? 'S${output.season.toString().padLeft(2, '0')}'
          : 'S??';
      String episode = output.episode != null
          ? 'E${output.episode.toString().padLeft(2, '0')}'
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

  /// Performs metadata search for a single file
  Future<void> _performSearch(
    BuildContext context,
    int index,
    MediaRecord input,
    FileStateService fileState,
    SettingsService settings,
  ) async {
    // Check if API keys are configured
    if (settings.metadataSource == 'tmdb' && settings.tmdbApiKey.isEmpty) {
      SnackbarHelper.showWarning(
        context,
        'TMDB API key not configured. Go to Settings to add it.',
      );
      return;
    }
    if (settings.metadataSource == 'omdb' && settings.omdbApiKey.isEmpty) {
      SnackbarHelper.showWarning(
        context,
        'OMDB API key not configured. Go to Settings to add it.',
      );
      return;
    }

    SnackbarHelper.showInfo(
      context,
      'Searching for "${input.fileName}"...',
    );

    await fileState.matchSingleFile(index, settings);

    if (!context.mounted) return;

    final result = fileState.matchResults.length > index
        ? fileState.matchResults[index]
        : null;

    if (result != null && result.title != null && result.title!.isNotEmpty) {
      setState(() => _searchedIndices.add(index));
      SnackbarHelper.showSuccess(
        context,
        'Found: ${result.title}${result.year != null ? " (${result.year})" : ""}',
      );
    } else {
      SnackbarHelper.showWarning(
        context,
        'No match found. Try editing metadata manually.',
      );
    }
  }
}
