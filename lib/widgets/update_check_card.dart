import 'package:flutter/material.dart';
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

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
    });

    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdates();

    setState(() {
      _checking = false;
    });

    if (!mounted) return;

    if (updateInfo != null) {
      // Show update available dialog
      _showUpdateDialog(updateInfo);
    } else {
      // Already latest
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ You are running the latest version'),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  updateInfo.releaseNotes,
                  style: Theme.of(context).textTheme.bodySmall,
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
      builder: (context) => _UpdateProgressDialog(updateInfo: updateInfo),
    );
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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

          const SizedBox(height: AppSpacing.sm),

          // View releases link
          TextButton.icon(
            onPressed: () async {
              final url = Uri.parse(
                  'https://github.com/${UpdateService.repoOwner}/${UpdateService.repoName}/releases');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View All Releases on GitHub'),
            style: TextButton.styleFrom(
              foregroundColor: settings.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog shown during update download and installation
class _UpdateProgressDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _UpdateProgressDialog({required this.updateInfo});

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  double _progress = 0.0;
  String _status = 'Initializing...';
  bool _completed = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _performUpdate();
  }

  Future<void> _performUpdate() async {
    final updateService = UpdateService();

    final success = await updateService.downloadAndInstall(
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_completed
          ? (_error ? 'Update Failed' : 'Update Complete')
          : 'Updating MyMeta'),
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
              'Failed to install update. Please try again or download manually from GitHub.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Update installed successfully! Please restart MyMeta to use the new version.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (_completed)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_error ? 'Close' : 'Restart Later'),
          ),
      ],
    );
  }
}
