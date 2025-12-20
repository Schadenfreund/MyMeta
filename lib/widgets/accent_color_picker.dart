import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class AccentColorPicker extends StatelessWidget {
  const AccentColorPicker({super.key});

  static const List<ColorOption> colors = [
    ColorOption('Indigo', Color(0xFF6366F1), Icons.auto_awesome),
    ColorOption('Blue', Color(0xFF3B82F6), Icons.water_drop),
    ColorOption('Purple', Color(0xFF8B5CF6), Icons.local_florist),
    ColorOption('Pink', Color(0xFFEC4899), Icons.favorite),
    ColorOption('Red', Color(0xFFEF4444), Icons.local_fire_department),
    ColorOption('Orange', Color(0xFFF97316), Icons.wb_sunny),
    ColorOption('Green', Color(0xFF10B981), Icons.eco),
    ColorOption('Teal', Color(0xFF14B8A6), Icons.waves),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: colors.map((colorOption) {
        final isSelected =
            colorOption.color.value == settings.accentColor.value;

        return Tooltip(
          message: colorOption.name,
          child: GestureDetector(
            onTap: () => settings.setAccentColor(colorOption.color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorOption.color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 4,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color:
                        colorOption.color.withOpacity(isSelected ? 0.5 : 0.2),
                    blurRadius: isSelected ? 16 : 8,
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                isSelected ? Icons.check : colorOption.icon,
                color: Colors.white,
                size: isSelected ? 32 : 24,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ColorOption {
  final String name;
  final Color color;
  final IconData icon;

  const ColorOption(this.name, this.color, this.icon);
}
