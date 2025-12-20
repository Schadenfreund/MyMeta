import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final hoverColor = isDark ? AppColors.darkHover : AppColors.lightHover;
    final accentColor = settings.accentColor;

    return Container(
      height: AppDimensions.headerHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: AppTheme.lightHeaderShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // App Icon with shadow
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                image: const DecorationImage(
                  image: AssetImage('assets/MyMeta.png'),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'MyMeta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.0,
                color: textColor,
              ),
            ),

            // Drag area (expands to fill space)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  windowManager.startDragging();
                },
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
            ),

            // Theme Toggle
            _ThemeToggleButton(
              isDark: isDark,
              onPressed: () {
                final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                settings.setThemeMode(newMode);
              },
              hoverColor: hoverColor,
              iconColor: textColor,
            ),

            // Window Controls
            _WindowButton(
              icon: Icons.minimize,
              onPressed: () => windowManager.minimize(),
              hoverColor: hoverColor,
              iconColor: textColor,
            ),
            _WindowButton(
              icon: Icons.crop_square,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              hoverColor: hoverColor,
              iconColor: textColor,
            ),
            _WindowButton(
              icon: Icons.close,
              onPressed: () => windowManager.close(),
              hoverColor: hoverColor,
              iconColor: accentColor,
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color iconColor;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    required this.iconColor,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: AppDimensions.headerHeight,
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: widget.iconColor,
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color iconColor;

  const _ThemeToggleButton({
    required this.isDark,
    required this.onPressed,
    required this.hoverColor,
    required this.iconColor,
  });

  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_ThemeToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      _rotationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: AppDimensions.headerHeight,
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : Colors.transparent,
          ),
          child: RotationTransition(
            turns: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _rotationController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Icon(
              widget.isDark ? Icons.dark_mode_outlined : Icons.light_mode,
              size: 18,
              color: widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
