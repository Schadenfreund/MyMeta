import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';

/// A minimal About card matching the centralized design.
/// Shows app icon, name, version, and a support link.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  Future<void> _openPayPal(BuildContext context) async {
    final Uri url = Uri.parse('https://www.paypal.com/paypalme/ivburic');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open PayPal. Visit: paypal.me/ivburic'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsService>();
    final accentColor = settings.accentColor;

    // Use lifetime statistics from settings
    final int tvShowCount = settings.lifetimeTvShowsMatched;
    final int movieCount = settings.lifetimeMoviesMatched;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '1.6.1';

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
            boxShadow:
                isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with logo and version
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Accent-colored logo
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          accentColor,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/MyMeta Symbol.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'MyMeta',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Version $version',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 13,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Full-width Stats Section - Horizontal layout
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.08),
                        accentColor.withOpacity(0.03),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // TV Shows Stat
                      Expanded(
                        child: _buildCompactStatItem(
                          context,
                          icon: Icons.tv_rounded,
                          count: tvShowCount,
                          label: 'TV Shows Matched',
                          accentColor: accentColor,
                          isDark: isDark,
                        ),
                      ),

                      // Vertical Divider
                      Container(
                        height: 40,
                        width: 1,
                        margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.0),
                              accentColor.withOpacity(0.3),
                              accentColor.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),

                      // Movies Stat
                      Expanded(
                        child: _buildCompactStatItem(
                          context,
                          icon: Icons.movie_rounded,
                          count: movieCount,
                          label: 'Movies Matched',
                          accentColor: accentColor,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Centered "Made With..." message
                Center(
                  child: Row(
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
                        color: accentColor,
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
                ),
                const SizedBox(height: AppSpacing.md),

                // Support Button - Centered
                Center(
                  child: ElevatedButton(
                    onPressed: () => _openPayPal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactStatItem(
    BuildContext context, {
    required IconData icon,
    required int count,
    required String label,
    required Color accentColor,
    required bool isDark,
  }) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: accentColor,
          ),
          const SizedBox(width: 12),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  fontSize: 28,
                  height: 1.0,
                ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
