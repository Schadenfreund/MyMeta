import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../widgets/accent_color_picker.dart';
import '../widgets/about_card.dart';
import '../widgets/tool_paths_card.dart';
import '../widgets/app_card.dart';
import '../theme/app_theme.dart';

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

  String _getColorName(Color color) {
    // Map color values to their names
    const colorMap = {
      0xFF6366F1: 'Indigo',
      0xFF3B82F6: 'Blue',
      0xFF8B5CF6: 'Purple',
      0xFFBE0AB4: 'Pink',
      0xFFEF4444: 'Red',
      0xFFF97316: 'Orange',
      0xFF10B981: 'Green',
      0xFF14B8A6: 'Teal',
    };
    return colorMap[color.value] ?? 'Custom';
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
                          _getColorName(settings.accentColor),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#${settings.accentColor.value.toRadixString(16).substring(2).toUpperCase()}',
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
              AppSettingRow(
                title: 'Preferred Provider',
                description: 'Select metadata provider',
                control: DropdownButton<String>(
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
