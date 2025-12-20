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

  Future<void> _pickFiles(BuildContext context) async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      List<XFile> xFiles = result.paths.map((path) => XFile(path!)).toList();
      final fileState = context.read<FileStateService>();
      final settings = context.read<SettingsService>();
      await fileState.addFiles(xFiles, settings: settings);

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

          // Show additional warning if FFmpeg is missing
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
              top: AppSpacing.md,
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
                // Clear All Button
                _buildMinimalIconButton(
                  context,
                  icon: Icons.delete_outline,
                  tooltip: 'Clear All',
                  onPressed: () {
                    setState(() => _expandedIndex = null);
                    fileState.clearAll();
                  },
                  isDark: isDark,
                  isDestructive: true,
                ),

                // Rename All Button - only if there are files to rename
                if (canRename) ...[
                  const SizedBox(width: 8),
                  _buildMinimalIconButton(
                    context,
                    icon: Icons.drive_file_rename_outline,
                    tooltip: 'Rename All',
                    onPressed: () {
                      setState(() => _expandedIndex = null);
                      final settings = context.read<SettingsService>();
                      fileState.renameFiles(settings: settings);
                    },
                    isDark: isDark,
                    isPrimary: true,
                    accentColor: settings.accentColor,
                  ),
                ],
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
  }) {
    final Color buttonColor = isPrimary
        ? (accentColor ?? Theme.of(context).colorScheme.primary)
        : (isDestructive
            ? AppColors.lightDanger
            : (isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary));

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
              color: isPrimary ? Colors.white : buttonColor,
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
                children: [
                  // Expand Icon
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: isRenamed
                        ? AppColors.lightSuccess
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Status Indicator (compact circular) - always show status
                  Builder(
                    builder: (context) {
                      final hasMetadata = output != null &&
                          output.title != null &&
                          output.title!.isNotEmpty;

                      IconData statusIcon;
                      Color statusColor;
                      String statusTooltip;

                      if (isRenamed) {
                        statusIcon = Icons.check;
                        statusColor = AppColors.lightSuccess;
                        statusTooltip = 'Renamed successfully';
                      } else if (hasMetadata) {
                        statusIcon = Icons.cloud_done_outlined;
                        statusColor = Theme.of(context).colorScheme.primary;
                        statusTooltip =
                            'Metadata ready - click Rename to apply';
                      } else {
                        statusIcon = Icons.warning_amber_rounded;
                        statusColor = Colors.orange;
                        statusTooltip =
                            'No metadata - click cloud icon to search';
                      }

                      return Tooltip(
                        message: statusTooltip,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(38),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),

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

                  // File Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          input.fileName,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isRenamed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isRenamed
                                        ? (isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary)
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

                  // Arrow Icon / Status
                  Icon(
                    isRenamed ? Icons.check_circle : Icons.arrow_forward,
                    color: isRenamed
                        ? AppColors.lightSuccess
                        : (isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Output Name
                  Expanded(
                    child: Text(
                      isRenamed
                          ? p.basename(input.renamedPath!)
                          : (output?.newName ?? "Pending..."),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isRenamed
                                ? AppColors.lightSuccess
                                : Theme.of(context).colorScheme.primary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Search Online Button
                  if (!isRenamed)
                    IconButton(
                      icon: const Icon(Icons.cloud_download_outlined, size: 20),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () async {
                        final settings = context.read<SettingsService>();

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

                        SnackbarHelper.showInfo(
                          context,
                          'Searching for "${input.fileName}"...',
                        );

                        await fileState.matchSingleFile(index, settings);

                        if (context.mounted) {
                          final result = fileState.matchResults.length > index
                              ? fileState.matchResults[index]
                              : null;
                          if (result != null &&
                              result.title != null &&
                              result.title!.isNotEmpty) {
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
                      },
                      tooltip: "Search online metadata",
                    ),

                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    onPressed: () {
                      if (isExpanded) _toggleExpanded(index);
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
              onRename: (MatchResult result) async {
                // Update the match result first
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
}
