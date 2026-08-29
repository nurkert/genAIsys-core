[Home](../README.md) > [Architecture](./README.md) > UI Design System

# UI Design System Standards (Desktop)

Status: Mandatory
Scope: `lib/ui/**` and desktop shell surfaces
Audience: Product UI designers and frontend engineers

---

## 1. Intent and Quality Bar

This document defines non-optional UI standards for Genaisys desktop.
The goals are:
- visual consistency across features and teams,
- predictable implementation rules for engineers,
- production-grade quality with explicit measurable constraints.

All new UI work must follow this sheet unless a documented exception is approved in an ADR.

## 2. Mandatory System Architecture

- UI geometry and shell tokens must be centralized in `lib/ui/desktop/theme/ui_chrome_config.dart`.
- Motion tokens must be centralized in `lib/ui/desktop/theme/ui_motion_config.dart`.
- Platform corner profiles must be centralized in `lib/ui/desktop/theme/platform_corner_profile.dart`.
- Color and metal palettes must be centralized in `lib/ui/desktop/theme/metal_palette.dart`.
- Theme-level component defaults must be centralized in `lib/ui/desktop/theme/saas_theme.dart`.
- Shell orchestration must stay thin in `lib/ui/desktop/widgets/desktop_scaffold.dart`.
- Shell-local interaction state must live in a controller (`lib/ui/desktop/controllers/**`), not in deeply nested widget trees.
- Widget-level hard-coded geometry values are forbidden unless temporary and tagged with a TODO + ticket id.

## 3. Spacing System (8pt Core)

Base unit: `4px`
Primary rhythm: multiples of `8px`

Allowed spacing scale:
- `4, 8, 12, 16, 20, 24, 32, 40, 48`

Usage rules:
- Inner component spacing: `8/12/16`
- Panel/card padding: `16/20/24`
- Page-level gutters and section spacing: `24/32`
- Avoid arbitrary values (`7`, `13`, `19`, etc.).

## 4. Radius System

Mandatory radius tokens:
- `controlRadius`: small interactive controls
- `cardRadius`: card and tile surfaces
- `sidebarRadius`: sidebars and dock-like surfaces
- `panelRadius`: main content shell

Rule:
- New components must use tokenized radii only.
- Radius values must not diverge per feature branch.

## 5. Border, Stroke, and Shadow Rules

- Default border width: `1px`
- Strong border: `1.5px` max
- Hairline/divider: theme divider token only

Shadow policy:
- Use minimal elevation shadows for main surfaces only.
- No decorative glow shadows as default style.
- Glows are allowed only for explicit highlight states and must be subtle.

## 6. Layout Grid and Structure

Desktop layout must be composed from these regions:
- Left sidebar (hide/show)
- Main content panel (primary workflow)
- Right sidebar (hide/show, independent from left)

Core behaviors:
- Left sidebar supports hide/show.
- Right sidebar supports hide/show.
- If both sidebars are hidden, main panel expands to full width.
- In full-width mode, non-essential outer framing is minimized.

## 7. Width and Insets

Tokenized widths only:
- Left expanded width
- Right expanded width

Window/content insets:
- Outer window inset and inter-panel gaps must use centralized tokens.

## 8. Canonical Desktop Token Baseline

The current shell baseline is intentionally explicit and versioned through code:

- `windowInset = 14`
- `panelGap = 14`
- `leftSidebarExpandedWidth = 238`
- `rightSidebarWidth = 292`
- `panelRadius = 20`
- `sidebarRadius = 18` (base token, platform profile can override effective visual radius)
- `cardRadius = 16`
- `controlRadius = 12`
- `topBarHeightMac = 32`
- `topBarHeightDesktop = 40`
- `topBarLeadingInsetMac = 84`
- `topBarLeadingInsetMacFullscreen = 6`
- `topBarLeadingInsetDesktop = 6`
- `panelPadding = 22`

Platform corner profile baseline:
- macOS: `mainTopRadius = 26`, `sidebarRadius = 20`
- Windows: `mainTopRadius = 8`, `sidebarRadius = 8`
- Linux: `mainTopRadius = 8`, `sidebarRadius = 8`

Any change to these values requires:
- token-file update in `ui_chrome_config.dart` or `platform_corner_profile.dart`,
- widget test updates where behavior/geometry contracts changed,
- brief rationale in PR notes.

## 9. Typography Rules

Use theme typography only.
Do not set ad-hoc font sizes in feature widgets unless unavoidable.

Minimum text hierarchy:
- Page title: `headlineSmall`
- Section title: `titleLarge`
- Card title: `titleMedium`
- Body text: `bodyMedium`
- Control labels: `labelLarge`

Text behavior:
- Truncate with ellipsis for constrained areas.
- Avoid multi-line overflow in headers and nav labels.

## 10. Color and Metallic Language

Metallic style must be material-like, not neon.

Allowed semantic metals:
- Silver/platinum for neutral status and structural accents
- Gold for premium/priority emphasis
- Bronze/copper for secondary warm emphasis

Rules:
- Main content surfaces stay solid and high-contrast.
- Transparency is limited to designated shell surfaces (sidebar zones).
- Maintain strong readability in both light and dark modes.

## 11. Interaction and States

All interactive elements must define:
- default,
- hover,
- pressed,
- focused,
- disabled,
- selected (if applicable).

Keyboard:
- focus ring must be visible,
- tab order must match visual order,
- all primary actions must be keyboard reachable.

## 12. Motion and Animation

Animation durations:
- quick micro transitions: `120-160ms`
- panel/sidebar transitions: `200-260ms`

Easing:
- use standard easing curves (`easeOutCubic` or theme equivalents)

Rules:
- animation must support reduced complexity (no distracting perpetual motion)
- no ornamental animations without interaction value.

## 13. Component Contracts

Buttons:
- min height `44`
- tokenized radius
- icon+label layouts must remain overflow-safe

Inputs:
- tokenized border radius and paddings
- clear focus state with theme focus color

Cards/Panels:
- tokenized padding and radius
- no per-widget random shadow tuning

Sidebars:
- explicit controls for hide/show
- hidden sidebars must be restorable via persistent top-level controls

## 14. Accessibility and Contrast

- Follow WCAG AA contrast targets.
- Do not rely on color alone to communicate state.
- Ensure hit targets are practical on desktop pointer and keyboard workflows.

## 15. Implementation Rules for Engineers

- Never import third-party window/runtime packages directly in UI widgets.
- Use service interfaces for platform/window behavior.
- Keep UI independent from CLI process concerns.
- Keep core domain independent from UI presentation concerns.
- Keep user-facing copy centralized in localization modules; no feature-level hardcoded strings.

Layering contract:
- `lib/core/**` must not import Flutter UI/runtime packages.
- `lib/ui/**` must not import `window_manager`, `flutter_acrylic`, or `desktop_multi_window`.
- `lib/desktop/services/**` is the only allowed adapter zone for desktop window packages.
- UI feature widgets depend on interfaces/controllers; they do not own orchestration business logic.

Window role contract:
- `project_workspace` is project-scoped and must display a centered project name in top chrome.
- `project_hub` owns project selection, new-project flows, and global settings entry points.
- `settings_workspace` reuses workspace shell structure, keeps left sidebar fixed visible, and omits right sidebar.
- App-global settings must open as a dedicated `settings_workspace` window.

## 16. Review Checklist (PR Gate)

Every UI PR must answer yes to all:
- Are spacing/radius/width values tokenized?
- Are both light and dark mode validated?
- Are sidebar state transitions functional and recoverable?
- Is overflow checked at constrained desktop widths?
- Are keyboard focus paths working?
- Are analyzer and widget tests green?

If any item is "no", the PR is not ready.

## 17. Change Management

When adding or changing design tokens:
- update central token file first,
- update this standards doc,
- include before/after screenshots in PR,
- add/adjust widget tests for affected layout states.

---

## Related Documentation

- [GUI Architecture](gui-architecture.md) — Full widget tree and state management design
- [GUI Development Guide](gui-development-guide.md) — Step-by-step patterns for GUI work
- [UI Engineering Guardrails](ui-engineering-guardrails.md) — Boundary rules and regression gates
- [UI Visual Identity](ui-visual-identity.md) — Premium White & Bronze palette
