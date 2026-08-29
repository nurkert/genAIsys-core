[Home](../README.md) > [Architecture](./README.md) > UI Engineering Guardrails

# UI Engineering Guardrails

This document defines mandatory desktop UI engineering rules for long-term consistency.

---

## 1) Third-Party Decoupling (Mandatory)

- UI widgets (`lib/ui/**`) must never import volatile 3rd-party platform packages directly.
- Package integrations (for example `window_manager`, `flutter_acrylic`, `desktop_multi_window`) must be isolated in service adapters under `lib/desktop/services/**`.
- Widgets can depend only on interfaces/contracts (for example `WindowServiceInterface`).
- If a package is replaced, only adapter implementations may change; UI files must remain untouched.

## 2) Centralized Visual Tokens (Mandatory)

- Radius, spacing, panel widths, and shell geometry must be defined in one central config.
- Current source of truth: `lib/ui/desktop/theme/ui_chrome_config.dart`.
- Platform corner strategy source of truth: `lib/ui/desktop/theme/platform_corner_profile.dart`.
- Motion timing/easing source of truth: `lib/ui/desktop/theme/ui_motion_config.dart`.
- Hard-coded geometry values in widgets are not allowed unless explicitly documented as temporary.

## 3) Shell Layout Rules

- Left sidebar supports full hide/show.
- Right sidebar visibility is independently toggleable.
- If both sidebars are hidden, the main content must expand to full window width.
- In full-width mode, decorative outer framing should be minimized or removed.
- Main content bottom edge stays flush with window bottom; sidebars may keep dedicated bottom inset.

## 4) UI Module Boundaries

- Desktop shell orchestration only: `lib/ui/desktop/widgets/desktop_scaffold.dart`.
- Ephemeral shell state: `lib/ui/desktop/controllers/desktop_shell_controller.dart`.
- Shell widgets: `lib/ui/desktop/widgets/shell/**`.
- Mock content/model contracts: `lib/ui/desktop/data/**`, `lib/ui/desktop/models/**`.
- Window/runtime integration stays behind `WindowServiceInterface` in `lib/desktop/services/**`.

## 5) Transparency Rules

- Transparency should be intentional and limited to designated surfaces.
- Main content must remain solid/readable in light and dark mode.
- Do not add global blur/glow effects by default.

## 6) Change Safety

- Any change to shell structure must include at least one widget/integration assertion covering:
  left sidebar hidden state, right sidebar hidden state, and both sidebars hidden full-width behavior.
- Mandatory regression target for shell interactions: `test/widget_test.dart`.

## 7) Boundary Regression Gates

- Use architecture tests as release gates for layering discipline.
- Mandatory boundary checks currently live in:
  - `test/core/architecture_imports_test.dart`
  - `test/core/ui_architecture_boundaries_test.dart`
- Any new adapter package integration requires a matching boundary test update in the same change.

## 8) Localization Boundary (Mandatory)

- User-facing copy must not be hardcoded in feature widgets.
- Centralized copy source for desktop: `lib/ui/desktop/localization/desktop_strings.dart`.
- Runtime language state for desktop: `lib/ui/desktop/localization/desktop_localization.dart`.
- Widgets must read strings through localization scope/context extension, never via scattered constants.

## 9) Window Role Boundary (Mandatory)

- Desktop must treat windows as explicit roles, not one generic UI shell.
- Current mandatory roles:
  - `project_workspace`: project-scoped execution window.
  - `project_hub`: project selection/new-project/global-settings window.
  - `settings_workspace`: global settings window using the shared workspace shell.
- Role parsing source: `lib/ui/desktop/models/desktop_window_mode.dart`.
- App entry wiring source: `lib/main.dart` (`GENAISYS_WINDOW_MODE`, `GENAISYS_PROJECT_NAME`) plus subwindow launch payload parsing.
- Settings entry contract:
  - macOS app menu path: `Genaisys > Settings` with `Cmd+,`
  - Windows/Linux in-window menu path: `Genaisys > Settings` with `Ctrl+,`
  - Opening settings must create/focus the dedicated `settings_workspace` window via `WindowServiceInterface.openGeneralSettingsWindow()`.
  - Sidebar `Settings` inside project workspace is reserved for project-scoped settings, not application-global settings.
  - `settings_workspace` must use a dedicated app-settings sidebar taxonomy and must not reuse project-workspace nav sections.
  - Global shortcut handling is wired in `DesktopSaasApp` and must remain active across window roles.
- Project hub/startup contract:
  - Startup default role is `project_hub` unless a valid last-opened project is available.
  - Last-opened project and hub project list persistence must be handled in core storage (`lib/core/settings/project_registry*`) and never in ad-hoc widget state.
  - Opening a project from hub must go through `WindowServiceInterface.openProjectWorkspaceWindow(...)`.
  - UI widgets must not directly invoke `desktop_multi_window`; all subwindow creation stays in `ProductionWindowService`.

## 10) Workspace Composition Rules (Mandatory)

- Primary section routing must stay centralized in `lib/ui/desktop/widgets/shell/main_content_panel.dart`.
- Shared workspace title/subtitle chrome must use the reusable header component:
  `lib/ui/desktop/widgets/shell/workspaces/workspace_header.dart`.
- Section widgets should avoid duplicating shell-level decoration and spacing logic.
- Responsive breakpoints must live inside section widgets and degrade to stacked layouts before overflow.

## 11) CLI JSON Test Stability (Mandatory)

- CLI JSON contract tests must invoke Dart with `--verbosity=error` to suppress toolchain noise that can corrupt payload parsing.
- JSON extraction in tests must use `test/core/support/cli_json_output_helper.dart` instead of ad-hoc line parsing.
- Any new `--json` CLI test should validate against decoded JSON payloads, not raw string equality.

---

## Related Documentation

- [GUI Architecture](gui-architecture.md) — Full widget tree and state management design
- [GUI Development Guide](gui-development-guide.md) — Step-by-step patterns for GUI work
- [UI Design System](ui-design-system.md) — Token values, spacing rules, PR checklist
- [UI Visual Identity](ui-visual-identity.md) — Premium White & Bronze palette
- [Architecture Overview](overview.md) — 3-layer architecture and dependency rules
