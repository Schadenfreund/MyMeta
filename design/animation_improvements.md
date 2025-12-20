# Animation & Interaction Improvements

This document captures learnings from implementing the MyMeta design system, particularly focusing on smooth animations and interactions.

## Retractable Tab Bar - Smooth Hover Interaction

### Problem Solved
The initial implementation had jerky animations when the mouse quickly entered and exited the tab bar trigger area.

### Solution Implemented

#### 1. **Delayed Hide with Timer**
```dart
Timer? _hideTimer;

void _showTabBar() {
  _hideTimer?.cancel();  // Cancel any pending hide
  if (!_tabbarVisible) {
    setState(() {
      _tabbarVisible = true;
    });
  }
}

void _scheduleHideTabBar() {
  _hideTimer?.cancel();  // Cancel previous timer
  _hideTimer = Timer(const Duration(milliseconds: 300), () {
    if (mounted) {
      setState(() {
        _tabbarVisible = false;
      });
    }
  });
}
```

**Why This Works:**
- **Immediate Show**: When mouse enters, tab bar appears instantly (good responsiveness)
- **Delayed Hide**: 300ms delay before hiding prevents flicker when mouse briefly exits
- **Timer Cancellation**: Each new event cancels previous timers, preventing stacked delays
- **Mounted Check**: Prevents setState on disposed widgets

#### 2. **Larger Trigger Area**
```dart
Container(
  height: _tabbarVisible ? 0 : 30,  // 30px instead of 20px
  color: Colors.transparent,
)
```

**Benefits:**
- Easier to trigger tab bar appearance
- Less precision needed from user
- Feels more forgiving and natural

#### 3. **Proper Animation Curves**
```dart
AnimatedSlide(
  duration: const Duration(milliseconds: 150),
  curve: Curves.easeOutCubic,  // Smooth deceleration
  offset: _tabbarVisible ? Offset.zero : const Offset(0, -0.3),
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 150),
    curve: Curves.easeOutCubic,
    opacity: _tabbarVisible ? 1.0 : 0.0,
    // ...
  ),
)
```

### Best Practices Learned

1. **Always use Timer for exit delays** on retractable UI elements
2. **Cancel timers** in both show/hide functions and dispose()
3. **Check mounted** before setState in async callbacks
4. **Use easeOutCubic** for smooth, natural feeling animations
5. **Trigger on header hover only** - no separate trigger areas to prevent flickering
6. **Wrap both header AND tab bar** in MouseRegion to keep visibility while interacting
7. **Use IgnorePointer** when hidden to prevent interference with content below
8. **Full slide offset (-1.0)** for complete hiding without visual artifacts

### Preventing Jerky Animation

**Problem**: Initial implementation had a separate 50px trigger area that caused the tab bar to flicker and shake.

**Solution**:
```dart
// ✅ CORRECT: Hover detection on header only
MouseRegion(
  onEnter: (_) => _showTabBar(),
  onExit: (_) => _scheduleHideTabBar(),
  child: const CustomTitleBar(),
),

// ✅ CORRECT: Also wrap tab bar to stay visible while using it
Positioned(
  top: 0,
  child: MouseRegion(
    onEnter: (_) => _showTabBar(),
    onExit: (_) => _scheduleHideTabBar(),
    child: AnimatedSlide(
      offset: _tabbarVisible ? Offset.zero : const Offset(0, -1.0),
      child: IgnorePointer(
        ignoring: !_tabbarVisible,
        // ... tab bar content
      ),
    ),
  ),
),

// ❌ WRONG: Separate trigger area causes flicker
Container(
  height: 50, // DON'T DO THIS
  color: Colors.transparent,
)
```

**Why This Works**:
- No intermediate trigger zones that can cause state conflicts
- Tab bar stays visible while mouse is over it
- Smooth entry/exit without fighting between regions
- IgnorePointer prevents hidden tab bar from blocking clicks

### Key Timing Values

| Action | Duration | Rationale |
|--------|----------|-----------|
| Show Animation | 150ms | Fast enough to feel instant, slow enough to be smooth |
| Hide Animation | 150ms | Matches show for consistency |
| Hide Delay | 500ms | Long enough to prevent accidental hiding during navigation |
| Slide Offset | -1.0 | Completely hides the tab bar off-screen |
| Trigger Method | Header hover only | Prevents flicker from intermediate trigger zones |

## Header Icon Shadow

The header app icon benefits from a subtle shadow for depth:

```dart
Container(
  width: 30,
  height: 30,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(7),
    image: DecorationImage(...),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
)
```

**Why:** Creates visual hierarchy and makes the icon feel like it's "above" the surface.

## TabBar Configuration

Using Material TabBar widget provides better UX than custom implementation:

```dart
TabBar(
  controller: _tabController,
  isScrollable: true,  // Prevents stretching
  indicatorSize: TabBarIndicatorSize.label,  // Indicator only under text
  indicatorWeight: 3.0,  // Visible but not overwhelming
  indicator: UnderlineTabIndicator(
    borderRadius: BorderRadius.circular(2),  // Soft corners
    borderSide: BorderSide(width: 3, color: accentColor),
  ),
  overlayColor: WidgetStateProperty.all(accentColor.withOpacity(0.1)),  // Subtle hover
  // ...
)
```

**Benefits:**
- Built-in gesture handling
- Smooth indicator animation
- Proper accessibility support
- Less custom code to maintain

## General Animation Principles

1. **Duration sweet spot**: 150-200ms for most UI animations
2. **Consistency**: Use same duration for related show/hide animations
3. **Curves**: easeOutCubic for natural deceleration
4. **Delays**: 300-500ms for intentional delays (like auto-hide)
5. **Opacity + Transform**: Combine for richer animations (fade + slide)

## Testing Checklist

When implementing retractable elements:

- [ ] Mouse enter triggers immediately
- [ ] Mouse exit has appropriate delay
- [ ] Rapid enter/exit doesn't cause flicker
- [ ] Timer is cancelled on dispose
- [ ] Mounted check before async setState
- [ ] Animation feels smooth at 60fps
- [ ] Trigger area is generous enough
- [ ] Works well with mouse and trackpad

## Performance Notes

- Timer overhead is minimal (<1ms)
- AnimatedSlide and AnimatedOpacity are efficient
- Avoid rebuilding heavy widgets in animation
- Use const constructors where possible

---

**Last Updated**: Based on MyMeta implementation (2025-12-20)
