import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

/// A simple row of color circles for selecting the app's accent color.
/// Matches the reference design with minimal, clean circles.
class AccentColorPicker extends StatelessWidget {
  const AccentColorPicker({super.key});

  static const List<ColorOption> colors = [
    ColorOption('Indigo', Color(0xFF6366F1)),
    ColorOption('Blue', Color(0xFF3B82F6)),
    ColorOption('Purple', Color(0xFF8B5CF6)),
    ColorOption('Pink', Color(0xFFEC4899)),
    ColorOption('Red', Color(0xFFEF4444)),
    ColorOption('Orange', Color(0xFFF97316)),
    ColorOption('Green', Color(0xFF10B981)),
    ColorOption('Teal', Color(0xFF14B8A6)),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: colors.map((colorOption) {
        final isSelected =
            colorOption.color.value == settings.accentColor.value;

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _ColorCircle(
            colorOption: colorOption,
            isSelected: isSelected,
            onTap: () => settings.setAccentColor(colorOption.color),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorCircle extends StatefulWidget {
  final ColorOption colorOption;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.colorOption,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ColorCircle> createState() => _ColorCircleState();
}

class _ColorCircleState extends State<_ColorCircle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.colorOption.name,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.colorOption.color,
              shape: BoxShape.circle,
              border: widget.isSelected
                  ? Border.all(
                      color: Colors.white,
                      width: 3,
                    )
                  : null,
              boxShadow: [
                if (widget.isSelected || _isHovered)
                  BoxShadow(
                    color: widget.colorOption.color.withAlpha(150),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: widget.isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class ColorOption {
  final String name;
  final Color color;

  const ColorOption(this.name, this.color);
}
