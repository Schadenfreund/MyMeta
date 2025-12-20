# Getting Started with MyMeta Design System

This guide will walk you through integrating the MyMeta design system into a new Flutter project in **10 minutes or less**.

---

## ⚡ Quick Start (TL;DR)

```bash
# 1. Copy files
cp -r design/ your-project/design/
cp -r lib/theme/ your-project/lib/theme/
cp lib/widgets/{collapsible_card,about_card}.dart your-project/lib/widgets/

# 2. Add to pubspec.yaml
# - provider: ^6.0.5
# - package_info_plus: ^8.0.0
# - Roboto fonts from design/fonts/

# 3. Use in main.dart
theme: AppTheme.lightTheme(yourAccentColor),
darkTheme: AppTheme.darkTheme(yourAccentColor),

#  4. Start building!
```

---

## 📋 Detailed Setup

### Step 1: Create Your Project

```bash
flutter create my_new_app
cd my_new_app
```

### Step 2: Copy Design System Files

#### A. Copy the design folder
```bash
cp -r /path/to/MyMeta/design ./design
```

This includes:
- ✅ All documentation (.md files)
- ✅ Roboto fonts (design/fonts/)

#### B. Copy the theme
```bash
mkdir -p lib/theme
cp /path/to/MyMeta/lib/theme/app_theme.dart ./lib/theme/
```

#### C. Copy reusable widgets
```bash
mkdir -p lib/widgets
cp /path/to/MyMeta/lib/widgets/collapsible_card.dart ./lib/widgets/
cp /path/to/MyMeta/lib/widgets/about_card.dart ./lib/widgets/
```

### Step 3: Update pubspec.yaml

```yaml
name: my_new_app
description: My awesome app using MyMeta design

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.0.5
  
  # App Info (for AboutCard)
  package_info_plus: ^8.0.0
  
  # Desktop Support (Optional - only if building desktop app)
  window_manager: ^0.3.5

flutter:
  uses-material-design: true
  
  # Roboto Fonts (Required)
  fonts:
    - family: Roboto
      fonts:
        - asset: design/fonts/Roboto-Regular.ttf
          weight: 400
        - asset: design/fonts/Roboto-Medium.ttf
          weight: 500
        - asset: design/fonts/Roboto-Bold.ttf
          weight: 700
```

```bash
flutter pub get
```

### Step 4: Create Settings Service (Optional but Recommended)

```dart
// lib/services/settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService with ChangeNotifier {
  late SharedPreferences _prefs;
  
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFF6366F1);
  
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }
  
  void _loadSettings() {
    final themeModeString = _prefs.getString('theme_mode') ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.toString() == 'ThemeMode.$themeModeString',
      orElse: () => ThemeMode.system,
    );
    
    final colorValue = _prefs.getInt('accent_color') ?? 0xFF6366F1;
    _accentColor = Color(colorValue);
    
    notifyListeners();
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString('theme_mode', mode.toString().split('.').last);
    notifyListeners();
  }
  
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _prefs.setInt('accent_color', color.value);
    notifyListeners();
  }
}
```

### Step 5: Update main.dart

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize settings
  final settings = SettingsService();
  await settings.init();
  
  runApp(
    ChangeNotifierProvider<SettingsService>.value(
      value: settings,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return MaterialApp(
      title: 'My New App',
      
      // Apply MyMeta Design System
      theme: AppTheme.lightTheme(settings.accentColor),
      darkTheme: AppTheme.darkTheme(settings.accentColor),
      themeMode: settings.themeMode,
      
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My New App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome!',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Using MyMeta Design System',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 6: Test It!

```bash
flutter run
```

You should see:
- ✅ Roboto font applied
- ✅ Proper colors from theme
- ✅ Typography working
- ✅ Light/dark mode switching (if supported)

---

## 🎨 Your First Component

Let's build a settings page using the design system:

```dart
// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../widgets/about_card.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Header
          Text(
            'Settings',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Customize your experience',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Theme Card
          _buildCard(
            context,
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                title: const Text('Theme'),
                subtitle: const Text('Choose your preferred mode'),
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  onChanged: (mode) => settings.setThemeMode(mode!),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // About Card
          const AboutCard(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardShadow = isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.displaySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}
```

---

## ✅ Verification Checklist

After setup, verify these work:

### Colors
- [ ] Light theme uses correct background
- [ ] Dark theme uses correct background
- [ ] Primary color is your accent
- [ ] Text has proper contrast

### Typography  
- [ ] Roboto font is applied
- [ ] Display styles are bold
- [ ] Body text is regular weight
- [ ] Sizes match specs (30/24/20/18/16/14/12)

### Spacing
- [ ] Cards have 24px (lg) padding
- [ ] Sections have 16px (md) spacing
- [ ] Elements have 8px (xs) gaps

### Components
- [ ] Cards have 12px radius
- [ ] Buttons have 8px radius
- [ ] Shadows match light/dark
- [ ] Inputs use theme styling

---

## 🎯 Next Steps

Now that setup is complete:

1. **Read Component Docs**: [layout_and_components.md](./layout_and_components.md)
2. **Study Colors**: [colors.md](./colors.md)
3. **Review Typography**: [typography.md](./typography.md)
4. **Add Animations**: [animation_improvements.md](./animation_improvements.md)

5. **Build Your UI**: Follow the patterns from MyMeta reference app

---

## 🆘 Common Issues

### "Can't find AppTheme"
- Ensure you copied `lib/theme/app_theme.dart`
- Import: `import 'package:your_app/theme/app_theme.dart';`

### "Roboto font not loading"
- Check `pubspec.yaml` fonts section
- Verify files exist in `design/fonts/`
- Run `flutter pub get` and rebuild

### "Colors look wrong"
- Use `AppColors.lightX` for light theme
- Use `AppColors.darkX` for dark theme
- Get brightness: `Theme.of(context).brightness`

### "AboutCard crashes"
- Add `package_info_plus: ^8.0.0` to pubspec
- Run `flutter pub get`

---

## 💡 Tips for Success

1. **Always use theme colors** - Never hardcode `Colors.blue`
2. **Always use AppSpacing** - Never hardcode `16.0`
3. **Always use text styles** - `Theme.of(context).textTheme.X`
4. **Test both themes** - Light AND dark
5. **Follow 8px grid** - All spacing multiples of 8

---

**Ready to build something amazing!** 🚀

Refer back to [README.md](./README.md) for navigation and [layout_and_components.md](./layout_and_components.md) for component details.
