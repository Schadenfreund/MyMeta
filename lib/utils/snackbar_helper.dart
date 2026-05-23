import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// Helper for showing consistently-styled, themed snackbars throughout the app.
///
/// All four variants share the same shape (floating, rounded, bordered surface);
/// only the icon and accent color differ to convey severity.
class SnackbarHelper {
  static void showSuccess(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
    _show(context,
        message: message,
        icon: Icons.check_circle_outlined,
        accent: context.read<SettingsService>().accentColor,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? const Duration(seconds: 3));
  }

  static void showInfo(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
    _show(context,
        message: message,
        icon: Icons.info_outline,
        accent: context.read<SettingsService>().accentColor,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? const Duration(seconds: 3));
  }

  static void showWarning(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _show(context,
        message: message,
        icon: Icons.warning_amber_rounded,
        accent: isDark ? AppColors.darkWarning : AppColors.lightWarning,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? const Duration(seconds: 5));
  }

  static void showError(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _show(context,
        message: message,
        icon: Icons.error_outline,
        accent: isDark ? AppColors.darkDanger : AppColors.lightDanger,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? const Duration(seconds: 4));
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color accent,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final surface =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withOpacity(0.3), width: 1.5),
        ),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: accent,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
