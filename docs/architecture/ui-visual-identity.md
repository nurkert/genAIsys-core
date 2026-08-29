[Home](../README.md) > [Architecture](./README.md) > UI Visual Identity

# Premium White & Bronze Visual Identity

This document defines the active UI identity for desktop shells while keeping existing windowing architecture untouched.

---

## Core Palette

| Token | Value | Usage |
|-------|-------|-------|
| App background | `#F5F5F7` | Window background behind all panels |
| Surface | `#FFFFFF` | Card and content surfaces |
| On-surface text | `#333333` | Primary text color |
| Primary bronze | `#A87B50` | Fallback flat bronze accent |
| Bronze gradient | `#8E5C3A` → `#D4AF37` → `#B47A4F` | Top-left to bottom-right on buttons and accents |

## Glassmorphism

| Property | Value |
|----------|-------|
| Sidebar glass blur | `sigmaX=10`, `sigmaY=10` |
| Sidebar glass color (light) | `rgba(255,255,255,0.70)` |
| Sidebar glass color (dark) | `rgba(31,27,24,0.35)` |

## Depth

| Shadow | Value |
|--------|-------|
| Soft shadow | `rgba(0,0,0,0.05)` with `blur=20`, `spread=0`, `offset=(0,4)` |
| Applied to | Cards, bronze CTA surfaces, active navigation highlights |

## Component Rules

- **BronzeButton**: Bronze gradient fill, subtle chamfer border, white bold text.
- **Active sidebar item**: Bronze gradient pill with soft glow.
- **Cards**: White surface, soft border, soft shadow.
- **Charts**:
  - Line series uses bronze gradient.
  - Under-line area fades bronze to transparent.
  - Progress ring uses light gray track and bronze gradient active arc.

## Source of Truth

All theme and visual constants are centralized in:

- `lib/ui/desktop/theme/premium_white_bronze_tokens.dart`
- `lib/ui/desktop/theme/saas_theme.dart`

---

## Related Documentation

- [UI Design System](ui-design-system.md) — Spacing, radius, layout, and motion standards
- [GUI Architecture](gui-architecture.md) — Token system hierarchy and component architecture
- [GUI Development Guide](gui-development-guide.md) — How to add new tokens and components
