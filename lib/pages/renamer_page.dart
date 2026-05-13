import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';
import '../services/file_state_service.dart';
import '../services/tmdb_service.dart';
import '../backend/media_record.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../widgets/inline_metadata_editor.dart';
import '../widgets/cover_picker_modal.dart';
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
                      final config = await _showSearchAllConfirmationModal(context, settings);

                      if (config == null) {
                        // User cancelled
                        return;
                      }

                      setState(() => _expandedIndex = null);

                      SnackbarHelper.showInfo(
                        context,
                        'Searching metadata for all files...',
                      );

                      // Search each file using its confirmed title and chosen provider
                      int foundCount = 0;
                      int unmatchedIdx = 0;
                      for (int i = 0; i < fileState.inputFiles.length; i++) {
                        if (!fileState.inputFiles[i].isRenamed) {
                          final override = unmatchedIdx < config.titles.length
                              ? config.titles[unmatchedIdx].trim()
                              : null;
                          unmatchedIdx++;
                          await fileState.matchSingleFile(
                            i,
                            settings,
                            overrideTitle: (override != null && override.isNotEmpty) ? override : null,
                            overrideSource: config.source,
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

                // Season Covers Button — shown when episode files with season data are loaded
                if (hasFiles && _hasSeasonGroups(fileState)) ...[
                  _buildMinimalIconButton(
                    context,
                    icon: Icons.photo_album_outlined,
                    tooltip: 'Season Covers',
                    onPressed: () =>
                        _showSeasonCoverDialog(context, fileState, settings),
                    isDark: isDark,
                    iconColor: settings.accentColor,
                  ),
                  const SizedBox(width: 8),
                ],

                // Apply-mode toggles: Rename / Cover / Fields
                if (hasFiles) ...[
                  _buildApplyToggle(
                    context,
                    icon: Icons.drive_file_rename_outline,
                    isActive: settings.doRename,
                    activeTooltip: 'Rename: ON — file will be renamed on disk',
                    inactiveTooltip: 'Rename: OFF — filename will not change',
                    onTap: () => settings.setDoRename(!settings.doRename),
                    isDark: isDark,
                    accentColor: settings.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildApplyToggle(
                    context,
                    icon: Icons.image_outlined,
                    isActive: settings.doCover,
                    activeTooltip: 'Cover: ON — existing cover will be replaced',
                    inactiveTooltip: 'Cover: OFF — existing cover will be kept',
                    onTap: () => settings.setDoCover(!settings.doCover),
                    isDark: isDark,
                    accentColor: settings.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildApplyToggle(
                    context,
                    icon: Icons.sell_outlined,
                    isActive: settings.doEmbedFields,
                    activeTooltip: 'Metadata: ON — fields (genre, actors, etc.) will be written',
                    inactiveTooltip: 'Metadata: OFF — metadata fields will not be changed',
                    onTap: () => settings.setDoEmbedFields(!settings.doEmbedFields),
                    isDark: isDark,
                    accentColor: settings.accentColor,
                  ),
                  const SizedBox(width: 8),
                ],

                // Apply All Button - only if there are files to apply
                if (canRename) ...[
                  _buildMinimalIconButton(
                    context,
                    icon: Icons.check,
                    tooltip: _applyTooltip(settings),
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

  /// Reusable toggle button for apply-mode flags (rename / cover / fields).
  Widget _buildApplyToggle(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required String activeTooltip,
    required String inactiveTooltip,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    final bgColor = isActive ? accentColor : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final iconColor = isActive ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Tooltip(
      message: isActive ? activeTooltip : inactiveTooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        elevation: isActive ? 2 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? null
                  : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }

  /// Builds the Apply All button tooltip summarising which operations are enabled.
  String _applyTooltip(SettingsService settings) {
    final ops = [
      if (settings.doRename) 'rename',
      if (settings.doCover) 'cover',
      if (settings.doEmbedFields) 'metadata',
    ];
    if (ops.isEmpty) return 'Apply (nothing enabled)';
    return 'Apply: ${ops.join(' + ')}';
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

  bool _hasSeasonGroups(FileStateService fileState) =>
      fileState.matchResults
          .any((r) => r.type == 'episode' && r.season != null && r.title != null);

  void _showSeasonCoverDialog(
    BuildContext context,
    FileStateService fileState,
    SettingsService settings,
  ) {
    // Group episode files by normalised (series title, season) key
    final Map<String, _SeasonGroup> groupMap = {};
    for (int i = 0; i < fileState.matchResults.length; i++) {
      final r = fileState.matchResults[i];
      if (r.type != 'episode' || r.title == null) continue;
      final key = '${r.title!.toLowerCase().trim()}___${r.season ?? -1}';
      groupMap.putIfAbsent(
        key,
        () => _SeasonGroup(
          seriesTitle: r.title!,
          season: r.season,
          tmdbId: r.tmdbId,
          fileIndices: [],
          currentCoverBytes: r.coverBytes,
          currentPosterUrl: r.posterUrl,
        ),
      );
      groupMap[key]!.fileIndices.add(i);
      // Capture a tmdbId from any file in the group if the first didn't have one
      if (groupMap[key]!.tmdbId == null && r.tmdbId != null) {
        groupMap[key]!.tmdbId = r.tmdbId;
      }
    }

    if (groupMap.isEmpty) return;

    final groups = groupMap.values.toList()
      ..sort((a, b) {
        final t = a.seriesTitle.compareTo(b.seriesTitle);
        return t != 0 ? t : (a.season ?? 0).compareTo(b.season ?? 0);
      });

    showDialog(
      context: context,
      builder: (_) => _SeasonCoverDialog(
        groups: groups,
        onApply: (updated) {
          for (final group in updated) {
            if (group.pendingCoverBytes == null) continue;
            for (final idx in group.fileIndices) {
              if (idx < fileState.matchResults.length) {
                fileState.updateManualMatch(
                  idx,
                  fileState.matchResults[idx].copyWith(
                    coverBytes: group.pendingCoverBytes,
                    clearCachedPosterPath: true,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  /// Shows the Search All confirmation dialog.
  /// Returns confirmed titles (one per unmatched file) and the chosen provider,
  /// or null if the user cancelled.
  Future<({List<String> titles, String source})?> _showSearchAllConfirmationModal(
    BuildContext context,
    SettingsService settings,
  ) {
    final unmatched = context
        .read<FileStateService>()
        .inputFiles
        .where((f) => !f.isRenamed)
        .toList();
    if (unmatched.isEmpty) return Future.value(null);

    return showDialog<({List<String> titles, String source})>(
      context: context,
      builder: (_) => _SearchAllConfirmationDialog(
        unmatched: unmatched,
        initialSource: settings.metadataSource,
      ),
    );
  }
}

// ─── Search All Confirmation Dialog ──────────────────────────────────────────

/// A group of files that share the same normalised title.
/// The user edits one shared field for the whole group, or expands it to
/// override each file individually.
class _TitleGroup {
  final List<int> unmatchedIndices;
  final TextEditingController sharedController;
  final List<TextEditingController> perFileControllers;
  bool expanded;

  _TitleGroup({
    required this.unmatchedIndices,
    required this.sharedController,
    required this.perFileControllers,
    this.expanded = false,
  });

  void dispose() {
    sharedController.dispose();
    for (final c in perFileControllers) {
      c.dispose();
    }
  }

  /// Returns the effective search title for the file at [localIndex].
  String titleFor(int localIndex) => expanded
      ? perFileControllers[localIndex].text.trim()
      : sharedController.text.trim();
}

class _SearchAllConfirmationDialog extends StatefulWidget {
  final List<MediaRecord> unmatched;
  final String initialSource;

  const _SearchAllConfirmationDialog({
    required this.unmatched,
    required this.initialSource,
  });

  @override
  State<_SearchAllConfirmationDialog> createState() =>
      _SearchAllConfirmationDialogState();
}

class _SearchAllConfirmationDialogState
    extends State<_SearchAllConfirmationDialog> {
  late String _source;
  late List<_TitleGroup> _groups;

  @override
  void initState() {
    super.initState();
    _groups = _buildGroups(widget.unmatched);
    // Resolve initialSource to a provider that actually has a key configured.
    _source = _resolveSource(
      widget.initialSource,
      context.read<SettingsService>(),
    );
  }

  @override
  void dispose() {
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  /// Returns [preferred] if it has a configured key, otherwise falls back to
  /// the first available provider.
  static String _resolveSource(String preferred, SettingsService settings) {
    final keys = {
      'tmdb': settings.tmdbApiKey,
      'omdb': settings.omdbApiKey,
      'anidb': settings.anidbClientId,
    };
    if (keys[preferred]?.isNotEmpty == true) return preferred;
    for (final e in keys.entries) {
      if (e.value.isNotEmpty) return e.key;
    }
    return preferred;
  }

  /// Groups [unmatched] files by their normalised title (lowercase,
  /// alphanumeric only) so duplicates share a single editable field.
  static List<_TitleGroup> _buildGroups(List<MediaRecord> unmatched) {
    final Map<String, List<int>> byKey = {};
    for (int i = 0; i < unmatched.length; i++) {
      final raw = unmatched[i].title ?? unmatched[i].fileName;
      final key = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      byKey.putIfAbsent(key, () => []).add(i);
    }
    return byKey.entries.map((e) {
      final indices = e.value;
      final displayTitle =
          unmatched[indices.first].title ?? unmatched[indices.first].fileName;
      return _TitleGroup(
        unmatchedIndices: indices,
        sharedController: TextEditingController(text: displayTitle),
        perFileControllers: indices
            .map((i) => TextEditingController(
                  text: unmatched[i].title ?? unmatched[i].fileName,
                ))
            .toList(),
      );
    }).toList();
  }

  /// Flattens groups back to a per-file titles list aligned to [widget.unmatched].
  List<String> _buildTitlesList() {
    final result = List<String>.filled(widget.unmatched.length, '');
    for (final group in _groups) {
      for (int j = 0; j < group.unmatchedIndices.length; j++) {
        result[group.unmatchedIndices[j]] = group.titleFor(j);
      }
    }
    return result;
  }

  /// Expands a group: seeds each per-file controller from the current shared
  /// value so the user only needs to edit the files that differ.
  void _expandGroup(int gi) {
    final group = _groups[gi];
    final sharedValue = group.sharedController.text;
    for (final c in group.perFileControllers) {
      c.text = sharedValue;
    }
    setState(() => group.expanded = true);
  }

  void _submit() => Navigator.pop(
        context,
        (titles: _buildTitlesList(), source: _source),
      );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final fileCount = widget.unmatched.length;
    final groupCount = _groups.length;

    final providerItems = <DropdownMenuItem<String>>[
      if (settings.tmdbApiKey.isNotEmpty)
        const DropdownMenuItem(value: 'tmdb', child: Text('TMDB')),
      if (settings.omdbApiKey.isNotEmpty)
        const DropdownMenuItem(value: 'omdb', child: Text('OMDb')),
      if (settings.anidbClientId.isNotEmpty)
        const DropdownMenuItem(value: 'anidb', child: Text('AniDB')),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_download_outlined,
                          color: settings.accentColor, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Search All Metadata',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Provider picker + summary
                  Row(
                    children: [
                      if (providerItems.isNotEmpty) ...[
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _source,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down,
                                size: 20),
                            items: providerItems,
                            onChanged: (v) {
                              if (v != null) setState(() => _source = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        groupCount < fileCount
                            ? '$groupCount group${groupCount == 1 ? '' : 's'} · $fileCount file${fileCount == 1 ? '' : 's'}'
                            : '$fileCount file${fileCount == 1 ? '' : 's'}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(160),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ── Groups list ──────────────────────────────────────────────────
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                shrinkWrap: true,
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, gi) =>
                    _buildGroupTile(context, gi, settings),
              ),
            ),
            // ── Footer ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: settings.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(
                        'Search $fileCount file${fileCount == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(
      BuildContext context, int gi, SettingsService settings) {
    final group = _groups[gi];
    final isMulti = group.unmatchedIndices.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withAlpha(120),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shared title row
          Row(
            children: [
              Icon(
                Icons.movie_outlined,
                size: 15,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(120),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: group.sharedController,
                  enabled: !group.expanded,
                  style: Theme.of(context).textTheme.bodySmall,
                  decoration: _inputDecoration(
                    context,
                    settings,
                    hint: widget
                        .unmatched[group.unmatchedIndices.first].fileName,
                  ),
                ),
              ),
              if (isMulti) ...[
                const SizedBox(width: 8),
                _FileBadge(
                  count: group.unmatchedIndices.length,
                  accentColor: settings.accentColor,
                ),
                IconButton(
                  icon: Icon(
                    group.expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                  ),
                  onPressed: () => group.expanded
                      ? setState(() => group.expanded = false)
                      : _expandGroup(gi),
                  tooltip: group.expanded
                      ? 'Use shared title'
                      : 'Edit individually',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          // Per-file overrides (visible only when expanded)
          if (isMulti && group.expanded)
            ...List.generate(group.unmatchedIndices.length, (j) {
              final fileIdx = group.unmatchedIndices[j];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(100),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: group.perFileControllers[j],
                        style: Theme.of(context).textTheme.bodySmall,
                        decoration: _inputDecoration(
                          context,
                          settings,
                          hint: widget.unmatched[fileIdx].fileName,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    SettingsService settings, {
    required String hint,
  }) =>
      InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: settings.accentColor, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(60),
          ),
        ),
      );
}

/// Small accent-coloured badge showing the number of files in a group.
class _FileBadge extends StatelessWidget {
  final int count;
  final Color accentColor;

  const _FileBadge({required this.count, required this.accentColor});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withAlpha(80)),
        ),
        child: Text(
          '$count files',
          style: TextStyle(
            fontSize: 11,
            color: accentColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

// ─── Season Cover Dialog ──────────────────────────────────────────────────────

/// Mutable data holder for one series+season group inside [_SeasonCoverDialog].
class _SeasonGroup {
  final String seriesTitle;
  final int? season;
  int? tmdbId; // non-final — may be filled in from any file in the group
  final List<int> fileIndices;
  final Uint8List? currentCoverBytes;
  final String? currentPosterUrl;
  Uint8List? pendingCoverBytes; // null = no change chosen yet
  bool isLoadingAuto = false;

  _SeasonGroup({
    required this.seriesTitle,
    required this.season,
    required this.tmdbId,
    required this.fileIndices,
    this.currentCoverBytes,
    this.currentPosterUrl,
  });
}

class _SeasonCoverDialog extends StatefulWidget {
  final List<_SeasonGroup> groups;
  final void Function(List<_SeasonGroup>) onApply;

  const _SeasonCoverDialog({
    required this.groups,
    required this.onApply,
  });

  @override
  State<_SeasonCoverDialog> createState() => _SeasonCoverDialogState();
}

class _SeasonCoverDialogState extends State<_SeasonCoverDialog> {
  late List<_SeasonGroup> _groups;

  @override
  void initState() {
    super.initState();
    _groups = widget.groups;
  }

  /// Fetches the season-specific (or show-level fallback) poster from TMDB
  /// and stores the downloaded bytes as [group.pendingCoverBytes].
  Future<void> _fetchAutocover(int gi) async {
    final group = _groups[gi];
    final settings = context.read<SettingsService>();
    if (settings.tmdbApiKey.isEmpty) return;

    setState(() => group.isLoadingAuto = true);

    try {
      final tmdb = TmdbService(settings.tmdbApiKey);

      // Resolve tvId — prefer stored tmdbId, fall back to searching by title
      int? tvId = group.tmdbId;
      if (tvId == null) {
        final result = await tmdb.searchTV(group.seriesTitle);
        tvId = result?['id'] as int?;
        if (tvId != null && mounted) group.tmdbId = tvId;
      }

      if (tvId == null) {
        if (mounted) setState(() => group.isLoadingAuto = false);
        return;
      }

      // Season-specific poster first, fall back to show-level poster
      String? posterUrl;
      if (group.season != null) {
        posterUrl = await tmdb.getSeasonPosterUrl(tvId, group.season!);
      }
      posterUrl ??= (await tmdb.getTVPosters(tvId)).firstOrNull;

      if (posterUrl != null && posterUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(posterUrl));
        if (response.statusCode == 200 &&
            response.bodyBytes.isNotEmpty &&
            mounted) {
          setState(() {
            group.pendingCoverBytes = response.bodyBytes;
            group.isLoadingAuto = false;
          });
          return;
        }
      }

      if (mounted) setState(() => group.isLoadingAuto = false);
    } catch (e) {
      debugPrint('Season cover auto-fetch failed: $e');
      if (mounted) setState(() => group.isLoadingAuto = false);
    }
  }

  /// Opens [CoverPickerModal] so the user can search and pick a poster manually.
  void _openCoverPicker(int gi) {
    final group = _groups[gi];
    showDialog(
      context: context,
      builder: (_) => CoverPickerModal(
        posterUrls: const [],
        initialSearchQuery: group.seriesTitle,
        isMovie: false,
        season: group.season,
        onSelected: (url) async {
          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200 && mounted) {
              setState(() => group.pendingCoverBytes = response.bodyBytes);
            }
          } catch (e) {
            debugPrint('Season cover download failed: $e');
          }
        },
      ),
    );
  }

  Future<void> _pickCustomImage(int gi) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes != null && mounted) {
      setState(() => _groups[gi].pendingCoverBytes = bytes);
    }
  }

  void _apply() {
    widget.onApply(_groups);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final hasTmdb = settings.tmdbApiKey.isNotEmpty;
    final pendingCount = _groups.where((g) => g.pendingCoverBytes != null).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.photo_album_outlined,
                      color: settings.accentColor, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Season Covers',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Set cover art per season — applies to all matching episodes',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(140),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Group rows
            Flexible(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shrinkWrap: true,
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, gi) =>
                    _buildGroupRow(context, gi, settings, hasTmdb),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: pendingCount > 0 ? _apply : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: settings.accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          settings.accentColor.withAlpha(60),
                      disabledForegroundColor: Colors.white.withAlpha(120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      pendingCount > 0
                          ? 'Apply to $pendingCount group${pendingCount == 1 ? '' : 's'}'
                          : 'Apply',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupRow(
      BuildContext context, int gi, SettingsService settings, bool hasTmdb) {
    final group = _groups[gi];
    final seasonLabel =
        group.season != null ? 'Season ${group.season}' : 'Unknown Season';
    final hasNewCover = group.pendingCoverBytes != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasNewCover
              ? settings.accentColor.withAlpha(140)
              : Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // Cover thumbnail — 2:3 aspect ratio
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 36,
              height: 54,
              child: _buildCoverThumb(group, settings),
            ),
          ),
          const SizedBox(width: 12),
          // Series title + season label + file badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.seriesTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      seasonLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(140),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _FileBadge(
                      count: group.fileIndices.length,
                      accentColor: settings.accentColor,
                    ),
                    if (hasNewCover) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle,
                          size: 14, color: settings.accentColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Auto button (TMDB only)
          if (hasTmdb)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: group.season != null
                    ? 'Fetch Season ${group.season} poster from TMDB'
                    : 'Fetch show poster from TMDB',
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: group.isLoadingAuto ? null : () => _fetchAutocover(gi),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: group.isLoadingAuto
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: settings.accentColor,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(180)),
                                const SizedBox(width: 4),
                                Text(
                                  'Auto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(180),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          // Custom file button
          Tooltip(
            message: 'Choose image file',
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => _pickCustomImage(gi),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Icon(Icons.folder_open,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(180)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Search button
          Tooltip(
            message: 'Search for cover art',
            child: Material(
              color: settings.accentColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => _openCoverPicker(gi),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Icon(Icons.search,
                      size: 16, color: settings.accentColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverThumb(_SeasonGroup group, SettingsService settings) {
    final bytes = group.pendingCoverBytes ?? group.currentCoverBytes;
    if (bytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(bytes, fit: BoxFit.cover),
          // Small checkmark overlay when a new cover has been chosen
          if (group.pendingCoverBytes != null)
            Positioned(
              right: 2,
              bottom: 2,
              child: Icon(Icons.check_circle,
                  size: 10, color: settings.accentColor),
            ),
        ],
      );
    }
    if (group.currentPosterUrl != null &&
        group.currentPosterUrl!.startsWith('http')) {
      return Image.network(
        group.currentPosterUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
      );
    }
    return _thumbPlaceholder();
  }

  Widget _thumbPlaceholder() => Container(
        color: Colors.grey.withAlpha(40),
        child: const Icon(Icons.tv, size: 16, color: Colors.grey),
      );
}
