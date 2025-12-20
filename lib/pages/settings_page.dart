import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import '../widgets/accent_color_picker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize your experience',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // Appearance Card
          _buildCard(
            context,
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              _buildSettingRow(
                context,
                'Theme',
                'Choose your preferred color scheme',
                DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(8),
                  onChanged: (ThemeMode? newValue) {
                    if (newValue != null) {
                      settings.setThemeMode(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accent Color',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your preferred accent color',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const AccentColorPicker(),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

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
                  borderRadius: BorderRadius.circular(8),
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
              const Divider(height: 32),
              _buildAPIKeyInput(
                context,
                'TMDB API Key',
                'Get your key from themoviedb.org',
                settings.tmdbApiKey,
                settings.setTmdbApiKey,
              ),
              const SizedBox(height: 16),
              _buildAPIKeyInput(
                context,
                'OMDb API Key',
                'Get your key from omdbapi.com',
                settings.omdbApiKey,
                settings.setOmdbApiKey,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Folder Exclusions Card
          _buildCard(
            context,
            title: 'Folder Exclusions',
            icon: Icons.folder_off_outlined,
            children: [
              Text(
                'Folders to ignore during matching',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: settings.excludedFolders.isEmpty
                    ? Center(
                        child: Text(
                          'No excluded folders',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: settings.excludedFolders.length,
                        itemBuilder: (context, index) {
                          final folder = settings.excludedFolders[index];
                          return ListTile(
                            dense: true,
                            leading:
                                const Icon(Icons.folder_outlined, size: 20),
                            title: Text(
                              folder,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: Colors.red.shade400,
                              onPressed: () =>
                                  settings.removeExcludedFolder(folder),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  String? selectedDirectory =
                      await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    settings.addExcludedFolder(selectedDirectory);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Folder'),
              ),
            ],
          ),

          const SizedBox(height: 24),

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
                          backgroundColor: Colors.red,
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
                foregroundColor: Colors.red.shade600,
              ),
            ),
          ),
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
            const SizedBox(height: 20),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          obscureText: true,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
