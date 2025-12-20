# Typography System

Uses **Roboto** font family throughout.

## Text Scale

| Logical Name | Size | Weight | Line Height | Letter Spacing | Usage |
|--------------|------|--------|-------------|----------------|-------|
| `displayLarge` | 30px | Bold (700) | 1.2 | -0.5 | Page titles |
| `displayMedium` | 24px | SemiBold (600) | 1.2 | -0.25 | Section headers |
| `displaySmall` | 20px | SemiBold (600) | 1.3 | 0 | Card titles |
| `headlineLarge` | 18px | SemiBold (600) | 1.3 | 0 | Sub-headers |
| `headlineSmall` | 16px | SemiBold (600) | 1.4 | 0 | List headers |
| `bodyLarge` | 16px | Regular (400) | 1.5 | 0 | Primary body text |
| `bodyMedium` | 14px | Regular (400) | 1.5 | 0 | Secondary body text |
| `bodySmall` | 12px | Regular (400) | 1.4 | 0.25 | Captions, labels |
| `labelLarge` | 14px | Medium (500) | 1.4 | 0.1 | Buttons |
| `labelSmall` | 12px | Medium (500) | 1.4 | 0.5 | Small buttons, chips |

## Component-Specific Styles

### AppBar Title
- **Size**: 18px
- **Weight**: SemiBold (600)
- **Letter Spacing**: -0.5
- **Line Height**: 1.0

### Button Text
- **Size**: 14px  
- **Weight**: Medium (500)
- **Letter Spacing**: 0.5 (uppercase)
- **Transform**: Uppercase for primary buttons

### Input Text
- **Size**: 14px
- **Weight**: Regular (400)
- **Color**: `TextPrimary`

### Label Text
- **Size**: 12px
- **Weight**: Regular (400)
- **Color**: `TextSecondary`

### Tab Bar Labels
- **Size**: 14px
- **Weight**: Medium (500)
- **Letter Spacing**: 0.25

---

## Usage Examples

### Page Title
```dart
Text(
  'Settings',
  style: Theme.of(context).textTheme.displayLarge,
)
```

### Section Header  
```dart
Text(
  'Appearance',
  style: Theme.of(context).textTheme.displayMedium,
)
```

### Card Title
```dart
Text(
  'About MyMeta',
  style: Theme.of(context).textTheme.displaySmall,
)
```

### Body Text
```dart
Text(
  'This is the main content of the paragraph.',
  style: Theme.of(context).textTheme.bodyLarge,
)
```

### Secondary Text
```dart
Text(
  'Additional information or description',
  style: Theme.of(context).textTheme.bodyMedium,
)
```

### Caption / Small Text
```dart
Text(
  'Version 1.0.0',
  style: Theme.of(context).textTheme.bodySmall,
)
```

### Custom Text with Color
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

Text(
  'Custom styled text',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
    fontWeight: FontWeight.w600,
  ),
)
```

---

## Text Hierarchy Guidelines

### DO ✅
- Use one `displayLarge` per page (main title)
- Use `displayMedium` for major sections
- Use `displaySmall` for card/panel titles
- Use `bodyMedium` for most content
- Use `bodySmall` for secondary info
- Use theme text styles: `Theme.of(context).textTheme.X`
- Override only when necessary with `.copyWith()`

### DON'T ❌
- Mix font families (always Roboto)
- Create custom TextStyles from scratch
- Use hardcoded font sizes
- Skip the text hierarchy (jumping from Large to Small)
- Use too many sizes on one screen
- Forget to test readability in both themes

---

## Accessibility

### Minimum Sizes
- ✅ Body text: 14px minimum (bodyMedium)
- ✅ Captions: 12px minimum (bodySmall)
- ❌ Never go below 12px

### Contrast
- All text uses colors from [colors.md](./colors.md)
- Primary text: Highest contrast (87% opacity)
- Secondary text: Medium contrast (60% opacity)
- Tertiary text: Lower contrast (38% opacity) - use sparingly

### Line Length
- Optimal: 50-75 characters per line
- Maximum: 90 characters per line
- Use responsive padding to control width

---

## Quick Reference

| Use Case | Text Style | Example |
|----------|-----------|---------|
| Page Title | `displayLarge` | "Settings" |
| Section Header | `displayMedium` | "Appearance" |
| Card Title | `displaySmall` | "About MyMeta" |
| Paragraph | `bodyLarge` | Main content |
| Description | `bodyMedium` | Supporting text |
| Label | `bodySmall` | "Version 1.0.0" |
| Button | `labelLarge` | "SAVE CHANGES" |

---

## Font Files

Required font files in `design/fonts/`:
- `Roboto-Regular.ttf` (Weight: 400)
- `Roboto-Medium.ttf` (Weight: 500)
- `Roboto-Bold.ttf` (Weight: 700)

### pubspec.yaml Configuration
```yaml
flutter:
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

---

**See also:**
- [colors.md](./colors.md) - Text color specifications
- [layout_and_components.md](./layout_and_components.md) - Component usage
- [Getting_Started.md](./Getting_Started.md) - Setup guide
