import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../widgets/app_card.dart';
import '../theme/app_theme.dart';

class FormatsPage extends StatefulWidget {
  const FormatsPage({super.key});

  @override
  State<FormatsPage> createState() => _FormatsPageState();
}

class _FormatsPageState extends State<FormatsPage> {
  late TextEditingController _seriesController;
  late TextEditingController _movieController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _seriesController = TextEditingController(text: settings.seriesFormat);
    _movieController = TextEditingController(text: settings.movieFormat);

    // Auto-save on text change and trigger rebuild for preview
    _seriesController.addListener(() {
      settings.setSeriesFormat(_seriesController.text);
      setState(() {}); // Trigger rebuild to update preview
    });
    _movieController.addListener(() {
      settings.setMovieFormat(_movieController.text);
      setState(() {}); // Trigger rebuild to update preview
    });
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _movieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppDimensions.tabBarHeight + AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        children: [
          // Series Format Card
          _buildFormatCard(
            context,
            title: 'TV Series Format',
            icon: Icons.tv_outlined,
            description: 'How TV show episodes should be named',
            controller: _seriesController,
            onReset: () {
              const defaultFormat =
                  '{series_name} - S{season_number}E{episode_number} - {episode_title}';
              _seriesController.text = defaultFormat;
            },
            tokens: const [
              TokenInfo('{series_name}', 'Name of the TV series'),
              TokenInfo('{season_number}', 'Season number (01, 02, etc.)'),
              TokenInfo('{episode_number}', 'Episode number (01, 02, etc.)'),
              TokenInfo('{episode_title}', 'Title of the episode'),
              TokenInfo('{year}', 'Release year'),
            ],
          ),

          const SizedBox(height: 16),

          // Movie Format Card
          _buildFormatCard(
            context,
            title: 'Movie Format',
            icon: Icons.movie_outlined,
            description: 'How movies should be named',
            controller: _movieController,
            onReset: () {
              const defaultFormat = '{movie_name}';
              _movieController.text = defaultFormat;
            },
            tokens: const [
              TokenInfo('{movie_name}', 'Title of the movie'),
              TokenInfo('{year}', 'Release year'),
            ],
          ),

          const SizedBox(height: 24),

          // Help Section
          _buildHelpCard(context),
        ],
      ),
    );
  }

  Widget _buildFormatCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
    required TextEditingController controller,
    required VoidCallback onReset,
    required List<TokenInfo> tokens,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return AppCard(
      title: title,
      icon: icon,
      description: description,
      accentColor: accentColor,
      children: [
        // Format Input with inline Reset button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Format Pattern',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Enter naming format...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Reset button (accent colored, icon only)
            Padding(
              padding: const EdgeInsets.only(top: 28), // Align with TextField
              child: Tooltip(
                message: 'Reset to Default',
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onReset,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.refresh,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Available Tokens
        Text(
          'Available Tokens',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tokens.map((token) {
            return Tooltip(
              message: token.description,
              child: InkWell(
                onTap: () {
                  final text = controller.text;
                  final selection = controller.selection;
                  final newText = text.substring(0, selection.start) +
                      token.token +
                      text.substring(selection.end);
                  controller.text = newText;
                  controller.selection = TextSelection.collapsed(
                    offset: selection.start + token.token.length,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    token.token,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Dynamic Preview
        Text(
          'Preview',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.visibility,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _generatePreview(controller.text, tokens),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpCard(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCardHeader(
            icon: Icons.info_outline,
            title: 'Formatting Tips',
            accentColor: accentColor,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTip('Click on any token to insert it at cursor position'),
          _buildTip(
              'Use standard characters like dashes, spaces, and parentheses'),
          _buildTip('Changes apply to newly renamed files'),
          _buildTip(
              'Test your format with a few files before batch processing'),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _generatePreview(String pattern, List<TokenInfo> tokens) {
    // Sample data from The Simpsons S6E12 - Homer the Great
    final sampleData = {
      '{series_name}': 'The Simpsons',
      '{season_number}': '06',
      '{episode_number}': '12',
      '{episode_title}': 'Homer the Great',
      '{year}': '1995',
      '{movie_name}': 'The Usual Suspects',
    };

    String preview = pattern;
    // Replace tokens with sample data
    sampleData.forEach((token, value) {
      preview = preview.replaceAll(token, value);
    });

    return preview.isEmpty ? 'Enter a format pattern to see preview' : preview;
  }
}

class TokenInfo {
  final String token;
  final String description;

  const TokenInfo(this.token, this.description);
}
