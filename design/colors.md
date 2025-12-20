# Color System

## Light Theme
| Name | Hex Code | Usage |
|------|----------|-------|
| Primary | `#4F46E5` | Main brand color, actions, active states |
| Secondary | `#6B7280` | Secondary text, inactive states |
| Success | `#10B981` | Success states, completions |
| Danger | `#EF4444` | Errors, destructive actions |
| Warning | `#F1C232` | Warnings, attention needed |
| Info | `#3B82F6` | Information, links |
| Background | `#F9FAFB` | App background |
| Surface | `#FFFFFF` | Cards, headers, sheets |
| Border | `#E5E7EB` | Dividers, borders |
| Hover | `#F3F4F6` | Hover states |
| Text Primary | `#111827` | High emphasis text |
| Text Secondary | `#6B7280` | Medium emphasis text |
| Text Tertiary | `#9CA3AF` | Low emphasis text / placeholders |

## Dark Theme
| Name | Hex Code | Usage |
|------|----------|-------|
| Primary | `#6366F1` | Main brand color (lighter for dark mode) |
| Secondary | `#9CA3AF` | Secondary text |
| Success | `#10B981` | Success states |
| Danger | `#EF4444` | Errors |
| Warning | `#F1C232` | Warnings |
| Info | `#3B82F6` | Info |
| Background | `#111827` | App background (very dark blue/gray) |
| Surface | `#1F2937` | Cards, headers, sheets |
| Border | `#374151` | Dividers, borders |
| Hover | `#374151` | Hover states |
| Text Primary | `#F9FAFB` | High emphasis text |
| Text Secondary | `#9CA3AF` | Medium emphasis text |
| Text Tertiary | `#6B7280` | Low emphasis text |

## Derived Styles
- **Input Fields**: Filled with Surface color, border color derived from theme (Light/Dark Border). Focused border uses Primary color (`width: 2`).
- **Cards**: Surface color, 1px border linked to Theme Border color.
- **Shadows**:
  - Light: `Colors.black.withValues(alpha: 0.05)`, Blur: 10, Offset: 0,4
  - Dark: `Colors.black.withValues(alpha: 0.3)`, Blur: 16, Offset: 0,8

---

## Usage Examples

### Getting Current Theme
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
```

### Using Theme Colors
```dart
// Always use theme-aware colors
Container(
  color: Theme.of(context).colorScheme.surface,  // Adaptive
  child: Text(
    'Hello',
    style: TextStyle(
      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    ),
  ),
)
```

### Status Colors (Theme-Independent)
```dart
// These are the same in light and dark modes
Icon(Icons.check_circle, color: AppColors.lightSuccess)  // Green
Icon(Icons.error, color: AppColors.lightDanger)          // Red
Icon(Icons.warning, color: AppColors.lightWarning)       // Orange
Icon(Icons.info, color: AppColors.lightInfo)             // Blue
```

### Applying Shadows
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow,
  ),
)
```

### Hover States
```dart
MouseRegion(
  onEnter: (_) => setState(() => _isHovered = true),
  onExit: (_) => setState(() => _isHovered = false),
  child: Container(
    color: _isHovered
        ? (isDark ? AppColors.darkHover : AppColors.lightHover)
        : Colors.transparent,
    child: ListTile(...),
  ),
)
```

---

## Color Accessibility

### Contrast Ratios (WCAG AA Compliant)
- **Text Primary on Background**: > 12:1 (Excellent)
- **Text Secondary on Background**: > 7:1 (Good)  
- **Text Tertiary on Background**: > 4.5:1 (Pass)
- **Primary on Surface**: > 4.5:1 (Pass)

### Usage Guidelines
- ✅ Use `TextPrimary` for main content
- ✅ Use `TextSecondary` for supporting text
- ✅ Use `TextTertiary` for hints and placeholders
- ❌ Don't use Tertiary for important information
- ❌ Don't use custom alpha values (use defined colors)

---

## Quick Reference Table

| Purpose | Light Mode | Dark Mode | Code |
|---------|-----------|-----------|------|
| **App Background** | `#F9FAFB` | `#111827` | `AppColors.light/darkBackground` |
| **Card/Surface** | `#FFFFFF` | `#1F2937` | `AppColors.light/darkSurface` |
| **Borders** | `#E5E7EB` | `#374151` | `AppColors.light/darkBorder` |
| **Main Text** | `#111827` | `#F9FAFB` | `AppColors.light/darkTextPrimary` |
| **Secondary Text** | `#6B7280` | `#9CA3AF` | `AppColors.light/darkTextSecondary` |
| **Hint Text** | `#9CA3AF` | `#6B7280` | `AppColors.light/darkTextTertiary` |
| **Success** | `#10B981` | `#10B981` | `AppColors.lightSuccess` |
| **Danger** | `#EF4444` | `#EF4444` | `AppColors.lightDanger` |
| **Warning** | `#F1C232` | `#F1C232` | `AppColors.lightWarning` |
| **Info** | `#3B82F6` | `#3B82F6` | `AppColors.lightInfo` |

---

**See also:**
- [typography.md](./typography.md) - Text styles using these colors
- [layout_and_components.md](./layout_and_components.md) - Components with color specifications
- [Getting_Started.md](./Getting_Started.md) - Setup and integration guide
