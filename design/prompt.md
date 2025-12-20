# App Creation Prompt (Design System)

You are an expert Flutter developer. Build a new application that matches the **MyPay** design system exactly.

## 1. Design Source of Truth
- **`colors.md`**: Exact Hex codes.
- **`typography.md`**: Exact text sizes/weights (Roboto).
- **`layout_and_components.md`**: The strict blueprint for all widgets.

## 2. Critical Implementation Checklist

### A. The "Signature" Navigation
- **Fixed Header**: 60px height, Surface color, specific shadow (Alpha 0.05).
- **Retractable Tab Bar**: MUST use `MouseRegion` to expand. Hidden by default (`Opacity 0`, `Slide -0.3`).
- **Tabs**: Compact height (44px), Icon+Text, Label Indicator (width 3, radius 2).

### B. Cards & Structure
- **Global**: `BorderRadius.circular(12)`, 1px Border, specific BoxShadows (Light: 5% opacity, Dark: 30%).
- **Collapsible Cards**: Implement `CollapsibleCard` widget.
  - Header: Status Icon (Green/Orange) + Title + Subtitle + Rotating Chevron.
  - Body: CrossFade between Summary and Expanded Content.
- **About Card**: You MUST implement the `AboutCard` as described in layout docs (Info Tiles grid, specific footer tagline).

### C. Feedback & Interactivity
- **Inputs**: Filed (Surface color), 1px border, 2px Primary focus border.
- **Snackbars**: Floating, Surface background (not black), with border.
- **Dialogs**: Standard AlertDialogs with Form inputs.

## 3. Mandatory Setup
1.  **Dependencies**: `google_fonts`, `window_manager`, `provider`.
2.  **Theme**: Create `AppTheme` class. Static getters for `lightCardDecoration` / `darkCardDecoration`.
3.  **Widgets**:
    - `AppHeader`
    - `HoverRevealTabBar`
    - `CollapsibleCard`
    - `AboutCard` (Copy the specific design: Info Tiles, Heart Icon Footer).

## 4. Fonts
**Roboto**. Title: w700. Body: w400. Labels: w500.

**Goal**: The app must be a pixel-perfect clone of the "MyPay" aesthetic.
