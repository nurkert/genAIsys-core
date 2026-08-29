[Home](../README.md) > [Architecture](./README.md) > GUI Architecture

# GUI Architecture Reference

Status: Living Document
Scope: `lib/ui/**`, `lib/desktop/**`, `lib/main.dart`
Audience: Engineers, agents, and contributors working on the desktop GUI

> **Companion documents**:
> - [UI Design System Standards](./ui-design-system.md) -- token values, spacing rules, PR checklist
> - [UI Engineering Guardrails](./ui-engineering-guardrails.md) -- layering rules, boundary tests
> - [GUI Development Guide](./gui-development-guide.md) -- how to extend the GUI correctly

---

## 1. Architectural Overview

Genaisys uses a **layered desktop shell architecture** that separates platform integration, design tokens, state management, and widget composition into clearly bounded layers.

```
  lib/main.dart                        -- App bootstrap, window service resolution
  lib/desktop/                         -- Platform integration layer (no Flutter UI)
    services/                          -- Window service interface + adapters
    windowing/                         -- Window mode enum, launch context
  lib/ui/desktop/                      -- Flutter desktop UI
    theme/                             -- Design tokens, surface styles, motion config
    controllers/                       -- State management (controllers, isolate runners)
    models/                            -- UI presentation models
    localization/                      -- String definitions, locale management
    widgets/                           -- Widget tree
      common/                          -- Shared components (BronzeButton, GlassPanel, ...)
      shell/                           -- Shell layout (scaffold, top bar, sidebars)
        workspaces/                    -- Workspace views (dashboard, backlog, chat, ...)
```

### Dependency Direction (Strict)

```
  lib/core/         <-- Business logic (no Flutter imports)
       ^
       |
  lib/core/app/     <-- Use cases, DTOs, API contracts
       ^
       |
  lib/desktop/      <-- Platform adapters (window_manager, desktop_multi_window)
       ^
       |
  lib/ui/desktop/   <-- Flutter widgets, controllers, theme
```

UI and desktop layers may depend on `core/app/`. Core must never depend on UI or desktop.

---

## 2. Bootstrap and Window Management

### Entry Point (`lib/main.dart`)

The app boots with a critical design decision: `runApp()` is called **immediately** before any async initialization. This prevents macOS sub-window freeze caused by blocking `await` calls before the frame scheduler starts.

```
main(args)
  1. Parse WindowLaunchContext from process args
  2. Resolve WindowServiceInterface (Production or Noop)
  3. runApp(DesktopSaasApp(...))  <-- immediate, no awaits before this
     4. initState → post-frame callback → windowService.initialize()
     5. Hydrate settings, apply theme, create workspace controller
```

### Window Modes

| Mode                 | Role                     | Size       | Instance Count |
|----------------------|--------------------------|------------|----------------|
| `projectHub`         | Project launcher (root)  | 1060x680   | 1 (singleton)  |
| `projectWorkspace`   | Per-project editor       | 1440x920   | Multiple       |
| `settingsWorkspace`  | App-global settings      | 1320x860   | 1 (singleton)  |

**Multi-window architecture**: The `ProductionWindowService` uses `desktop_multi_window` for sub-window spawning. Sub-windows receive a `WindowLaunchContext` via process args as JSON payload. Inter-window messaging uses named methods (`genaisys.window.focus`, `genaisys.window.closed`).

### Window Service Abstraction

```
WindowServiceInterface (abstract)
  ├── ProductionWindowService  -- Real desktop (macOS/Windows/Linux)
  └── NoopWindowService        -- Web/test fallback
```

Key observable state exposed via `ValueNotifier`:
- `sidebarHidden` -- left sidebar visibility
- `fullscreen` -- fullscreen mode
- `windowFocused` -- native window focus (used to pause/resume polling)

---

## 3. Design Token System

The visual identity is managed through a **five-layer token hierarchy**:

### Layer 1: Color Tokens (`premium_white_bronze_tokens.dart`)

64+ semantic colors organized as:
- **Surface palette**: `surface`, `surfaceSoft`, `surfaceMuted`, `surfaceStrong`, `surfaceAccent` (+ dark variants)
- **Metal palette**: Bronze (dark/mid/highlight), Silver (light + dark mode variants)
- **Shell colors**: Sidebar surfaces, shell backgrounds, toggle controls
- **Procedural gradients**: `bronzeGradientFor(seed)`, `silverGradientFor(seed)` -- each seed produces a unique but cohesive gradient using HSL tone modulation
- **Shadow system**: `softSurfaceShadow`, `elevatedSurfaceShadow`, `bronzeGlow`, toggle shadows

### Layer 2: Geometry Tokens (`ui_chrome_config.dart`)

Central source of truth for all spatial values:
- **Spacing scale** (4pt base): `space4`, `space8`, `space12`, `space16`, `space20`, `space24`
- **Radius hierarchy**: `panelRadius: 20`, `sidebarRadius: 18`, `cardRadius: 16`, `controlRadius: 12`
- **Layout dimensions**: `leftSidebarExpandedWidth: 238`, `rightSidebarWidth: 292`, `windowInset: 14`, `panelGap: 14`
- **Platform-specific methods**: `topBarHeightFor(platform)`, `topInsetFor(platform)`

### Layer 3: Surface Styles (`ui_surface_styles.dart`)

Converts tokens into `BoxDecoration` and color values:
- **`DesktopSurfaceTone`** enum: `base`, `soft`, `muted`, `strong`, `accent`
- Factory methods: `panel()`, `pill()`, `shadow()`, `shellBackground()`, `sidebarSurface()`
- Theme-aware: auto-switches between light/dark based on `Theme.of(context).brightness`

### Layer 4: Motion Tokens (`ui_motion_config.dart`)

Standardized animation timing:
- `shellDuration: 230ms` / `shellCurve: easeOutCubic` -- sidebar expand/collapse
- `fadeDuration: 160ms` -- opacity transitions
- `fullscreenExpandDuration: 560ms` / `fullscreenCollapseDuration: 420ms` -- asymmetric (Apple-style)
- `fullscreenCurve: easeInOutCubic`

### Layer 5: Platform Profiles

- **`PlatformWindowControlsProfile`**: Resolves window control side (left on Mac, right on Windows) and inset values
- **`PlatformCornerProfile`**: Platform-specific corner radii (macOS: 26/20, Windows/Linux: 8/8)

---

## 4. State Management Architecture

### Controller Hierarchy

```
DesktopSaasApp (root widget)
  └── DesktopScaffold
       ├── DesktopShellController          -- Shell-level state (sidebar visibility, section selection)
       │    ├── selectedSection: ValueNotifier<DesktopPrimarySection>
       │    └── rightSidebarVisible: ValueNotifier<bool>
       │
       └── ProjectWorkspaceController      -- Project data coordinator
            ├── AutopilotController         -- Autopilot polling + status
            ├── TaskController              -- Task CRUD, backlog
            ├── ReviewController            -- Review decisions
            └── ProjectConfigController     -- Config persistence
```

### State Propagation: ValueNotifier Pattern

The GUI uses `ValueNotifier<T>` + `ValueListenableBuilder<T>` as the primary state mechanism instead of Riverpod or Bloc. This provides:

- **Scoped rebuilds**: Each `ValueListenableBuilder` only rebuilds its subtree when its specific value changes
- **Independent sections**: Left sidebar visibility, right sidebar visibility, and section selection trigger different rebuild scopes
- **No framework overhead**: Dart-native, zero dependencies

Example rebuild isolation:
```dart
ValueListenableBuilder<bool>(              // Scope 1: left sidebar
  valueListenable: windowService.sidebarHidden,
  builder: (context, hidden, _) {
    return ValueListenableBuilder<bool>(   // Scope 2: right sidebar
      valueListenable: controller.rightSidebarVisible,
      builder: (context, visible, _) {
        return Row(children: [             // Only this row rebuilds
          AnimatedSidebarSlot(visible: !hidden, ...),
          Expanded(child: mainContent),
          AnimatedSidebarSlot(visible: visible, ...),
        ]);
      },
    );
  },
)
```

### Background Isolate Pattern

Heavy I/O (git subprocesses, file reads, status polling) runs in background isolates to keep the UI thread responsive:

```
Main Thread                           Background Isolate
    |                                      |
    |-- Isolate.run(fn) ------------------>|
    |                                      |-- Creates fresh InProcessGenaisysApi
    |                                      |-- Runs git/file operations
    |                                      |-- Returns sendable DTO result
    |<------ WorkspaceRefreshResult -------|
    |                                      (isolate ends)
    |-- Apply results to controllers
    |-- Fire ValueNotifiers
```

Key constraints:
- Top-level functions only (must be sendable across isolate boundary)
- Fresh API instance per isolate (no captured main-thread state)
- All return types composed of primitives, enums, Lists, Maps
- Graceful failure: spawn errors return empty result + error string, never block UI

### Polling Architecture

| Poller                     | Interval     | Paused When         |
|----------------------------|--------------|---------------------|
| Dashboard refresh          | 30s          | Window unfocused    |
| Autopilot status           | 1s (running) | Window unfocused    |
| Autopilot status (idle)    | 5s           | Window unfocused    |

Autopilot polling includes jitter (up to 500ms) to avoid thundering herd across multiple windows.

---

## 5. Shell Layout Architecture

### Widget Tree (Scaffold to Content)

```
DesktopScaffold (StatefulWidget)
  └── Column
       ├── SizedBox (platform-specific top inset)
       ├── ShellTopBar
       │    └── TweenAnimationBuilder<_TopBarInsets> (fullscreen inset animation)
       │         └── Row [sidebar toggles, project name, right toggle]
       ├── InWindowMenuBar (non-Mac only)
       ├── SizedBox(panelGap)
       └── Expanded
            └── _ShellBody (extracted StatelessWidget for rebuild isolation)
                 └── AnimatedPadding (responds to sidebar visibility)
                      └── Row
                           ├── AnimatedSidebarSlot (left, 238pt)
                           │    └── LeftSidebar → GlassPanel → ListView.separated
                           │         └── LeftSidebarItemButton (RepaintBoundary)
                           ├── AnimatedSidebarGap
                           ├── Expanded → MainContentPanel
                           │    └── IndexedStack (preserves tab state)
                           │         ├── DashboardWorkspaceView
                           │         ├── ChatWorkspaceView
                           │         ├── BacklogWorkspaceView
                           │         ├── ReportsWorkspaceView
                           │         ├── AutopilotWorkspaceView
                           │         └── ProjectSettingsWorkspaceView
                           ├── AnimatedSidebarGap
                           └── AnimatedSidebarSlot (right, 292pt)
                                └── RightSidebar → GlassPanel → AnimatedSwitcher
```

### Sidebar Visibility Model

- **Left sidebar**: Controlled via `WindowServiceInterface.sidebarHidden` ValueNotifier. Supports hidden/visible states. When hidden, the slot collapses to zero width with animation.
- **Right sidebar**: Controlled via `DesktopShellController.rightSidebarVisible`. Independent toggle.
- **Full-width mode**: When both sidebars hidden, all horizontal padding removed, content expands to window edges.

### AnimatedSidebarSlot

Handles sidebar show/hide animation as a reusable container:
- Width animated via `AnimatedContainer` (0 ↔ expanded width)
- `ClipRect` prevents content overflow during collapse
- `AnimatedOpacity` fades content during transition
- `IgnorePointer` when hidden (prevents ghost clicks)

---

## 6. Component Architecture

### Common Components (`lib/ui/desktop/widgets/common/`)

| Component               | Purpose                                                 |
|--------------------------|---------------------------------------------------------|
| `BronzeButton`           | Signature metallic button with texture + reflection     |
| `BronzeBrushTexturePainter` | CustomPainter for brushed-metal texture overlay      |
| `BronzeSpecularLight`    | Animated metallic reflection (drift + hover + press)    |
| `BronzeSwitch`           | Toggle switch with metallic styling                     |
| `BronzeGradientText`     | Text with bronze gradient shader                        |
| `GlassPanel`             | Semi-transparent panel with border radius               |
| `SettingsCard`           | Card container for settings forms                       |

### BronzeButton Composition Stack

Each `BronzeButton` is built from multiple layers for the metallic effect:

```
RepaintBoundary
  └── AnimatedScale (hover: 1.014, press: 0.987)
       └── AnimatedContainer (transform: Y offset, shadow modulation)
            └── BoxDecoration (bronzeGradientFor(seed), border)
                 └── CustomPaint(foregroundPainter: BronzeBrushTexturePainter)
                      └── Stack
                           ├── BronzeSpecularLight (animated reflection)
                           └── Row [Icon, Text] (white + embossed shadows)
```

**Seed-based uniqueness**: Each button derives its gradient seed from `label.hashCode`, ensuring visual variety while maintaining deterministic consistency across sessions.

### BronzeSpecularLight Animation System

Three parallel animation controllers create organic metallic behavior:
1. **Drift** (8.5-13.7s continuous loop): Multi-phase sinusoidal wandering for organic light movement
2. **Hover** (240ms): Smooth transition to hover state with reduced drift amplitude
3. **Press** (95ms): Fast response with compressed drift and reduced intensity

Physics parameters are seed-dependent, ensuring each element drifts at a unique speed and phase.

### Custom Painters

**BronzeBrushTexturePainter**: Pre-computes brush stroke segments once per size/seed, caches them, and iterates the cache on each paint call. `shouldRepaint()` only returns true when seed, strength, or borderRadius change.

---

## 7. Workspace Views

Each workspace tab follows a consistent structure:

```
WorkspaceView (StatefulWidget)
  └── Column
       ├── WorkspaceHeader (title, subtitle, seed for gradient)
       ├── [Optional: control strip, tab bar, filters]
       └── Expanded
            └── Content area (scrollable, responsive via LayoutBuilder)
```

### Responsive Design

Workspace views use `LayoutBuilder` for responsive breakpoints:
- **Wide mode** (>980px): Multi-column layouts, horizontal stat rows
- **Compact mode** (<980px): Stacked columns, vertical layout
- **Scroll fallback** (<760px height): Wraps in `SingleChildScrollView`

### Content Preservation

`MainContentPanel` uses `IndexedStack` with lazy building:
- Views only instantiated on first visit (tracked via `_visitedSections` set)
- Once built, widget tree stays in memory across tab switches
- Scroll positions, input focus, and animation states preserved

---

### Settings Workspace

`SettingsWorkspaceView` is the one workspace that is not hand-laid-out per field:

- **All settings** — generated from the config field registry, so it covers every scalar config
  key the engine knows about. A group rail narrows to one area; a search spans every group.
  Values are written through `ConfigRegistryService`, which edits `config.yml` with `YamlEditor`
  and therefore preserves comments and formatting.
- **Paths & allowlist** — the legacy `ProjectSettingsWorkspaceView`, retained for the
  list-valued settings the scalar registry cannot express.

See [GUI Development Guide](gui-development-guide.md) — *Settings Are Generated, Not Hand-Built*.

---

## 8. Localization Architecture

```
DesktopLocalizationController (ChangeNotifier)
  └── Manages: language enum → Locale + DesktopStrings
       └── DesktopLocalizationScope (InheritedNotifier)
            └── context.strings extension → access anywhere in widget tree
```

- **DesktopStrings**: 290+ string fields as immutable `static const` instance
- **Extension method**: `context.strings` for clean access in `build()`
- **Future-ready**: Structure supports multiple language instances when needed

---

## 9. Performance Techniques Summary

| Technique                       | Where Used                              | Impact                          |
|---------------------------------|-----------------------------------------|---------------------------------|
| `RepaintBoundary`               | Sidebar item buttons, bronze buttons    | Isolates animated repaints      |
| `ValueNotifier` scoping         | Shell body, workspace views             | Minimal rebuild scope           |
| Background `Isolate`            | Dashboard refresh, autopilot polling    | Keeps UI thread responsive      |
| `IndexedStack` + lazy build     | Main content panel                      | Preserves tab state, saves RAM  |
| CustomPainter segment caching   | Bronze texture painter                  | Avoids per-frame geometry       |
| Polling pause on unfocus        | Workspace controller, autopilot         | Saves CPU when inactive         |
| Deferred initialization         | Post-frame callback in initState        | Prevents startup freeze         |
| `const` constructors            | Spacers, icons, decorations             | Skips unchanged subtree builds  |
| AnimatedContainer batching      | Sidebar slots, shell padding            | Single animation pass           |

---

## 10. File Reference Map

### Theme Layer
| File | Contents |
|------|----------|
| `theme/ui_chrome_config.dart` | Spacing scale, radii, layout dimensions, platform methods |
| `theme/ui_motion_config.dart` | Animation durations and curves |
| `theme/ui_surface_styles.dart` | Surface tones, shadow factories, panel decorations |
| `theme/premium_white_bronze_tokens.dart` | 64+ colors, procedural gradients, shadow sets |
| `theme/platform_window_controls_profile.dart` | Window control side + inset per platform |
| `theme/platform_corner_profile.dart` | Corner radii per platform |
| `theme/saas_theme.dart` | Material 3 ThemeData for light/dark |

### Controller Layer
| File | Contents |
|------|----------|
| `controllers/desktop_shell_controller.dart` | Shell-level visibility + section state |
| `controllers/project_workspace_controller.dart` | Project data coordinator (facade) |
| `controllers/autopilot_controller.dart` | Autopilot status, polling, step/stop |
| `controllers/task_controller.dart` | Task CRUD, backlog helpers |
| `controllers/review_controller.dart` | Review status + decisions |
| `controllers/project_config_controller.dart` | Config persistence + draft editing |
| `controllers/background_api_runner.dart` | Isolate execution for heavy I/O |

### Widget Layer
| File | Contents |
|------|----------|
| `widgets/shell/desktop_scaffold.dart` | Main shell layout, sidebar orchestration |
| `widgets/shell/shell_top_bar.dart` | Top chrome with animated fullscreen insets |
| `widgets/shell/left_sidebar.dart` | Navigation panel in glass container |
| `widgets/shell/right_sidebar.dart` | Context panel with section switching |
| `widgets/shell/main_content_panel.dart` | IndexedStack tab management |
| `widgets/shell/animated_shell_slot.dart` | Reusable sidebar show/hide animation |
| `widgets/shell/workspaces/*.dart` | Individual workspace view implementations |
| `widgets/common/bronze_button.dart` | Metallic button component |
| `widgets/common/bronze_brush_texture.dart` | CustomPainter for metal texture |
| `widgets/common/bronze_reflection.dart` | Animated specular light system |
| `widgets/common/glass_panel.dart` | Semi-transparent panel container |

### Desktop Integration Layer
| File | Contents |
|------|----------|
| `desktop/services/window_service_interface.dart` | Abstract contract for window operations |
| `desktop/services/production_window_service.dart` | Real desktop implementation |
| `desktop/services/noop_window_service.dart` | Fallback for web/test |
| `desktop/windowing/desktop_window_mode.dart` | Window type enum + parser |
| `desktop/windowing/window_launch_context.dart` | Immutable bootstrap context |

---

## Related Documentation

- [GUI Development Guide](gui-development-guide.md) -- How to extend the GUI correctly
- [UI Design System Standards](ui-design-system.md) -- Token values, spacing rules, PR checklist
- [UI Engineering Guardrails](ui-engineering-guardrails.md) -- Layering rules, boundary tests
- [Architecture Overview](overview.md) -- 3-layer architecture and dependency rules
