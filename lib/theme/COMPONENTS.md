# MyMeta Design System - Component Library

## Status Indicators

### Circular Badge (Compact)
Use for inline status indicators on list items.

```dart
Container(
  padding: const EdgeInsets.all(6),
  decoration: BoxDecoration(
    color: AppColors.lightSuccess.withOpacity(0.15),
    shape: BoxShape.circle,
  ),
  child: Icon(
    Icons.check,
    size: 16,
    color: AppColors.lightSuccess,
  ),
)
```

**States:**
- ✅ Success: Green check
- ⚠️ Warning: Orange warning
- ❌ Error: Red X

---

## Cards

### Standard Card
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
    border: Border.all(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      width: 1,
    ),
    boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow,
  ),
  padding: const EdgeInsets.all(AppSpacing.lg),
  child: content,
)
```

### Interactive Card (with hover)
```dart
Card(
  elevation: isHovered ? 2 : 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
    side: BorderSide(
      color: isSelected 
          ? Theme.of(context).colorScheme.primary 
          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      width: isSelected ? 2 : 1,
    ),
  ),
  child: content,
)
```

---

## Buttons

### Primary Button
```dart
ElevatedButton.icon(
  onPressed: onTap,
  icon: Icon(Icons.check),
  label: Text("Confirm"),
  style: ElevatedButton.styleFrom(
    backgroundColor: settings.accentColor,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  ),
)
```

### Secondary Button
```dart
OutlinedButton.icon(
  onPressed: onTap,
  icon: Icon(Icons.edit),
  label: Text("Edit"),
  style: OutlinedButton.styleFrom(
    foregroundColor: Theme.of(context).colorScheme.primary,
    side: BorderSide(color: Theme.of(context).colorScheme.primary),
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
)
```

### Destructive Button (Text style)
```dart
TextButton.icon(
  onPressed: onDelete,
  icon: Icon(Icons.delete_outline, size: 18),
  label: Text("Delete"),
  style: TextButton.styleFrom(
    foregroundColor: AppColors.lightDanger,
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
)
```

---

## Support / Donation Section

```dart
Container(
  padding: const EdgeInsets.all(AppSpacing.md),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Theme.of(context).colorScheme.primary.withOpacity(0.1),
        Theme.of(context).colorScheme.secondary.withOpacity(0.05),
      ],
    ),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
    ),
  ),
  child: Column(
    children: [
      Row(children: [
        Icon(Icons.favorite, color: Colors.red, size: 20),
        SizedBox(width: AppSpacing.sm),
        Text('Support Development', style: titleStyle),
      ]),
      SizedBox(height: AppSpacing.sm),
      Text('Your description here...'),
      SizedBox(height: AppSpacing.md),
      OutlinedButton.icon(
        onPressed: () { /* open link */ },
        icon: Icon(Icons.volunteer_activism, size: 18),
        label: Text('Donate via PayPal'),
      ),
    ],
  ),
)
```

---

## File/Item Row Pattern

```dart
Row(
  children: [
    // Expand Icon
    Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right),
    
    // Status Badge (compact)
    if (hasStatus)
      CircularStatusBadge(status: status),
    
    // Thumbnail
    if (hasThumbnail)
      ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
        child: Image.memory(thumbnail, width: 40, height: 60, fit: BoxFit.cover),
      ),
    
    // Content
    Expanded(child: Column(children: [title, subtitle])),
    
    // Actions
    IconButton(icon: Icon(Icons.cloud_download_outlined), tooltip: "Search"),
    IconButton(icon: Icon(Icons.close), tooltip: "Remove"),
  ],
)
```

---

## Typography

| Style | Usage |
|-------|-------|
| `displayLarge` | Page titles, hero text |
| `displayMedium` | Section headers |
| `displaySmall` | Card titles |
| `headlineMedium` | Subsection headers |
| `bodyLarge` | Primary content |
| `bodyMedium` | Standard text |
| `bodySmall` | Captions, hints |
| `labelLarge` | Button text |

---

Built with Flutter ❤️
