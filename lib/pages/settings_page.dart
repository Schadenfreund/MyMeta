import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../widgets/accent_color_picker.dart';
import '../widgets/about_card.dart';
import '../widgets/tool_paths_card.dart';
import '../widgets/app_card.dart';
import '../widgets/update_check_card.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // Refresh tool status when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsService>().checkToolAvailability();
    });
  }

  Future<void> _openPayPal(BuildContext context) async {
    final Uri url = Uri.parse('https://www.paypal.com/paypalme/ivburic');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          'Could not open PayPal. Visit: paypal.me/ivburic',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: ListView(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppDimensions.tabBarHeight + AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        children: [
          AppCard(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            description: 'Personalize your interface',
            accentColor: settings.accentColor,
            children: [
              // Current Color Display
              Row(
                children: [
                  // Color Preview Circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: settings.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: settings.accentColor.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Color Name and Hex
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AccentColorPicker.nameOf(settings.accentColor),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#${settings.accentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Color Picker
              const AccentColorPicker(),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Metadata Source Card
          AppCard(
            title: 'Metadata Source',
            icon: Icons.cloud_outlined,
            description: 'Choose where to fetch metadata from',
            accentColor: settings.accentColor,
            children: [
              AppLabeledInput(
                label: 'TMDB API Key',
                description: 'Get your key from themoviedb.org',
                input: _ApiKeyInput(
                  value: settings.tmdbApiKey,
                  onChanged: settings.setTmdbApiKey,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppLabeledInput(
                label: 'OMDb API Key',
                description: 'Get your key from omdbapi.com',
                input: _ApiKeyInput(
                  value: settings.omdbApiKey,
                  onChanged: settings.setOmdbApiKey,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppLabeledInput(
                label: 'AniDB Client ID',
                description: 'Register your client at wiki.anidb.net/API',
                input: _ApiKeyInput(
                  value: settings.anidbClientId,
                  onChanged: settings.setAnidbClientId,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSettingRow(
                title: 'Season Poster',
                description: 'Use season-specific poster for TV episodes (TMDB only). Falls back to show poster if unavailable.',
                control: Switch(
                  value: settings.useSeasonPoster,
                  onChanged: settings.setUseSeasonPoster,
                  activeColor: settings.accentColor,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSettingRow(
                title: 'Remove All Covers Before Embed',
                description: 'MKV only. When enabled, all image attachments (any name, image/jpeg or image/png) are removed before the new cover is added. When disabled, only attachments whose filename contains "cover" are removed. Has no effect when "Update Cover" is turned off.',
                control: Switch(
                  value: settings.removeAllCoversBeforeEmbed,
                  onChanged: settings.setRemoveAllCoversBeforeEmbed,
                  activeColor: settings.accentColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Tool Paths Card (Collapsible)
          ToolPathsCard(
            ffmpegPath: settings.ffmpegPath,
            mkvpropeditPath: settings.mkvpropeditPath,
            atomicparsleyPath: settings.atomicparsleyPath,
            onFFmpegPathChanged: settings.setFFmpegPath,
            onMkvpropeditPathChanged: settings.setMkvpropeditPath,
            onAtomicparsleyPathChanged: settings.setAtomicParsleyPath,
            ffmpegAvailable: settings.isFFmpegAvailable,
            mkvpropeditAvailable: settings.isMkvpropeditAvailable,
            atomicparsleyAvailable: settings.isAtomicParsleyAvailable,
            checkingTools: settings.isCheckingTools,
            onRefresh: settings.checkToolAvailability,
          ),

          const SizedBox(height: AppSpacing.md),

          // Update Check Card
          const UpdateCheckCard(),

          const SizedBox(height: AppSpacing.md),

          // About Card
          const AboutCard(),

          const SizedBox(height: AppSpacing.lg),

          // Made with ❤️ message and Support button
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Made with ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                    ),
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: settings.accentColor,
                    ),
                    Text(
                      ' for you to enjoy. Please consider supporting the development.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => _openPayPal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: settings.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Support',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ApiKeyInput extends StatefulWidget {
  final String value;
  final Function(String) onChanged;

  const _ApiKeyInput({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ApiKeyInput> createState() => _ApiKeyInputState();
}

class _ApiKeyInputState extends State<_ApiKeyInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ApiKeyInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        hintText: 'Enter API key',
        isDense: true,
      ),
      onChanged: widget.onChanged,
      obscureText: true,
    );
  }
}
