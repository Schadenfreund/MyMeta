# MyMeta Design System

A clean, modern Flutter design system supporting light/dark themes with customizable accent colors.

## 🎨 Quick Start

Copy the `lib/theme/` folder to your new project and import:

```dart
import 'theme/app_theme.dart';
```

Then use in your MaterialApp:

```dart
MaterialApp(
  theme: AppTheme.lightTheme(accentColor),
  darkTheme: AppTheme.darkTheme(accentColor),
  themeMode: ThemeMode.system,
)
```

## 📦 What's Included

### Colors (`AppColors`)
- **Light theme**: Primary, secondary, success, danger, warning, info
- **Dark theme**: Same semantic colors, optimized for dark backgrounds
- **Text colors**: Primary, secondary, tertiary for visual hierarchy

### Spacing (`AppSpacing`)
```dart
xs: 8    // Tight spacing
sm: 12   // Small gaps
md: 16   // Standard spacing
lg: 24   // Section spacing
xl: 32   // Large gaps
xxl: 48  // Page margins
```

### Dimensions (`AppDimensions`)
```dart
cardBorderRadius: 12.0
inputBorderRadius: 8.0
tabBarHeight: 48.0
headerHeight: 60.0
maxContentWidth: 1200.0
```

### Theme Components
- Complete `ThemeData` for light/dark modes
- Pre-styled buttons, cards, inputs, dialogs
- Consistent shadows and elevations
- Typography scale

## 🎯 Design Principles

1. **Consistency**: Use `AppSpacing` and `AppDimensions` everywhere
2. **Semantic colors**: Use success/danger/warning appropriately
3. **Dark mode first**: All colors work in both themes
4. **Customizable accent**: Pass any color to `lightTheme()`/`darkTheme()`

## 💡 Usage Examples

### Cards
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
    boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow,
  ),
  padding: EdgeInsets.all(AppSpacing.lg),
  child: YourContent(),
)
```

### Status Indicators
```dart
Container(
  padding: EdgeInsets.all(6),
  decoration: BoxDecoration(
    color: AppColors.lightSuccess.withOpacity(0.15),
    shape: BoxShape.circle,
  ),
  child: Icon(Icons.check, size: 16, color: AppColors.lightSuccess),
)
```

### Text Hierarchy
```dart
Text('Title', style: Theme.of(context).textTheme.displayMedium),
Text('Subtitle', style: Theme.of(context).textTheme.bodyMedium),
Text('Caption', style: Theme.of(context).textTheme.bodySmall),
```

## 📁 File Structure

```
lib/theme/
├── app_theme.dart      # Complete design system
└── README.md           # This file

lib/widgets/
├── about_card.dart     # Reusable about card
└── ...                 # Other reusable widgets
```

## 🔧 Customization

### Change Accent Color
```dart
// In SettingsService or similar
Color accentColor = Color(0xFF4F46E5); // Indigo
```

### Add New Colors
```dart
// In AppColors class
static const Color yourColor = Color(0xFFHEXCODE);
```

### Add New Spacing
```dart
// In AppSpacing class
static const double yourSpacing = 40.0;
```

---

Built with ❤️ for Flutter
