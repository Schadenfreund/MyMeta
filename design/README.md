# MyMeta Design System

> **A professional, consistent, and beautiful design language for Flutter applications**

This folder contains the complete design system used in MyMeta, ready to be copied and applied to your next Flutter project. Every component, color, spacing value, and animation has been carefully crafted and documented.

---

## 📁 Quick Navigation

| Document | Purpose | Use When |
|----------|---------|----------|
| **[START HERE](./Getting_Started.md)** | Step-by-step setup guide | Starting a new project |
| [colors.md](./colors.md) | Complete color palette | Styling any component |
| [typography.md](./typography.md) | Text styles and hierarchy | Adding text anywhere |
| [layout_and_components.md](./layout_and_components.md) | Component specifications | Building UI elements |
| [animation_improvements.md](./animation_improvements.md) | Animation best practices | Adding smooth transitions |
| [prompt.md](./prompt.md) | Quick reference checklist | Quality assurance |

**Status Reports** (Optional Reading):
- [COMPLETE_IMPLEMENTATION.md](./COMPLETE_IMPLEMENTATION.md) - What's been built
- [IMPLEMENTATION_REVIEW.md](./IMPLEMENTATION_REVIEW.md) - Design system audit
- [RECENT_UPDATES.md](./RECENT_UPDATES.md) - Latest changes

---

## 🎨 What Is This Design System?

The MyMeta Design System is a complete, production-ready visual language that provides:

- **Color Palette**: Light and dark themes with semantic colors
- **Typography Scale**: Roboto font with 10 predefined text styles
- **Spacing System**: Strict 8px grid for perfect alignment
- **Component Library**: Cards, buttons, inputs, dialogs, and more
- **Animation Guidelines**: Smooth, professional transitions
- **Theme Support**: Seamless light/dark mode switching

### Why Use This?

✅ **Consistency**: Every app built with this looks cohesive  
✅ **Speed**: No design decisions needed - it's all solved  
✅ **Professional**: Matches modern app quality standards  
✅ **Flexible**: Accent color customization per app  
✅ **Proven**: Battle-tested in MyMeta production app  

---

## 🚀 Getting Started (5 Minutes)

### 1. Copy Required Files

```bash
# From your new project root:
cp -r /path/to/MyMeta/design ./design
cp -r /path/to/MyMeta/lib/theme ./lib/theme
cp -r /path/to/MyMeta/lib/widgets/collapsible_card.dart ./lib/widgets/
cp -r /path/to/MyMeta/lib/widgets/about_card.dart ./lib/widgets/
```

### 2. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  provider: ^6.0.5
  window_manager: ^0.3.5  # For desktop apps
  package_info_plus: ^8.0.0

# Add fonts
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

### 3. Apply Theme

```dart
// main.dart
import 'theme/app_theme.dart';
import 'services/settings_service.dart';

MaterialApp(
  theme: AppTheme.lightTheme(accentColor),
  darkTheme: AppTheme.darkTheme(accentColor),
  // ...
)
```

### 4. Start Building!

Read [Getting_Started.md](./Getting_Started.md) for detailed instructions.

---

## 📐 Core Design Principles

### 1. **8px Grid System**
All spacing uses multiples of 8:
- xs: 8px
- sm: 12px  
- md: 16px
- lg: 24px
- xl: 32px

### 2. **Consistent Border Radius**
- Cards: 12px
- Inputs/Buttons: 8px
- Avatars/Icons: Variable

### 3. **Semantic Color Usage**
- Primary: Brand/Accent actions
- Surface: Cards, dialogs, headers
- Background: Main app background
- Text: Three levels (Primary, Secondary, Tertiary)

### 4. **Roboto Typography**
- Display: 30/24/20px (Bold/SemiBold)
- Headline: 18/16px (SemiBold)
- Body: 16/14/12px (Regular)

### 5. **Smooth Animations**
- Standard: 150ms with easeOutCubic
- Complex: 250ms with easeInOut
- Delays: 300-500ms for auto-hide

---

## 🎯 Common Use Cases

### Building a Settings Page
```dart
// Use AboutCard for app info
const AboutCard()

// Use _buildCard helper for sections
_buildCard(
  context,
  title: 'Section',
  icon: Icons.settings,
  children: [...],
)
```

### Creating Cards
```dart
// Use CollapsibleCard for expandable sections
CollapsibleCard(
  title: 'Advanced Options',
  status: CardStatus.configured,
  collapsedSummary: Text('Quick view'),
  expandedContent: DetailedSettings(),
)

// Use standard CardTheme for simple cards
Card(
  child: Padding(...),
)
```

### Showing Feedback
```dart
// Snackbars (theme configured)
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Success!')),
);

// Dialogs
showDialog(
  context: context,
  builder: (context) => AlertDialog(...),
);
```

---

## 🎨 Customization

### Changing Accent Color
```dart
// Per app or user preference
final accentColor = Color(0xFF6366F1);  // Indigo
final accentColor = Color(0xFFEC4899);  // Pink
final accentColor = Color(0xFF10B981);  // Green
```

### Extending the System
1. Add new colors to `AppColors`
2. Add new spacing to `AppSpacing`
3. Create new widgets following existing patterns
4. Document in `layout_and_components.md`

---

## 📦 Included Widgets

| Widget | Purpose | Documentation |
|--------|---------|---------------|
| CollapsibleCard | Expandable settings cards | layout_and_components.md |
| AboutCard | App information display | layout_and_components.md |
| AccentColorPicker | Color selection | (MyMeta specific) |
| CustomTitleBar | Desktop window controls | (MyMeta specific) |

---

## ✅ Quality Checklist

Before shipping your app, verify:

- [ ] All colors from `AppColors` (no hardcoded `Colors.blue`)
- [ ] All spacing from `AppSpacing` (no magic numbers)
- [ ] All text uses theme text styles
- [ ] Light AND dark themes tested
- [ ] Animations use specified curves and durations
- [ ] Cards use proper shadows
- [ ] Inputs use proper border radius
- [ ] Snackbars use theme styling

---

## 📚 Documentation Structure

```
design/
├── README.md                      ← You are here
├── Getting_Started.md             ← Step-by-step setup
├── colors.md                      ← Color palette
├── typography.md                  ← Text styles
├── layout_and_components.md       ← Component specs
├── animation_improvements.md      ← Animation guide
├── prompt.md                      ← Quick checklist
├── fonts/
│   ├── Roboto-Regular.ttf
│   ├── Roboto-Medium.ttf
│   └── Roboto-Bold.ttf
└── [Status Reports]               ← Optional reading
```

---

## 🌟 Examples

### MyMeta (Reference Implementation)
The MyMeta app in this repository demonstrates:
- Complete theme integration
- All components in use
- Light/dark mode switching
- Custom title bar
- Settings page layout
- Professional polish

**Study These Files**:
- `lib/theme/app_theme.dart` - Complete theme
- `lib/pages/settings_page.dart` - AboutCard & card layout
- `lib/widgets/collapsible_card.dart` - Expandable cards
- `lib/widgets/custom_titlebar.dart` - Header with theme toggle

---

## 🆘 Troubleshooting

### Colors look wrong
- Ensure you're using `AppColors.lightX` or `AppColors.darkX`
- Check `Theme.of(context).brightness` for theme detection

### Spacing inconsistent
- Use `AppSpacing.md` etc, not hardcoded pixels
- Follow 8px grid: 8, 12, 16, 24, 32, 48, 64

### Fonts not showing
- Verify `pubspec.yaml` has font declarations
- Run `flutter pub get`
- Clean and rebuild

### Theme not applying
- Check MaterialApp has `theme` and `darkTheme`
- Ensure `SettingsService` provides `themeMode`
- Wrap app in `Provider` if using state management

---

## 📄 License

This design system is part of the MyMeta project.  
Feel free to use in your own projects!

---

## 🤝 Contributing

Found an improvement? Document it!

1. Update relevant `.md` file
2. Add example code
3. Test in both themes
4. Document in RECENT_UPDATES.md

---

**Version**: 1.0.0  
**Last Updated**: 2025-12-20  
**Status**: ✅ Production Ready  
**Quality**: 🌟 Professional
