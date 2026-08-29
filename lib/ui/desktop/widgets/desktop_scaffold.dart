// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../desktop/services/window_service_interface.dart';
import '../controllers/project_workspace_controller.dart';
import '../controllers/desktop_shell_controller.dart';
import '../models/dashboard_models.dart';
import '../theme/platform_corner_profile.dart';
import '../theme/platform_window_controls_profile.dart';
import '../theme/ui_chrome_config.dart';
import '../theme/ui_motion_config.dart';
import '../theme/ui_surface_styles.dart';
import 'adaptive_menu_bar.dart';
import 'shell/animated_shell_slot.dart';
import 'shell/left_sidebar.dart';
import 'shell/main_content_panel.dart';
import 'shell/right_sidebar.dart';
import 'shell/shell_top_bar.dart';

typedef DesktopMainContentBuilder =
    Widget Function(
      BuildContext context,
      double topCornerRadius,
      bool leftSidebarVisible,
      bool rightSidebarVisible,
    );
typedef DesktopLeftSidebarBuilder = Widget Function(BuildContext context);

class DesktopScaffold extends StatefulWidget {
  const DesktopScaffold({
    super.key,
    required this.windowService,
    required this.projectDisplayName,
    this.projectRootPath,
    this.onOpenSettings,
    this.leftSidebarCollapsible = true,
    this.rightSidebarEnabled = true,
    this.mainContentBuilder,
    this.leftSidebarBuilder,
    this.shellBackgroundColor,
    this.topBarForegroundColor,
    this.manageWindowTranslucency = true,
    this.sidebarLightGlassColor,
    this.sidebarDarkGlassColor,
    this.sidebarLightBorderColor,
    this.sidebarDarkBorderColor,
  });

  final WindowServiceInterface windowService;
  final String projectDisplayName;
  final String? projectRootPath;
  final VoidCallback? onOpenSettings;
  final bool leftSidebarCollapsible;
  final bool rightSidebarEnabled;
  final DesktopMainContentBuilder? mainContentBuilder;
  final DesktopLeftSidebarBuilder? leftSidebarBuilder;
  final Color? shellBackgroundColor;
  final Color? topBarForegroundColor;
  final bool manageWindowTranslucency;
  final Color? sidebarLightGlassColor;
  final Color? sidebarDarkGlassColor;
  final Color? sidebarLightBorderColor;
  final Color? sidebarDarkBorderColor;

  @override
  State<DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<DesktopScaffold> {
  late final DesktopShellController _controller = DesktopShellController(
    windowService: widget.windowService,
  );
  ProjectWorkspaceController? _workspaceController;
  String? _workspaceControllerProjectRoot;
  static const PlatformWindowControlsResolver _windowControlsResolver =
      PlatformWindowControlsResolver();
  bool? _lastAppliedBlurDarkMode;

  bool get _requiresWorkspaceController =>
      widget.mainContentBuilder == null || widget.rightSidebarEnabled;

  void _toggleLeftSidebar() {
    if (!widget.leftSidebarCollapsible) {
      return;
    }
    _controller.toggleLeftSidebar();
  }

  void _openSettings() {
    widget.onOpenSettings?.call();
  }

  @override
  void initState() {
    super.initState();
    _ensureWorkspaceController(deferInit: true);
    widget.windowService.windowFocused.addListener(_onWindowFocusChanged);
  }

  @override
  void didUpdateWidget(covariant DesktopScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowService != widget.windowService) {
      oldWidget.windowService.windowFocused.removeListener(
        _onWindowFocusChanged,
      );
      widget.windowService.windowFocused.addListener(_onWindowFocusChanged);
    }
    if (oldWidget.projectRootPath != widget.projectRootPath ||
        oldWidget.mainContentBuilder != widget.mainContentBuilder ||
        oldWidget.rightSidebarEnabled != widget.rightSidebarEnabled) {
      _ensureWorkspaceController();
    }
    if (oldWidget.manageWindowTranslucency != widget.manageWindowTranslucency) {
      _lastAppliedBlurDarkMode = null;
      _syncWindowBlurForTheme();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWindowBlurForTheme();
    if (!widget.leftSidebarCollapsible &&
        widget.windowService.sidebarHidden.value) {
      widget.windowService.setSidebarHidden(false);
    }
  }

  @override
  void dispose() {
    widget.windowService.windowFocused.removeListener(_onWindowFocusChanged);
    _workspaceController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onWindowFocusChanged() {
    final bool focused = widget.windowService.windowFocused.value;
    final ProjectWorkspaceController? controller = _workspaceController;
    if (controller == null) {
      return;
    }
    if (focused) {
      controller.resumePolling();
      controller.autopilot.resumePolling();
      // Trigger an immediate silent refresh so the UI shows current data
      // after returning from an unfocused state.
      unawaited(controller.refresh(silent: true));
    } else {
      controller.pausePolling();
      controller.autopilot.pausePolling();
    }
  }

  void _ensureWorkspaceController({bool deferInit = false}) {
    if (!_requiresWorkspaceController) {
      _workspaceController?.dispose();
      _workspaceController = null;
      _workspaceControllerProjectRoot = null;
      return;
    }

    final String normalizedProjectRoot = (widget.projectRootPath ?? '').trim();
    if (_workspaceController != null &&
        _workspaceControllerProjectRoot == normalizedProjectRoot) {
      return;
    }

    _workspaceController?.dispose();
    final ProjectWorkspaceController controller = ProjectWorkspaceController(
      projectRootPath: normalizedProjectRoot,
    );
    _workspaceController = controller;
    _workspaceControllerProjectRoot = normalizedProjectRoot;
    if (deferInit) {
      // Schedule initialization after the first frame so the window renders
      // its placeholder layout before any blocking API calls begin.
      //
      // CRITICAL: We await `windowService.initialized` before starting the
      // controller.  In release builds the window service performs platform
      // channel calls (ensureInitialized, show, focus) that must finish
      // before background isolates can reliably spawn.  Without this gate
      // the two independent post-frame callbacks (window init + controller
      // init) race, and if the isolate fails the old main-thread fallback
      // would block the event loop, preventing the window from appearing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_workspaceController != controller || !mounted) {
          return;
        }
        unawaited(
          widget.windowService.initialized.then((_) {
            if (_workspaceController == controller && mounted) {
              controller.initialize();
            }
          }),
        );
      });
    } else {
      unawaited(controller.initialize());
    }
  }

  ProjectWorkspaceController _resolveWorkspaceController() {
    _ensureWorkspaceController();
    final ProjectWorkspaceController? controller = _workspaceController;
    if (controller != null) {
      return controller;
    }
    throw StateError('Workspace controller is unavailable.');
  }

  void _syncWindowBlurForTheme() {
    if (!widget.manageWindowTranslucency) {
      return;
    }
    final bool darkMode = Theme.of(context).brightness == Brightness.dark;
    if (_lastAppliedBlurDarkMode == darkMode) {
      return;
    }
    _lastAppliedBlurDarkMode = darkMode;
    unawaited(
      widget.windowService
          .setBlur(enabled: true, darkMode: darkMode)
          .catchError((Object error, StackTrace stackTrace) {
            if (kDebugMode) {
              debugPrint('Failed to synchronize window blur: $error');
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TargetPlatform platform = Theme.of(context).platform;
    final double topInset = UiChromeConfig.topInsetFor(platform);
    final double topBarHeight = UiChromeConfig.topBarHeightFor(platform);
    final PlatformCornerProfile corners = PlatformCornerProfile.resolve();
    final PlatformWindowControlsProfile windowControlsProfile =
        _windowControlsResolver.resolve(platform: platform);
    final Color defaultShellBackground = UiSurfaceStyles.shellBackground(
      context,
    );
    final Color scaffoldBackgroundColor = widget.manageWindowTranslucency
        ? Colors.transparent
        : (widget.shellBackgroundColor ?? defaultShellBackground);

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      body: AdaptiveMenuBar(
        windowService: widget.windowService,
        onOpenSettings: _openSettings,
        onToggleLeftSidebar: _toggleLeftSidebar,
        onToggleRightSidebar: _controller.toggleRightSidebar,
        showSettingsAction: widget.onOpenSettings != null,
        showLeftSidebarAction: widget.leftSidebarCollapsible,
        showRightSidebarAction: widget.rightSidebarEnabled,
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.windowService.fullscreen,
          builder: (BuildContext context, bool fullscreen, Widget? _) {
            final Color resolvedShellBackground =
                widget.shellBackgroundColor ??
                (widget.manageWindowTranslucency
                    ? Colors.transparent
                    : defaultShellBackground);
            final double topBarHorizontalInset =
                UiChromeConfig.topBarHorizontalInsetFor(
                  platform: platform,
                  fullscreen: fullscreen,
                );

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Guard: skip full layout when the native window is still at
                // degenerate size (e.g. 1×1 on macOS before
                // waitUntilReadyToShow completes).  Once the window reaches a
                // viable size the LayoutBuilder will rebuild automatically.
                if (constraints.maxWidth < 100 || constraints.maxHeight < 100) {
                  return const SizedBox.shrink();
                }
                return Container(
                  key: const Key('desktop.shell.background'),
                  color: resolvedShellBackground,
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: topInset),
                      // Top bar: only rebuilds on fullscreen + sidebarHidden changes.
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.windowService.sidebarHidden,
                        builder:
                            (
                              BuildContext context,
                              bool sidebarHiddenValue,
                              Widget? _,
                            ) {
                              final bool leftHidden =
                                  widget.leftSidebarCollapsible
                                  ? sidebarHiddenValue
                                  : false;
                              return ValueListenableBuilder<bool>(
                                valueListenable:
                                    _controller.rightSidebarVisible,
                                builder:
                                    (
                                      BuildContext context,
                                      bool rightVisible,
                                      Widget? _,
                                    ) {
                                      final bool effectiveRightVisible =
                                          widget.rightSidebarEnabled
                                          ? rightVisible
                                          : false;
                                      return AnimatedPadding(
                                        key: const Key(
                                          'desktop.topbar.shellPadding',
                                        ),
                                        duration:
                                            UiMotionConfig.fullscreenDuration,
                                        curve: UiMotionConfig.fullscreenCurve,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: topBarHorizontalInset,
                                        ),
                                        child: ShellTopBar(
                                          height: topBarHeight,
                                          fullscreen: fullscreen,
                                          windowControlsProfile:
                                              windowControlsProfile,
                                          projectDisplayName:
                                              widget.projectDisplayName,
                                          foregroundColor:
                                              widget.topBarForegroundColor,
                                          showLeftToggle:
                                              widget.leftSidebarCollapsible,
                                          showRightToggle:
                                              widget.rightSidebarEnabled,
                                          leftHidden: leftHidden,
                                          rightVisible: effectiveRightVisible,
                                          onToggleLeftVisibility:
                                              _toggleLeftSidebar,
                                          onToggleRightVisibility:
                                              _controller.toggleRightSidebar,
                                        ),
                                      );
                                    },
                              );
                            },
                      ),
                      if (platform != TargetPlatform.macOS) ...<Widget>[
                        const SizedBox(height: UiChromeConfig.space8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiChromeConfig.windowInset,
                          ),
                          child: InWindowMenuBar(
                            windowService: widget.windowService,
                            onOpenSettings: _openSettings,
                            onToggleLeftSidebar: _toggleLeftSidebar,
                            onToggleRightSidebar:
                                _controller.toggleRightSidebar,
                            showSettingsAction: widget.onOpenSettings != null,
                            showLeftSidebarAction:
                                widget.leftSidebarCollapsible,
                            showRightSidebarAction: widget.rightSidebarEnabled,
                          ),
                        ),
                      ],
                      const SizedBox(height: UiChromeConfig.panelGap),
                      // Main body: sidebar slots + content panel.
                      Expanded(
                        child: _ShellBody(
                          controller: _controller,
                          windowService: widget.windowService,
                          leftSidebarCollapsible: widget.leftSidebarCollapsible,
                          rightSidebarEnabled: widget.rightSidebarEnabled,
                          corners: corners,
                          leftSidebarBuilder: widget.leftSidebarBuilder,
                          mainContentBuilder: widget.mainContentBuilder,
                          resolveWorkspaceController:
                              _resolveWorkspaceController,
                          sidebarLightGlassColor: widget.sidebarLightGlassColor,
                          sidebarDarkGlassColor: widget.sidebarDarkGlassColor,
                          sidebarLightBorderColor:
                              widget.sidebarLightBorderColor,
                          sidebarDarkBorderColor: widget.sidebarDarkBorderColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Extracted body widget that scopes sidebar and content rebuilds independently.
class _ShellBody extends StatelessWidget {
  const _ShellBody({
    required this.controller,
    required this.windowService,
    required this.leftSidebarCollapsible,
    required this.rightSidebarEnabled,
    required this.corners,
    required this.leftSidebarBuilder,
    required this.mainContentBuilder,
    required this.resolveWorkspaceController,
    required this.sidebarLightGlassColor,
    required this.sidebarDarkGlassColor,
    required this.sidebarLightBorderColor,
    required this.sidebarDarkBorderColor,
  });

  final DesktopShellController controller;
  final WindowServiceInterface windowService;
  final bool leftSidebarCollapsible;
  final bool rightSidebarEnabled;
  final PlatformCornerProfile corners;
  final DesktopLeftSidebarBuilder? leftSidebarBuilder;
  final DesktopMainContentBuilder? mainContentBuilder;
  final ProjectWorkspaceController Function() resolveWorkspaceController;
  final Color? sidebarLightGlassColor;
  final Color? sidebarDarkGlassColor;
  final Color? sidebarLightBorderColor;
  final Color? sidebarDarkBorderColor;

  @override
  Widget build(BuildContext context) {
    // Sidebar visibility scope: rebuilds only sidebar slots when hidden state changes.
    return ValueListenableBuilder<bool>(
      valueListenable: windowService.sidebarHidden,
      builder: (BuildContext context, bool sidebarHiddenValue, Widget? _) {
        final bool leftHidden = leftSidebarCollapsible
            ? sidebarHiddenValue
            : false;

        return ValueListenableBuilder<bool>(
          valueListenable: controller.rightSidebarVisible,
          builder: (BuildContext context, bool rightVisibleValue, Widget? _) {
            final bool rightVisible = rightSidebarEnabled
                ? rightVisibleValue
                : false;

            return AnimatedPadding(
              duration: UiMotionConfig.shellDuration,
              curve: UiMotionConfig.shellCurve,
              padding: EdgeInsets.fromLTRB(
                leftHidden ? 0 : UiChromeConfig.windowInset,
                0,
                rightVisible ? UiChromeConfig.windowInset : 0,
                0,
              ),
              child: Row(
                children: <Widget>[
                  // Left sidebar slot.
                  AnimatedSidebarSlot(
                    key: const Key('desktop.leftSidebar.slot'),
                    visible: !leftHidden,
                    width: UiChromeConfig.leftSidebarExpandedWidth,
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: UiChromeConfig.windowInset,
                      ),
                      child:
                          leftSidebarBuilder?.call(context) ??
                          // Left sidebar only needs selectedSection for highlight.
                          ValueListenableBuilder<DesktopPrimarySection>(
                            valueListenable: controller.selectedSection,
                            builder:
                                (
                                  BuildContext context,
                                  DesktopPrimarySection section,
                                  Widget? _,
                                ) {
                                  return LeftSidebar(
                                    cornerRadius: corners.sidebarRadius,
                                    selectedSection: section,
                                    onSelectSection: controller.selectSection,
                                    lightGlassColor: sidebarLightGlassColor,
                                    darkGlassColor: sidebarDarkGlassColor,
                                    lightBorderColor: sidebarLightBorderColor,
                                    darkBorderColor: sidebarDarkBorderColor,
                                  );
                                },
                          ),
                    ),
                  ),
                  AnimatedSidebarGap(visible: !leftHidden),
                  // Main content: only rebuilds when selectedSection changes.
                  Expanded(
                    child: mainContentBuilder != null
                        ? mainContentBuilder!(
                            context,
                            corners.mainTopRadius,
                            !leftHidden,
                            rightVisible,
                          )
                        : ValueListenableBuilder<DesktopPrimarySection>(
                            valueListenable: controller.selectedSection,
                            builder:
                                (
                                  BuildContext context,
                                  DesktopPrimarySection section,
                                  Widget? _,
                                ) {
                                  return MainContentPanel(
                                    controller: resolveWorkspaceController(),
                                    topCornerRadius: corners.mainTopRadius,
                                    leftSidebarVisible: !leftHidden,
                                    rightSidebarVisible: rightVisible,
                                    selectedSection: section,
                                    onBacklogCreateRequested: () {
                                      controller.showRightSidebar();
                                      resolveWorkspaceController()
                                          .requestBacklogComposerFocus();
                                    },
                                  );
                                },
                          ),
                  ),
                  AnimatedSidebarGap(visible: rightVisible),
                  // Right sidebar slot.
                  AnimatedSidebarSlot(
                    key: const Key('desktop.rightSidebar.slot'),
                    visible: rightVisible,
                    width: UiChromeConfig.rightSidebarWidth,
                    alignment: Alignment.centerRight,
                    child: rightSidebarEnabled
                        ? Padding(
                            padding: const EdgeInsets.only(
                              bottom: UiChromeConfig.windowInset,
                            ),
                            child:
                                ValueListenableBuilder<DesktopPrimarySection>(
                                  valueListenable: controller.selectedSection,
                                  builder:
                                      (
                                        BuildContext context,
                                        DesktopPrimarySection section,
                                        Widget? _,
                                      ) {
                                        return RightSidebar(
                                          cornerRadius: corners.sidebarRadius,
                                          selectedSection: section,
                                          controller:
                                              resolveWorkspaceController(),
                                          lightGlassColor:
                                              sidebarLightGlassColor,
                                          darkGlassColor: sidebarDarkGlassColor,
                                          lightBorderColor:
                                              sidebarLightBorderColor,
                                          darkBorderColor:
                                              sidebarDarkBorderColor,
                                        );
                                      },
                                ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
