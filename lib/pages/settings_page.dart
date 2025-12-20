import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import '../widgets/accent_color_picker.dart';
import '../widgets/about_card.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Header
          Text(
            'Settings',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Customize your experience',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Appearance Card
          _buildCard(
            context,
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accent Color',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose your preferred accent color',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const AccentColorPicker(),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Metadata Source Card
          _buildCard(
            context,
            title: 'Metadata Source',
            icon: Icons.cloud_outlined,
            children: [
              _buildSettingRow(
                context,
                'Preferred Provider',
                'Choose where to fetch metadata from',
                DropdownButton<String>(
                  value: settings.metadataSource,
                  underline: const SizedBox(),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.inputBorderRadius),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      settings.setMetadataSource(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'tmdb',
                      child: Text('The Movie Database (TMDB)'),
                    ),
                    DropdownMenuItem(
                      value: 'omdb',
                      child: Text('OMDb (IMDb Data)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildAPIKeyInput(
                context,
                'TMDB API Key',
                'Get your key from themoviedb.org',
                settings.tmdbApiKey,
                settings.setTmdbApiKey,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildAPIKeyInput(
                context,
                'OMDb API Key',
                'Get your key from omdbapi.com',
                settings.omdbApiKey,
                settings.setOmdbApiKey,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // FFmpeg Configuration Card
          _buildCard(
            context,
            title: 'FFmpeg Configuration',
            icon: Icons.settings_applications_outlined,
            children: [
              Text(
                'Required for reading and writing metadata from video files',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),

              // FFmpeg Folder Path
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'FFmpeg Folder',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightHover,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.inputBorderRadius),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            settings.ffmpegPath.isEmpty
                                ? 'Not configured - will search in system PATH'
                                : settings.ffmpegPath,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      color: settings.ffmpegPath.isEmpty
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
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      OutlinedButton.icon(
                        onPressed: () async {
                          String? selectedDirectory =
                              await FilePicker.platform.getDirectoryPath(
                            dialogTitle:
                                'Select FFmpeg Folder (contains bin/ffmpeg.exe)',
                          );
                          if (selectedDirectory != null) {
                            settings.setFFmpegPath(selectedDirectory);
                          }
                        },
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Browse'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      if (settings.ffmpegPath.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Clear',
                          onPressed: () => settings.setFFmpegPath(''),
                          color: AppColors.lightDanger,
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Help Text with Accent Color
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: settings.accentColor.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.inputBorderRadius),
                  border: Border.all(
                    color: settings.accentColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: settings.accentColor,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How to set up FFmpeg',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: settings.accentColor,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1. Download FFmpeg from ffmpeg.org or github.com/BtbN/FFmpeg-Builds/releases',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                    ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '2. Extract the ZIP file to a folder (e.g., C:\\FFmpeg)',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                    ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '3. Click Browse and select that folder',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                    ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The folder should contain bin/ffmpeg.exe and bin/ffprobe.exe',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.lightTextTertiary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // About Card
          const AboutCard(),

          const SizedBox(height: AppSpacing.lg),

          // Reset Button
          Center(
            child: TextButton.icon(
              onPressed: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Settings'),
                    content: const Text(
                      'This will reset all settings to default values. Continue?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightDanger,
                        ),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await settings.resetSettings();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset All Settings'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lightDanger,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardShadow =
        isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow;

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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context,
    String title,
    String description,
    Widget control,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        control,
      ],
    );
  }

  Widget _buildAPIKeyInput(
    BuildContext context,
    String label,
    String hint,
    String value,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
          ),
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          obscureText: true,
        ),
      ],
    );
  }
}
