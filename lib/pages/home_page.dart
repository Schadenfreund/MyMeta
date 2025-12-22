import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'renamer_page.dart';
import 'formats_page.dart';
import 'settings_page.dart';
import '../widgets/custom_titlebar.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool _tabbarVisible = false;
  late TabController _tabController;
  Timer? _hideTimer;

  static const List<Widget> _pages = <Widget>[
    RenamerPage(),
    FormatsPage(),
    SettingsPage(),
  ];

  static const List<TabInfo> _tabs = [
    TabInfo('Renamer', Icons.drive_file_rename_outline),
    TabInfo('Formats', Icons.text_fields),
    TabInfo('Settings', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _showTabBar() {
    _hideTimer?.cancel();
    if (!_tabbarVisible) {
      setState(() {
        _tabbarVisible = true;
      });
    }
  }

  void _scheduleHideTabBar() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _tabbarVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final accentColor = settings.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Header with hover detection
          MouseRegion(
            onEnter: (_) => _showTabBar(),
            onExit: (_) => _scheduleHideTabBar(),
            child: const CustomTitleBar(),
          ),
          Expanded(
            child: Stack(
              children: [
                // Content Area with TabBarView
                TabBarView(
                  controller: _tabController,
                  children: _pages,
                ),

                // Retractable Tab Bar overlaying content
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_tabbarVisible,
                    child: MouseRegion(
                      onEnter: (_) => _showTabBar(),
                      onExit: (_) => _scheduleHideTabBar(),
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        offset: _tabbarVisible
                            ? Offset.zero
                            : const Offset(0, -1.0),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          opacity: _tabbarVisible ? 1.0 : 0.0,
                          child: IgnorePointer(
                            ignoring: !_tabbarVisible,
                            child: SizedBox(
                              height: AppDimensions.tabBarHeight,
                              child: _buildTabBar(accentColor, isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color accentColor, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor:
            isDark ? AppColors.darkBorder : AppColors.lightBorder,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3.0,
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(width: 3, color: accentColor),
        ),
        labelColor: accentColor,
        unselectedLabelColor: secondaryColor,
        overlayColor: WidgetStateProperty.all(accentColor.withOpacity(0.1)),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: _tabs.map((tab) {
          return Tab(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 18),
                const SizedBox(width: 6),
                Text(tab.label),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TabInfo {
  final String label;
  final IconData icon;

  const TabInfo(this.label, this.icon);
}
