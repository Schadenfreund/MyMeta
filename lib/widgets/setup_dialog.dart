import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tool_downloader_service.dart';
import '../services/settings_service.dart';

/// Dialog for setting up third-party tools (FFmpeg, MKVToolNix, AtomicParsley)
class SetupDialog extends StatefulWidget {
  const SetupDialog({super.key});

  @override
  State<SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<SetupDialog> {
  Map<String, bool> _toolsStatus = {};
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadStatus = {};
  Map<String, bool> _isDownloading = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToolsStatus();
  }

  Future<void> _loadToolsStatus() async {
    setState(() => _isLoading = true);
    final status = await ToolDownloaderService.getToolsStatus();
    setState(() {
      _toolsStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _downloadTool(String toolName) async {
    setState(() {
      _isDownloading[toolName] = true;
      _downloadProgress[toolName] = 0.0;
      _downloadStatus[toolName] = 'Starting...';
    });

    try {
      await ToolDownloaderService.downloadTool(
        toolName,
        progressCallback: (downloaded, total, status) {
          setState(() {
            _downloadProgress[toolName] = total > 0 ? downloaded / total : 0.0;
            _downloadStatus[toolName] = status;
          });
        },
      );

      // Update settings to use the downloaded tool
      if (mounted) {
        final settings = Provider.of<SettingsService>(context, listen: false);
        final toolPath = await ToolDownloaderService.getToolPath(toolName);

        if (toolPath != null) {
          switch (toolName.toLowerCase()) {
            case 'ffmpeg':
              await settings.setFFmpegPath(toolPath);
              break;
            case 'mkvpropedit':
              await settings.setMkvpropeditPath(toolPath);
              break;
            case 'atomicparsley':
              await settings.setAtomicParsleyPath(toolPath);
              break;
          }
        }
      }

      await _loadToolsStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download $toolName: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading[toolName] = false;
        _downloadProgress.remove(toolName);
        _downloadStatus.remove(toolName);
      });
    }
  }

  Future<void> _deleteTool(String toolName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tool'),
        content: Text('Are you sure you want to delete $toolName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ToolDownloaderService.deleteTool(toolName);
      await _loadToolsStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.build_circle,
                      color: colorScheme.primary, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup Third-Party Tools',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Download and configure required tools for metadata processing',
                          style: theme.textTheme.bodySmall,
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

            // Content
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildToolCard(
                          'FFmpeg',
                          'ffmpeg',
                          'Required for video processing and metadata embedding',
                          '~80 MB',
                        ),
                        const SizedBox(height: 16),
                        _buildToolCard(
                          'MKVToolNix',
                          'mkvpropedit',
                          'Optional - 60-120x faster MKV metadata embedding',
                          '~30 MB (Manual install required)',
                          optional: true,
                        ),
                        const SizedBox(height: 16),
                        _buildToolCard(
                          'AtomicParsley',
                          'atomicparsley',
                          'Optional - 10-20x faster MP4 metadata embedding',
                          '~2 MB',
                          optional: true,
                        ),
                      ],
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(
    String displayName,
    String toolName,
    String description,
    String size, {
    bool optional = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInstalled = _toolsStatus[toolName] ?? false;
    final isDownloading = _isDownloading[toolName] ?? false;
    final progress = _downloadProgress[toolName] ?? 0.0;
    final status = _downloadStatus[toolName] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInstalled ? Icons.check_circle : Icons.download,
                color: isInstalled ? colorScheme.primary : theme.hintColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (optional) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.hintColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Optional',
                              style: theme.textTheme.bodySmall!.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isInstalled)
                ElevatedButton.icon(
                  onPressed: isDownloading ? null : () => _deleteTool(toolName),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                  ),
                )
              else if (toolName == 'mkvpropedit')
                OutlinedButton.icon(
                  onPressed: () {
                    // Show manual installation instructions
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Manual Installation Required'),
                        content: const Text(
                          'MKVToolNix requires manual installation.\n\n'
                          '1. Visit mkvtoolnix.download\n'
                          '2. Download the Windows installer\n'
                          '3. Install to the default location\n'
                          '4. Restart MyMeta\n\n'
                          'MyMeta will automatically detect the installation.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Manual Install'),
                )
              else
                ElevatedButton.icon(
                  onPressed:
                      isDownloading ? null : () => _downloadTool(toolName),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.dividerColor.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (isInstalled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FutureBuilder<String?>(
                    future: ToolDownloaderService.getToolPath(toolName),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          snapshot.data!,
                          style: theme.textTheme.bodySmall!.copyWith(
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Size: $size',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
