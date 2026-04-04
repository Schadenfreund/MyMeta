import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// Card for checking and installing app updates from GitHub
class UpdateCheckCard extends StatefulWidget {
  const UpdateCheckCard({super.key});

  @override
  State<UpdateCheckCard> createState() => _UpdateCheckCardState();
}

class _UpdateCheckCardState extends State<UpdateCheckCard> {
  bool _checking = false;
  PendingUpdate? _pendingUpdate;
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _checkPendingUpdate();
  }

  Future<void> _checkPendingUpdate() async {
    final pending = await _updateService.checkPendingUpdate();
    if (mounted) {
      setState(() => _pendingUpdate = pending);
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);

    final updateInfo = await _updateService.checkForUpdates();

    setState(() => _checking = false);

    if (!mounted) return;

    if (updateInfo != null) {
      _showUpdateDialog(updateInfo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are running the latest version'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    final settings = context.read<SettingsService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: settings.accentColor),
            const SizedBox(width: 12),
            const Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MyMeta v${updateInfo.version} is available!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Release Notes:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: updateInfo.releaseNotes,
                  styleSheet: MarkdownStyleSheet.fromTheme(
                    Theme.of(context),
                  ).copyWith(
                    p: Theme.of(context).textTheme.bodySmall,
                    h3: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    listBullet: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(updateInfo);
            },
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _startUpdate(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateProgressDialog(
        updateInfo: updateInfo,
        updateService: _updateService,
        onCompleted: () {
          // Refresh pending update state when download completes
          _checkPendingUpdate();
        },
      ),
    );
  }

  Future<void> _restartToUpdate() async {
    final error = await _updateService.launchUpdateScript();
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }
    exit(0);
  }

  Future<void> _dismissPendingUpdate() async {
    await _updateService.cleanupPendingUpdate();
    if (mounted) {
      setState(() => _pendingUpdate = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsService>();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.system_update_outlined,
                color: settings.accentColor,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Software Updates',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Description
          Text(
            'Check for updates from GitHub Releases. Your settings and tools are preserved during updates.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Pending update banner
          if (_pendingUpdate != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: settings.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: settings.accentColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.download_done, color: settings.accentColor),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'v${_pendingUpdate!.version} is ready to install',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _dismissPendingUpdate,
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _restartToUpdate,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart Now to Update'),
                style: FilledButton.styleFrom(
                  backgroundColor: settings.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            // Check for Updates Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _checking ? null : _checkForUpdates,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download),
                label: Text(_checking ? 'Checking...' : 'Check for Updates'),
                style: FilledButton.styleFrom(
                  backgroundColor: settings.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // View releases link
          TextButton.icon(
            onPressed: () async {
              final url = Uri.parse(UpdateService.releasesUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View All Releases on GitHub'),
            style: TextButton.styleFrom(foregroundColor: settings.accentColor),
          ),
        ],
      ),
    );
  }
}

/// Dialog shown during update download and installation
class _UpdateProgressDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;
  final VoidCallback onCompleted;

  const _UpdateProgressDialog({
    required this.updateInfo,
    required this.updateService,
    required this.onCompleted,
  });

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  double _progress = 0.0;
  String _status = 'Initializing...';
  bool _completed = false;
  bool _error = false;
  String? _launchError;

  @override
  void initState() {
    super.initState();
    _performUpdate();
  }

  Future<void> _performUpdate() async {
    final success = await widget.updateService.downloadAndInstall(
      widget.updateInfo,
      (progress, status) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _status = status;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _completed = true;
        _error = !success;
      });
      if (success) {
        widget.onCompleted();
      }
    }
  }

  Future<void> _executeUpdateAndExit() async {
    final error = await widget.updateService.launchUpdateScript();
    if (error != null) {
      if (mounted) {
        setState(() => _launchError = error);
      }
      return;
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _completed
            ? (_error ? 'Update Failed' : 'Update Ready')
            : 'Updating MyMeta',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_completed) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            Text(_status),
          ] else if (_error) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to download update. Please try again or download manually from GitHub.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Update downloaded successfully!\nRestart now or later from the Settings page.',
              textAlign: TextAlign.center,
            ),
            if (_launchError != null) ...[
              const SizedBox(height: 8),
              Text(
                _launchError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
      actions: [
        if (_completed && !_error) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_launchError != null ? 'Close' : 'Restart Later'),
          ),
          if (_launchError != null)
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(UpdateService.latestReleaseUrl)),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open GitHub'),
            )
          else
            FilledButton.icon(
              onPressed: _executeUpdateAndExit,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restart Now'),
            ),
        ] else if (_completed && _error) ...[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ],
    );
  }
}
