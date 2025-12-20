# Component Library Reference

Complete reference for all reusable widgets in the MyMeta Design System.

---

## 📦 Available Components

| Component | File | Purpose |
|-----------|------|---------|
| CollapsibleCard | `lib/widgets/collapsible_card.dart` | Expandable settings cards with status |
| AboutCard | `lib/widgets/about_card.dart` | App information display |
| AccentColorPicker | `lib/widgets/accent_color_picker.dart` | Color selection grid |
| CustomTitleBar | `lib/widgets/custom_titlebar.dart` | Desktop window controls |

---

## 1. CollapsibleCard

Expandable card with status indicator, ideal for settings sections.

### Properties

```dart
CollapsibleCard({
  required String title,           // Card title
  String? subtitle,                 // Optional subtitle
  required CardStatus status,       // Status indicator
  required Widget collapsedSummary, // Content when collapsed
  required Widget expandedContent,  // Content when expanded
  bool initiallyExpanded = false,   // Initial state
})
```

### CardStatus Enum

```dart
enum CardStatus {
  configured,      // Green circle with check icon
  needsAttention,  // Orange circle with warning icon
  unconfigured,    // Gray circle with info icon
}
```

### Usage Example

```dart
CollapsibleCard(
  title: 'API Settings',
  subtitle: 'Configure your API keys',
  status: CardStatus.configured,
  collapsedSummary: Text(
    'TMDB configured, OMDb pending',
    style: Theme.of(context).textTheme.bodySmall,
  ),
  expandedContent: Column(
    crossAxisAlignment CrossAxisAlignment.start,
    children: [
      TextField(
        decoration: InputDecoration(labelText: 'TMDB API Key'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        decoration: InputDecoration(labelText: 'OMDb API Key'),
      ),
      const SizedBox(height: AppSpacing.md),
      ElevatedButton(
        onPressed: _saveKeys,
        child: const Text('Save'),
      ),
    ],
  ),
)
```

### Design Specs
- **Animation**: 250ms easeInOut for expand/collapse
- **Chevron**: Rotates 180° (0.5 turns)
- **Status Indicator**: 32x32px circle
- **Padding**: 24px (AppSpacing.lg)
- **Border Radius**: 12px
- **Shadow**: Theme-aware card shadow

---

## 2. AboutCard

Displays app information with branding.

### Properties

```dart
AboutCard()  // No parameters - auto-fetches app info
```

### What It Shows
- App icon (if available)
- App name and version
- Build number
- 2x2 info tile grid:
  - Version
  - Platform
  - Build
  - Framework
- Branded footer with accent-colored heart

### Usage Example

```dart
// Simply add to your settings page
ListView(
  padding: const EdgeInsets.all(AppSpacing.lg),
  children: [
    // ... other settings ...
    const SizedBox(height: AppSpacing.md),
    const AboutCard(),
  ],
)
```

### Design Specs
- **Info Tiles**: 2x2 grid with 12px gap
- **Tile Background**: 3% opacity (light), 5% opacity (dark)
- **Tile Padding**: 16px
- **Tile Radius**: 8px
- **Heart Icon**: 16px, accent color
- **Overall Padding**: 24px

### Dependencies
- Requires `package_info_plus: ^8.0.0`

---

## 3. AccentColorPicker

Grid of selectable accent colors.

### Properties

```dart
AccentColorPicker()  // Uses SettingsService for state
```

### Available Colors

| Name | Hex | Icon |
|------|-----|------|
| Indigo | `#6366F1` | auto_awesome |
| Blue | `#3B82F6` | water_drop |
| Purple | `#8B5CF6` | local_florist |
| Pink | `#EC4899` | favorite |
| Red | `#EF4444` | local_fire_department |
| Orange | `#F97316` | wb_sunny |
| Green | `#10B981` | eco |
| Teal | `#14B8A6` | waves |

### Usage Example

```dart
_buildCard(
  context,
  title: 'Appearance',
  icon: Icons.palette_outlined,
  children: [
    Text(
      'Accent Color',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: AppSpacing.xs),
    Text(
      'Choose your preferred accent color',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: AppSpacing.md),
    const AccentColorPicker(),
  ],
)
```

### Design Specs
- **Circle Size**: 64x64px
- **Spacing**: 16px between circles
- **Selected Border**: 4px white/surface color
- **Shadow**: Colored glow (20% opacity unselected, 50% selected)
- **Icon**: 24px (unselected), 32px check (selected)
- **Animation**: 200ms size/shadow transition

---

## 4. CustomTitleBar (Desktop Only)

Window controls with theme toggle for desktop apps.

### Properties

```dart
CustomTitleBar({
  required String title,      // Window title
  String? iconAssetPath,      // Optional app icon
  VoidCallback? onThemeToggle, // Theme toggle callback
})
```

###Usage Example

```dart
Scaffold(
  body: Column(
    children: [
      CustomTitleBar(
        title: 'MyMeta',
        iconAssetPath: 'assets/MyMeta.png',
        onThemeToggle: () {
          final settings = context.read<SettingsService>();
          final newMode = settings.themeMode == ThemeMode.light
              ? ThemeMode.dark
              : ThemeMode.light;
          settings.setThemeMode(newMode);
        },
      ),
      Expanded(child: YourContent()),
    ],
  ),
)
```

### Features
- Drag to move window
- Minimize/maximize/close buttons
- Theme toggle with 300ms rotation animation
- App icon with shadow
- Retractable tab bar trigger (hover header to show tabs)

### Design Specs
- **Height**: 60px
- **Icon Size**: 30x30px, 7px radius
- **Title**: 18px bold, -0.5 letter spacing
- **Padding**: 16px horizontal, 12px vertical
- **Theme Toggle**: light_mode / dark_mode_outlined icons
- **Controls**: Platform-specific styling

---

## Using Components in Your App

### 1. Copy Widget Files
```bash
cp lib/widgets/collapsible_card.dart your-app/lib/widgets/
cp lib/widgets/about_card.dart your-app/lib/widgets/
```

### 2. Import in Your Code
```dart
import 'package:your_app/widgets/collapsible_card.dart';
import 'package:your_app/widgets/about_card.dart';
```

### 3. Use in Your Pages
Follow the usage examples above for each component.

---

## Creating New Components

When building new widgets, follow these principles:

### 1. Theme-Aware Styling
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
```

### 2. Use Design Tokens
```dart
// Good ✅
BorderRadius.circular(AppDimensions.cardBorderRadius)
const EdgeInsets.all(AppSpacing.lg)

// Bad ❌
BorderRadius.circular(12.0)
const EdgeInsets.all(24.0)
```

### 3. Consistent Animations
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  curve: Curves.easeOutCubic,
  // ...
)
```

### 4. Proper Shadows
```dart
boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow
```

---

## Component Checklist

Before adding a new component to the library:

- [ ] Uses only theme colors (no hardcoded colors)
- [ ] Uses spacing from AppSpacing
- [ ] Uses dimensions from AppDimensions
- [ ] Works in both light and dark themes
- [ ] Has smooth animations (150-250ms)
- [ ] Uses proper shadows
- [ ] Follows 8px grid system
- [ ] Has documentation with examples
- [ ] Handles edge cases (empty states, etc.)
- [ ] Uses const constructors where possible

---

**See also:**
- [layout_and_components.md](./layout_and_components.md) - Layout specifications
- [animation_improvements.md](./animation_improvements.md) - Animation guidelines
- [Getting_Started.md](./Getting_Started.md) - Setup guide
