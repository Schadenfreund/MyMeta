import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'renamer_page.dart';
import 'formats_page.dart';
import 'settings_page.dart';
import '../widgets/custom_titlebar.dart';
import '../services/settings_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _sidebarVisible = false;

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
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final accentColor = settings.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          const CustomTitleBar(),
          Expanded(
            child: Stack(
              children: [
                // Content Area (full width)
                _pages[_selectedIndex],

                // Auto-Hide Sidebar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _sidebarVisible = true),
                    onExit: (_) => setState(() => _sidebarVisible = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: _sidebarVisible ? 72 : 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        border: _sidebarVisible
                            ? Border(
                                right: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : Colors.grey.shade200,
                                  width: 1,
                                ),
                              )
                            : null,
                        boxShadow: _sidebarVisible
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(2, 0),
                                ),
                              ]
                            : null,
                      ),
                      child: _sidebarVisible
                          ? Column(
                              children: [
                                const SizedBox(height: 8),
                                ...List.generate(_tabs.length, (index) {
                                  return _buildSidebarTab(
                                    _tabs[index].label,
                                    _tabs[index].icon,
                                    index,
                                    accentColor,
                                    isDark,
                                  );
                                }),
                              ],
                            )
                          : const SizedBox(),
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

  Widget _buildSidebarTab(
    String label,
    IconData icon,
    int index,
    Color accentColor,
    bool isDark,
  ) {
    final isSelected = _selectedIndex == index;

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          height: 64,
          width: 72, // Explicit full width
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TabInfo {
  final String label;
  final IconData icon;

  const TabInfo(this.label, this.icon);
}
