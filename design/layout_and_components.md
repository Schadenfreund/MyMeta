# Layout & Components

## Spacing System
The application uses a strict **8px grid system**.
| Token | Size | Use Case |
|-------|------|----------|
| `xs` | 8.0 | Minimal separation, internal component padding |
| `sm` | 12.0 | Standard input padding, tight grouping |
| `md` | 16.0 | Standard component padding, card padding |
| `lg` | 24.0 | Section separation, large card padding |
| `xl` | 32.0 | Major section breaks |
| `2xl` | 48.0 | - |
| `3xl` | 64.0 | - |

## UI Constants & Dimensions
- **Tab Bar Height**: 65px (Container), 44px (Individual Tab)
- **Top Header Height**: ~60px (Auto-sized based on content)
- **Top Header Icon Size**: 30px (Rounded corners)
- **Bottom Nav Height**: 56px
- **Max Content Width**: 1200px (Desktop centered)
- **Card Padding**: `20px` (Regular), `24px` (Large/Lg)
- **List Item Height**: `200-300px` (Variable)
- **Dialog Widths**: Min 300px, Max 600px

---

## 1. App Header (Top Fixed)
The header is always visible and provides window controls and global context.

**Container Style:**
- **Background**: `Surface` color.
- **Border**: Bottom 1px solid `Divider` color.
- **Shadow**: `BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2))`

**Content Layout (Row):**
- **Padding**: `symmetric(horizontal: 16, vertical: 12)`
- **Left**:
  - **App Icon**: 30x30 Container, `borderRadius: 7`. Shadow: black(alpha:0.1, blur 4, offset 0,2). Image or Gradient fallback.
  - **Gap**: 12px.
  - **Title**: Text "MyPay", 18px, `w700`, `letterSpacing: -0.5`, `height: 1.0`.
- **Spacer**
- **Right**:
  - **Filter Widgets** (if applicable).
  - **Theme Toggle**: Icon Rotation Animation (`RotationTransition`).
  - **Window Controls** (Desktop): Minimize, Maximize, Close.

---

## 2. Retractable Tab Bar
The navigation bar is **hidden by default** and overlays the content when hovering the header area.

**Interaction Logic (MouseRegion):**
- **Wrap**: Wrap the Header + TabBar column in a `MouseRegion`.
- **Enter**: Set state `_isTabBarExpanded = true`.
- **Exit**: Set state `_isTabBarExpanded = false`.

**Animation:**
- **Opacity**: 0.0 -> 1.0.
- **Slide**: `Offset(0, -0.3)` -> `Offset.zero`.
- **Duration**: `150ms`.
- **Curve**: `Curves.easeOutCubic`.

**Container Style:**
- **Background**: `Surface` color.
- **Border**: Bottom 1px `Divider` color.
- **Shadow**: Black (0.05 opacity), Blur 4, Offset 0,2.

**TabBar Widget Configuration:**
- `isScrollable`: **true**.
- `indicatorSize`: **TabBarIndicatorSize.label**.
- `indicatorWeight`: **3.0**.
- `indicator`: `UnderlineTabIndicator(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(width: 3, color: accentColor))`.
- `labelColor`: `accentColor`.
- `unselectedLabelColor`: `TextSecondary`.
- `overlayColor`: `accentColor.withOpacity(0.1)` (Hover state).
- `labelStyle`: 14px, `w600`.
- `unselectedLabelStyle`: 14px, `w500`.

**Tab Item:** `Row(Icon(18px), Gap(6px), Text(Label))`. Height: 44px.

---

## 3. Card Styles

### Standard Card (`CustomCard` / `CardTheme`)
- **Radius**: `12px`.
- **Border**: 1px solid `Border` color.
- **Background**: `Surface` color.
- **Shadow**:
  - **Light**: Black (alpha 0.05), Blur 10, Offset 0,4.
  - **Dark**: Black (alpha 0.3), Blur 16, Offset 0,8.

### Collapsible Card (`CollapsibleCard`)
Used for configuration/settings items.
- **Animation**: `AnimatedCrossFade`, 250ms, `Curves.easeInOut`.
- **Header**:
  - Padding: `24px` (Lg).
  - **Status Indicator** (Optional): Circle (32px) with Icon (18px). Colors: Green (Configured), Orange (Needs Attention), Grey (Unconfigured). Alpha 0.12 background.
  - **Title**: 20px, w600 (`displayLarge` color).
  - **Subtitle**: `fontSizeSm`, `bodySmall` color.
  - **Chevron**: `Icons.keyboard_arrow_down`, rotates 0.5 turns (180deg) when expanded.
- **Content**:
  - `collapsedSummary`: Padding Lg (bottom/sides).
  - `expandedContent`: Padding Lg (bottom/sides).

### About Card (`AboutCard`)
Used in Settings to display app info. uses Standard Card decoration.
- **Header**: Standard `CardHeader`.
- **Grid Layout**: 2x2 grid of "Info Tiles".
- **Info Tile**:
  - **Background**: `Colors.black.withValues(alpha: 0.03)` (Light) / `Colors.white.withValues(alpha: 0.05)` (Dark).
  - **Radius**: `8px` (`radiusMd`).
  - **Padding**: `16px` (`spacingMd`).
  - **Icon**: `iconMd`, `bodySmall` color.
  - **Text**: Label (`fontSizeXs`, `bodySmall`), Value (`fontSizeSm`, `w600`, `bodyMedium`).
- **Footer**:
  - Centered tagline with Heart Icon (`favorite_border`) in `AccentColor`.
  - Subtext in `fontSizeXs`.

---

## 4. Dialogs
- **Style**: Standard `AlertDialog` but content logic is often custom.
- **Title**: Text string.
- **Content**: `SingleChildScrollView` > `Form`.
- **Input Spacing**: `spacingMd` (16px) between fields.
- **Actions**: `TextButton` (Cancel) and `ElevatedButton` (Save/Primary).

## 5. Snackbars
- **Behavior**: `SnackBarBehavior.floating`.
- **Elevation**: 3.
- **Background**: `Surface` color (NOT black/inverse).
- **Shape**: RoundedRect `radius: 8`, Border `1px solid Border`.
- **Text**: `TextPrimary` color, `14px`.
- **Action Text**: `AccentColor`.

## 6. Input Fields
- **Decoration**: `filled: true`, `fillColor: Surface`.
- **Padding**: 12px all around.
- **Border**: OutlineInputBorder, Radius 8, BorderSide(color: Border).
- **Focused**: BorderSide(color: Primary, width: 2).
- **Labels**: `TextSecondary`, 14px.

---

## 7. Usage Examples

### Example 1: Settings Page Layout

```dart
Scaffold(
  backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
  body: ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      // Header
      Text('Settings', style: Theme.of(context).textTheme.displayMedium),
      const SizedBox(height: AppSpacing.xs),
      Text('Subtitle', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.lg),
      
      // Cards
      _buildCard(context, title: 'Section', icon: Icons.settings, children: [...]),
      const SizedBox(height: AppSpacing.md),
      const AboutCard(),
    ],
  ),
)
```

### Example 2: Card Helper Method

```dart
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
```

### Example 3: CollapsibleCard Usage

```dart
CollapsibleCard(
  title: 'Advanced Settings',
  subtitle: 'Configure advanced options',
  status: CardStatus.configured,
  collapsedSummary: Text(
    'API configured, 3 folders excluded',
    style: Theme.of(context).textTheme.bodySmall,
  ),
  expandedContent: Column(
    children: [
      TextField(decoration: InputDecoration(labelText: 'API Key')),
      const SizedBox(height: AppSpacing.md),
      ElevatedButton(onPressed: () {}, child: Text('Save')),
    ],
  ),
)
```

### Example 4: Using Snackbars

```dart
// Success message
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text('Settings saved successfully!'),
    duration: Duration(seconds: 2),
  ),
);

// With action
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Item deleted'),
    action: SnackBarAction(
      label: 'UNDO',
      onPressed: () {
        // Undo action
      },
    ),
  ),
);
```

### Example 5: Responsive Layout

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 800) {
      // Desktop: Two columns
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildLeftColumn()),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _buildRightColumn()),
        ],
      );
    } else {
      // Mobile: Single column
      return Column(
        children: [
          _buildLeftColumn(),
          const SizedBox(height: AppSpacing.lg),
          _buildRightColumn(),
        ],
      );
    }
  },
)
```

---

## 8. Best Practices

### DO ✅
- Use `AppColors` constants for all colors
- Use `AppSpacing` for all spacing values
- Use `AppDimensions` for sizes (radius, heights)
- Use theme text styles from `Theme.of(context).textTheme`
- Test both light and dark themes
- Follow the 8px grid system strictly
- Use `const` constructors where possible
- Apply shadows from `AppTheme.lightCardShadow` / `darkCardShadow`

### DON'T ❌
- Hardcode colors like `Color(0xFF123456)` or `Colors.blue`
- Use magic numbers like `16.0` instead of `AppSpacing.md`
- Mix different border radius values arbitrarily
- Ignore theme brightness (always check light/dark)
- Use different font families
- Create custom shadows without reason
- Forget to apply padding/spacing consistently

---

## 9. Quick Reference

| Element | Size/Value | Token |
|---------|-----------|-------|
| Card Radius | 12px | `AppDimensions.cardBorderRadius` |
| Input Radius | 8px | `AppDimensions.inputBorderRadius` |
| Header Height | 60px | `AppDimensions.headerHeight` |
| Tab Bar Height | 48px | `AppDimensions.tabBarHeight` |
| Card Padding | 24px | `AppSpacing.lg` |
| Section Gap | 16px | `AppSpacing.md` |
| Element Gap | 8px | `AppSpacing.xs` |
| Title Size | 30px | `displayLarge` |
| Body Size | 14px | `bodyMedium` |
| Small Text | 12px | `bodySmall` |

---

**For complete color and typography references, see:**
- [colors.md](./colors.md) - Full color palette
- [typography.md](./typography.md) - Text style definitions
- [animation_improvements.md](./animation_improvements.md) - Animation specs
