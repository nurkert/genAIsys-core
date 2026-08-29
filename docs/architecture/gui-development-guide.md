[Home](../README.md) > [Architecture](./README.md) > GUI Development Guide

# GUI Development Guide

Status: Mandatory
Scope: All GUI work in `lib/ui/**` and `lib/desktop/**`
Audience: Engineers and agents extending the Genaisys desktop GUI

> **Prerequisite reading**:
> - [GUI Architecture Reference](./gui-architecture.md) -- how the current system works
> - [UI Design System Standards](./ui-design-system.md) -- token values and PR checklist
> - [UI Engineering Guardrails](./ui-engineering-guardrails.md) -- boundary rules and regression gates

---

## 1. Before You Start

Before writing any GUI code, verify that you understand:

1. **Which layer are you working in?** (theme tokens, controller, widget, desktop service)
2. **Does a token or component already exist?** Search `ui_chrome_config.dart`, `premium_white_bronze_tokens.dart`, and `widgets/common/` before creating anything new.
3. **What rebuild scope will your change affect?** Trace the `ValueNotifier` / `ValueListenableBuilder` chain from your change point upward.

---

## 2. Adding a New Workspace View

Workspace views are the main content tabs (Dashboard, Backlog, Chat, Autopilot, etc.).

### Step-by-Step

1. **Create the view widget** in `lib/ui/desktop/widgets/shell/workspaces/`:

```dart
class MyNewWorkspaceView extends StatefulWidget {
  const MyNewWorkspaceView({super.key, required this.controller});
  final ProjectWorkspaceController controller;

  @override
  State<MyNewWorkspaceView> createState() => _MyNewWorkspaceViewState();
}
```

2. **Follow the standard layout pattern**:

```dart
@override
Widget build(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      WorkspaceHeader(
        title: context.strings.myNewTitle,
        subtitle: context.strings.myNewSubtitle,
        seed: <unique_int>,  // For gradient uniqueness
      ),
      const SizedBox(height: UiChromeConfig.space12),
      // Optional: control strip, tab bar, filters
      Expanded(
        child: _buildContent(context),
      ),
    ],
  );
}
```

3. **Register in `DesktopPrimarySection`** enum (`models/dashboard_models.dart`).

4. **Add to `MainContentPanel`** in the `IndexedStack` builder.

5. **Add sidebar section content** in `RightSidebar` if needed.

6. **Add localized strings** in `desktop_strings.dart`.

7. **Add navigation item** in `LeftSidebar` nav items list.

### Mandatory Checklist
- [ ] Uses `WorkspaceHeader` for title chrome
- [ ] Spacing values from `UiChromeConfig` only
- [ ] Strings from `context.strings` only
- [ ] Responsive via `LayoutBuilder` for narrow widths
- [ ] Controller access via `widget.controller`, not recreated

---

## 3. Adding a New Common Component

Common components live in `lib/ui/desktop/widgets/common/` and are reused across workspace views.

### Rules

1. **Stateless when possible**. Use `StatefulWidget` only when the component manages its own animation or hover/press state.
2. **Accept configuration via constructor**. No internal constants -- use tokens from `UiChromeConfig` or `PremiumWhiteBronzeTokens`.
3. **Wrap in `RepaintBoundary`** if the component has frequent paint changes (animations, hover effects, custom painters).
4. **Use `const` constructors** wherever possible.

### Pattern: Metallic Component

If your component uses the bronze/silver metallic language:

```dart
class MyMetalWidget extends StatefulWidget {
  const MyMetalWidget({super.key, required this.seed});
  final int seed;
  // ...
}

class _MyMetalWidgetState extends State<MyMetalWidget> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: PremiumWhiteBronzeTokens.bronzeGradientFor(widget.seed),
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          boxShadow: PremiumWhiteBronzeTokens.softSurfaceShadow,
        ),
        child: CustomPaint(
          foregroundPainter: BronzeBrushTexturePainter(
            seed: widget.seed,
            strength: 0.6,
            borderRadius: UiChromeConfig.controlRadius,
          ),
          child: Stack(
            children: <Widget>[
              BronzeSpecularLight(seed: widget.seed, ...),
              // Content here
            ],
          ),
        ),
      ),
    );
  }
}
```

### Pattern: Surface Panel

For non-metallic content panels:

```dart
Container(
  decoration: UiSurfaceStyles.panel(
    context,
    tone: DesktopSurfaceTone.soft,
    radius: UiChromeConfig.cardRadius,
  ),
  padding: const EdgeInsets.all(UiChromeConfig.space16),
  child: content,
)
```

---

## 4. Working with State

### When to Use What

| Pattern | When | Example |
|---------|------|---------|
| `ValueNotifier` + `ValueListenableBuilder` | UI-local reactive state | Sidebar visibility, section selection |
| Controller method + `notifyListeners()` | Complex state with side effects | Task mutation, config save |
| Background `Isolate` | Blocking I/O (git, file, process) | Dashboard refresh, autopilot status |
| Simple `setState()` | Widget-internal transient state | Hover, pressed, text input |

### Adding a New Controller

If your feature manages independent state that should not trigger rebuilds in unrelated views:

1. **Create a focused controller** in `lib/ui/desktop/controllers/`:

```dart
class MyFeatureController {
  MyFeatureController({required String projectRootPath, required GenaisysApi api})
    : _projectRootPath = projectRootPath, _api = api;

  final String _projectRootPath;
  final GenaisysApi _api;

  final ValueNotifier<MyDataDto?> dataNotifier = ValueNotifier<MyDataDto?>(null);

  Future<String?> refresh() async {
    final AppResult<MyDataDto> result = await _api.loadMyData(_projectRootPath);
    if (result.ok && result.data != null) {
      dataNotifier.value = result.data;
      return null;
    }
    return result.error?.message ?? 'Failed to load data.';
  }
}
```

2. **Register in `ProjectWorkspaceController`** as a delegate:

```dart
late final MyFeatureController _myFeature;

// In constructor:
_myFeature = MyFeatureController(
  projectRootPath: _projectRootPath,
  api: _api,
);

// Expose notifier:
ValueNotifier<MyDataDto?> get myDataNotifier => _myFeature.dataNotifier;
```

3. **Consume in widget**:

```dart
ValueListenableBuilder<MyDataDto?>(
  valueListenable: widget.controller.myDataNotifier,
  builder: (context, data, _) {
    if (data == null) return const CircularProgressIndicator();
    return MyDataView(data: data);
  },
)
```

### Running Heavy Work in Background Isolates

If your operation calls `Process.runSync`, reads large files, or takes >50ms:

1. **Add a top-level function** in `background_api_runner.dart`:

```dart
Future<MyResult> runMyOperationInBackground({required String projectRootPath}) {
  return Isolate.run(() => _myOperationInIsolate(projectRootPath));
}

MyResult _myOperationInIsolate(String rootPath) {
  final GenaisysApi api = InProcessGenaisysApi();
  // ... heavy work with fresh API instance ...
  return MyResult(...);
}
```

2. **Ensure `MyResult` is isolate-sendable** (only primitives, enums, Lists, Maps).

3. **Handle spawn failure gracefully** -- return error string, never fallback to main thread.

---

## 5. Adding Design Tokens

### New Spacing or Dimension

Add to `ui_chrome_config.dart`:

```dart
/// Horizontal padding for my new panel.
static const double myNewPanelPadding = 16;
```

Never use bare `16.0` in widget files. Always reference the token.

### New Color

Add to `premium_white_bronze_tokens.dart` in the appropriate palette section:

```dart
/// Accent color for my feature highlight.
static const Color myFeatureAccent = Color(0xFF...);
static const Color myFeatureAccentDark = Color(0xFF...);
```

### New Animation Timing

Add to `ui_motion_config.dart`:

```dart
/// Duration for my feature panel transition.
static const Duration myFeatureDuration = Duration(milliseconds: 200);
static const Curve myFeatureCurve = Curves.easeOutCubic;
```

### Token Change Protocol

1. Update central token file
2. Update `ui_design_system_standards.md` if baseline values change
3. Update affected widget tests
4. Include before/after screenshots in PR

---

## 6. Platform-Specific Behavior

### Rules

1. **Never check `Platform.isMacOS` in widgets**. Use `Theme.of(context).platform` or the resolved `PlatformWindowControlsProfile` / `PlatformCornerProfile`.
2. **Never import `window_manager` or `desktop_multi_window` in `lib/ui/`**. Use `WindowServiceInterface` methods.
3. **Platform-specific insets** are resolved by `UiChromeConfig.topBarHeightFor(platform)` and `PlatformWindowControlsProfile.insetFor(fullscreen:)`.

### Adding a New Platform Operation

1. Add the method to `WindowServiceInterface`:

```dart
Future<void> myNewPlatformOperation();
```

2. Implement in `ProductionWindowService` with try-catch:

```dart
@override
Future<void> myNewPlatformOperation() async {
  try {
    await windowManager.someNativeCall();
  } on MissingPluginException {
    // Graceful degradation
  }
}
```

3. Add no-op in `NoopWindowService`:

```dart
@override
Future<void> myNewPlatformOperation() async {}
```

---

## 7. Localization

### Adding New Strings

1. Add fields to `DesktopStrings` in `desktop_strings.dart`:

```dart
final String myFeatureTitle;
final String myFeatureDescription;
```

2. Provide values in the `english` static const:

```dart
static const DesktopStrings english = DesktopStrings(
  // ... existing fields ...
  myFeatureTitle: 'My Feature',
  myFeatureDescription: 'Description of my feature.',
);
```

3. Access in widgets:

```dart
final DesktopStrings strings = context.strings;
Text(strings.myFeatureTitle)
```

**Never** hardcode user-visible strings in widget files.

---

## 8. Sidebar Integration

### Left Sidebar Navigation

To add a navigation item:

1. Add to `DesktopPrimarySection` enum.
2. Add `SidebarNavItem` in `LeftSidebar` nav list with icon and label.
3. Register the workspace view in `MainContentPanel`.

### Right Sidebar Context Panel

Right sidebar content switches based on the active section via `AnimatedSwitcher`:

1. Create a `SimpleSidebarPanel` or custom panel widget.
2. Register in the section-to-panel mapping in `RightSidebar`.
3. Ensure the panel handles loading/empty states.

---

## 9. Testing Requirements

### Widget Tests

Every new UI component or workspace view must have:
- Rendering test (builds without errors)
- State test (controller changes reflected in widget)
- Light + dark mode test
- Sidebar visibility tests (if layout-dependent)

### Architecture Boundary Tests

Changes to imports must pass:
- `test/core/architecture_imports_test.dart` -- core never imports UI
- `test/core/ui_architecture_boundaries_test.dart` -- UI never imports desktop packages

### Analyzer

`flutter analyze` must report zero issues. No `// ignore` without documented reason.

---

## 10. Anti-Patterns to Avoid

| Anti-Pattern | Why It Is Wrong | Do This Instead |
|--------------|-----------------|-----------------|
| Hard-coded `EdgeInsets.all(16)` | Breaks token centralization | `UiChromeConfig.space16` |
| `import 'package:window_manager/...'` in UI | Violates boundary rule | Use `WindowServiceInterface` |
| Hardcoded strings `'Dashboard'` | Blocks localization | `context.strings.dashboardTitle` |
| `setState()` for shared state | Causes full-widget rebuilds | `ValueNotifier` + `ValueListenableBuilder` |
| `FutureBuilder` for API calls | Retriggered on every build | Controller pattern with notifiers |
| `dynamic` types in controllers | Loses type safety | Typed DTOs from `core/app/dto/` |
| Blocking `await` in `main()` | Freezes macOS sub-windows | Post-frame callback pattern |
| Rebuilding entire shell on tab switch | Performance waste | `IndexedStack` + lazy building |
| `Process.runSync` on UI thread | Freezes UI for 300-700ms | Background `Isolate` |
| Creating new gradient per frame | Expensive + flickering | `bronzeGradientFor(seed)` with stable seed |

---

## 11. Quick Reference: File Locations

| I want to... | Go to... |
|---------------|----------|
| Add spacing/radius token | `lib/ui/desktop/theme/ui_chrome_config.dart` |
| Add color/gradient | `lib/ui/desktop/theme/premium_white_bronze_tokens.dart` |
| Add animation timing | `lib/ui/desktop/theme/ui_motion_config.dart` |
| Add surface style | `lib/ui/desktop/theme/ui_surface_styles.dart` |
| Add platform behavior | `lib/desktop/services/window_service_interface.dart` + impls |
| Add UI strings | `lib/ui/desktop/localization/desktop_strings.dart` |
| Add workspace view | `lib/ui/desktop/widgets/shell/workspaces/` |
| Add shared component | `lib/ui/desktop/widgets/common/` |
| Add controller | `lib/ui/desktop/controllers/` |
| Add UI model | `lib/ui/desktop/models/` |
| Add shell-level state | `lib/ui/desktop/controllers/desktop_shell_controller.dart` |
| Add heavy background work | `lib/ui/desktop/controllers/background_api_runner.dart` |
| Modify shell layout | `lib/ui/desktop/widgets/shell/desktop_scaffold.dart` |

---

## 12. PR Checklist for GUI Changes

Before submitting any GUI PR, confirm every item:

- [ ] All spacing, radius, and width values use centralized tokens
- [ ] No direct imports of `window_manager`, `flutter_acrylic`, or `desktop_multi_window` in `lib/ui/`
- [ ] All user-visible strings from `context.strings`
- [ ] Light mode and dark mode both validated
- [ ] Sidebar hidden/visible states tested
- [ ] `flutter analyze` reports zero issues
- [ ] Widget tests added or updated
- [ ] Architecture boundary tests pass
- [ ] Responsive behavior verified at narrow widths
- [ ] No blocking I/O on the UI thread
- [ ] `RepaintBoundary` used around frequently-animated components
- [ ] Token changes documented in this guide or `ui_design_system_standards.md`

---

## Related Documentation

- [GUI Architecture Reference](gui-architecture.md) -- Shell layout, state management, widget tree
- [UI Design System Standards](ui-design-system.md) -- Token values, spacing rules, PR checklist
- [UI Engineering Guardrails](ui-engineering-guardrails.md) -- Layering rules, boundary tests
- [Architecture Overview](overview.md) -- 3-layer architecture and dependency rules
