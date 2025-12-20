import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

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
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _movieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Text(
            'Naming Formats',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize how files are named',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // Series Format Card
          _buildFormatCard(
            context,
            title: 'TV Series Format',
            icon: Icons.tv_outlined,
            description: 'How TV show episodes should be named',
            controller: _seriesController,
            onSave: () => settings.setSeriesFormat(_seriesController.text),
            onReset: () {
              const defaultFormat =
                  '{series_name} - S{season_number}E{episode_number} - {episode_title}';
              _seriesController.text = defaultFormat;
              settings.setSeriesFormat(defaultFormat);
            },
            tokens: const [
              TokenInfo('{series_name}', 'Name of the TV series'),
              TokenInfo('{season_number}', 'Season number (01, 02, etc.)'),
              TokenInfo('{episode_number}', 'Episode number (01, 02, etc.)'),
              TokenInfo('{episode_title}', 'Title of the episode'),
              TokenInfo('{year}', 'Release year'),
            ],
            examples: const [
              'Breaking Bad - S01E01 - Pilot',
              'Game of Thrones - S03E09 - The Rains of Castamere',
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
            onSave: () => settings.setMovieFormat(_movieController.text),
            onReset: () {
              const defaultFormat = '{movie_name} ({year})';
              _movieController.text = defaultFormat;
              settings.setMovieFormat(defaultFormat);
            },
            tokens: const [
              TokenInfo('{movie_name}', 'Title of the movie'),
              TokenInfo('{year}', 'Release year'),
            ],
            examples: const [
              'The Matrix (1999)',
              'Inception (2010)',
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
    required VoidCallback onSave,
    required VoidCallback onReset,
    required List<TokenInfo> tokens,
    required List<String> examples,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(icon,
                    size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 20),

            // Format Input
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

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Changes'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset to Default'),
                ),
              ],
            ),

            const Divider(height: 32),

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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        token.token,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Examples
            Text(
              'Examples',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...examples.map((example) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_right,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      example,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Formatting Tips',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTip('Click on any token to insert it at cursor position'),
            _buildTip(
                'Use standard characters like dashes, spaces, and parentheses'),
            _buildTip('Changes apply to newly renamed files'),
            _buildTip(
                'Test your format with a few files before batch processing'),
          ],
        ),
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
}

class TokenInfo {
  final String token;
  final String description;

  const TokenInfo(this.token, this.description);
}
