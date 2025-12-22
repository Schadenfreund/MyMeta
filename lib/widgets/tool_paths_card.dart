import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import '../services/settings_service.dart';
import '../services/tool_downloader_service.dart';
import '../theme/app_theme.dart';

/// Collapsible Tool Paths Card with integrated Quick Setup
class ToolPathsCard extends StatefulWidget {
  final String ffmpegPath;
  final String mkvpropeditPath;
  final String atomicparsleyPath;
  final Function(String) onFFmpegPathChanged;
  final Function(String) onMkvpropeditPathChanged;
  final Function(String) onAtomicparsleyPathChanged;
  final bool ffmpegAvailable;
  final bool mkvpropeditAvailable;
  final bool atomicparsleyAvailable;
  final bool checkingTools;
  final VoidCallback onRefresh;

  const ToolPathsCard({
    super.key,
    required this.ffmpegPath,
    required this.mkvpropeditPath,
    required this.atomicparsleyPath,
    required this.onFFmpegPathChanged,
    required this.onMkvpropeditPathChanged,
    required this.onAtomicparsleyPathChanged,
    required this.ffmpegAvailable,
    required this.mkvpropeditAvailable,
    required this.atomicparsleyAvailable,
    required this.checkingTools,
    required this.onRefresh,
  });

  @override
  State<ToolPathsCard> createState() => _ToolPathsCardState();
}

class _ToolPathsCardState extends State<ToolPathsCard> {
  bool _isExpanded = false;
  bool _isDownloading = false;
  bool _setupComplete = false;
  Map<String, double> _progress = {};
  Map<String, String> _status = {};
  String? _errorMessage;

  bool get _areAllToolsConfigured =>
      widget.ffmpegPath.isNotEmpty &&
      widget.mkvpropeditPath.isNotEmpty &&
      widget.atomicparsleyPath.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardShadow =
        isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow;

    // Determine header status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_areAllToolsConfigured) {
      statusColor = Colors.green;
      statusText = 'Configured';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusText = 'Setup Required';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: cardShadow,
      ),
      child: Column(
        children: [
          // Header (always visible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius:
                  BorderRadius.circular(AppDimensions.cardBorderRadius),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 24,
                      color: settings.accentColor,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Tool Paths',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Configure locations for FFmpeg, MKVToolNix, and AtomicParsley',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontSize: 13,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge (moved to the right)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 24,
                      ),
                      onPressed: () =>
                          setState(() => _isExpanded = !_isExpanded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // Quick Setup Section
                  if (!_areAllToolsConfigured ||
                      _isDownloading ||
                      _setupComplete ||
                      _errorMessage != null) ...[
                    if (_errorMessage != null)
                      _buildErrorState(context, isDark)
                    else if (_setupComplete)
                      _buildSetupComplete(context, isDark)
                    else if (_isDownloading)
                      _buildDownloadingState(context, settings.accentColor)
                    else
                      _buildQuickSetupIntro(context, settings.accentColor),
                    const SizedBox(height: AppSpacing.lg),
                    Divider(
                      height: 1,
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // FFmpeg
                  _buildToolSection(
                    context,
                    'FFmpeg',
                    widget.ffmpegPath,
                    'Select FFmpeg Folder (contains bin/ffmpeg.exe)',
                    widget.onFFmpegPathChanged,
                    true, // required
                    widget.ffmpegAvailable,
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Divider(
                    height: 1,
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // MKVToolNix
                  _buildToolSection(
                    context,
                    'MKVToolNix',
                    widget.mkvpropeditPath,
                    'Select mkvpropedit Folder (contains mkvpropedit.exe)',
                    widget.onMkvpropeditPathChanged,
                    false, // optional
                    widget.mkvpropeditAvailable,
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Divider(
                    height: 1,
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // AtomicParsley
                  _buildToolSection(
                    context,
                    'AtomicParsley',
                    widget.atomicparsleyPath,
                    'Select AtomicParsley Folder (contains AtomicParsley.exe)',
                    widget.onAtomicparsleyPathChanged,
                    false, // optional
                    widget.atomicparsleyAvailable,
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Divider(
                    height: 1,
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Download URLs - Collapsible section at bottom
                  Container(
                    decoration: BoxDecoration(
                      color: settings.accentColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(
                          AppDimensions.inputBorderRadius),
                      border: Border.all(
                        color: settings.accentColor.withOpacity(0.2),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        childrenPadding: const EdgeInsets.only(
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                          bottom: AppSpacing.md,
                        ),
                        leading: Icon(
                          Icons.link,
                          size: 20,
                          color: settings.accentColor,
                        ),
                        title: Text(
                          'Download URLs',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: settings.accentColor,
                                  ),
                        ),
                        iconColor: settings.accentColor,
                        collapsedIconColor: settings.accentColor,
                        children: [
                          // Info box
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: settings.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: settings.accentColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: settings.accentColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Click the download button to get tools manually. Extract to UserData/tools folder or use the Setup button above for automatic installation.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                          height: 1.4,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // URL inputs
                          _buildUrlInput(
                            context,
                            'FFmpeg URL',
                            settings.ffmpegUrl,
                            settings.setFFmpegUrl,
                            settings.accentColor,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildUrlInput(
                            context,
                            'MKVToolNix URL',
                            settings.mkvtoolnixUrl,
                            settings.setMkvtoolnixUrl,
                            settings.accentColor,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildUrlInput(
                            context,
                            'AtomicParsley URL',
                            settings.atomicParsleyUrl,
                            settings.setAtomicParsleyUrl,
                            settings.accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Refresh button removed as requested
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlInput(
    BuildContext context,
    String label,
    String value,
    Function(String) onChanged,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurface.withOpacity(0.3)
                    : AppColors.lightHover.withOpacity(0.5),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder.withOpacity(0.3)
                        : AppColors.lightBorder.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder.withOpacity(0.3)
                        : AppColors.lightBorder.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: accentColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
          // Download icon button with accent color
          Tooltip(
            message: 'Download from $label',
            child: Container(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final url = Uri.parse(value);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSetupIntro(BuildContext context, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One-Click Setup',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Automatically download and configure required tools',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _startQuickSetup,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Install Tools'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingState(BuildContext context, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Downloading & Installing Tools...',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_status.containsKey('ffmpeg'))
            _buildProgressItem('FFmpeg', 'ffmpeg', accentColor),
          if (_status.containsKey('mkvpropedit')) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildProgressItem('MKVToolNix', 'mkvpropedit', accentColor),
          ],
          if (_status.containsKey('atomicparsley')) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildProgressItem('AtomicParsley', 'atomicparsley', accentColor),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightDanger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
        border: Border.all(
          color: AppColors.lightDanger.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline,
                color: AppColors.lightDanger, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Failed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightDanger,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ?? 'Unknown error occurred.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _setupComplete = false;
              });
            },
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          )
        ],
      ),
    );
  }

  Widget _buildSetupComplete(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, color: Colors.green, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Complete!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All tools have been successfully downloaded and configured.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _setupComplete = false;
              });
            },
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          )
        ],
      ),
    );
  }

  Future<void> _startQuickSetup() async {
    final settings = context.read<SettingsService>();
    setState(() {
      _isDownloading = true;
      _setupComplete = false;
      _errorMessage = null;
      _progress.clear();
      _status.clear();
    });

    try {
      // Download FFmpeg
      await _downloadTool('ffmpeg', settings.ffmpegUrl, 'FFmpeg');
      if (mounted) {
        final path = await ToolDownloaderService.getToolPath('ffmpeg');
        if (path != null) {
          // Store the directory path, not the executable path
          widget.onFFmpegPathChanged(p.dirname(path));
        }
      }

      // Download AtomicParsley
      // Note: Doing AtomicParsley before MKVToolNix because MKV might fail
      await _downloadTool(
          'atomicparsley', settings.atomicParsleyUrl, 'AtomicParsley');
      if (mounted) {
        final path = await ToolDownloaderService.getToolPath('atomicparsley');
        if (path != null) {
          widget.onAtomicparsleyPathChanged(p.dirname(path));
        }
      }

      // Download MKVToolNix
      await _downloadTool('mkvpropedit', settings.mkvtoolnixUrl, 'MKVToolNix');
      if (mounted) {
        final path = await ToolDownloaderService.getToolPath('mkvpropedit');
        if (path != null) {
          widget.onMkvpropeditPathChanged(p.dirname(path));
        }
      }

      if (mounted) {
        setState(() {
          _setupComplete = true;
          _isDownloading = false;
          _status['complete'] = 'Setup complete!';
        });
      }

      // Refresh tool status
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        // If it's the specific mkvtoolnix 7z error which shouldn't happen anymore with the 7za integration
        // but just in case we catch generic errors
        setState(() {
          _errorMessage = 'An error occurred during setup: $e';
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _downloadTool(
      String toolName, String url, String displayName) async {
    setState(() {
      _status[toolName] = 'Starting download...';
      _progress[toolName] = 0.0;
    });

    try {
      await ToolDownloaderService.downloadTool(
        toolName,
        url,
        progressCallback: (downloaded, total, status) {
          if (mounted) {
            setState(() {
              _progress[toolName] = total > 0 ? downloaded / total : 0.0;
              _status[toolName] = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _status[toolName] = '$displayName installed ✓';
          _progress[toolName] = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status[toolName] = 'Failed: $e';
        });
      }
      rethrow;
    }
  }

  Widget _buildProgressItem(
      String displayName, String toolName, Color accentColor) {
    final progress = _progress[toolName] ?? 0.0;
    final status = _status[toolName] ?? '';

    // Check if this tool specifically failed (contains "Failed")
    final bool isFailed =
        status.contains('Failed') || status.contains('Manual required');
    final Color progressColor = isFailed ? AppColors.lightDanger : accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: progressColor.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: isFailed ? AppColors.lightDanger : null,
              ),
        ),
      ],
    );
  }

  Widget _buildToolSection(
    BuildContext context,
    String toolName,
    String path,
    String dialogTitle,
    Function(String) onPathChanged,
    bool isRequired,
    bool? isAvailable,
  ) {
    final settings = context.read<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if path is set but tool unavailable (invalid path)
    final bool isError = path.isNotEmpty && isAvailable == false;
    // Check if path is valid
    final bool isValid = path.isNotEmpty && isAvailable == true;

    Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    if (isError) borderColor = AppColors.lightDanger.withOpacity(0.5);
    if (isValid) borderColor = Colors.green.withOpacity(0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tool name with status on the right
        Row(
          children: [
            Text(
              toolName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: settings.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: settings.accentColor,
                      ),
                ),
              ),
            ],
            const Spacer(),
            // Status indicator on the right
            if (isValid) ...[
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text('Ready',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500)),
            ] else if (path.isEmpty) ...[
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: settings.accentColor),
              const SizedBox(width: 4),
              Text('Missing',
                  style: TextStyle(
                      fontSize: 12,
                      color: settings.accentColor,
                      fontWeight: FontWeight.w500)),
            ] else ...[
              Icon(Icons.error_outline, size: 16, color: AppColors.lightDanger),
              const SizedBox(width: 4),
              Text('Not Found',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.lightDanger,
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Path selector
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightHover,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.inputBorderRadius),
                  border: Border.all(
                    color: borderColor,
                    width: isError || isValid ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (isValid)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.check, size: 14, color: Colors.green),
                      ),
                    Expanded(
                      child: Text(
                        path.isEmpty ? 'Not configured' : path,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: path.isEmpty
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
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            ElevatedButton.icon(
              onPressed: () async {
                String? selectedDirectory =
                    await FilePicker.platform.getDirectoryPath(
                  dialogTitle: dialogTitle,
                );
                if (selectedDirectory != null) {
                  onPathChanged(selectedDirectory);
                }
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
              ),
            ),
            if (path.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Clear',
                onPressed: () => onPathChanged(''),
                color: AppColors.lightDanger,
                padding: const EdgeInsets.all(8),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
