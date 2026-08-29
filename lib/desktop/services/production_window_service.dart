// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../windowing/desktop_window_mode.dart';
import '../windowing/window_launch_context.dart';
import 'multi_window_api.dart';
import 'window_service_interface.dart';

class ProductionWindowService
    with WindowListener
    implements WindowServiceInterface {
  ProductionWindowService({
    required WindowLaunchContext launchContext,
    required MultiWindowApi multiWindowApi,
  }) : _launchContext = launchContext,
       _multiWindowApi = multiWindowApi;

  static const Color _opaqueHubBackground = Color(0xFFF5F5F7);
  static const Color _opaqueWorkspaceBackground = Color(0xFFF5F5F7);
  static const Size _projectHubSize = Size(1060, 680);

  static String? _settingsWindowId;
  static const String _focusWindowMethod = 'genaisys.window.focus';
  static const String _identifyWindowMethod = 'genaisys.window.identity';
  static const String _windowClosedMethod = 'genaisys.window.closed';

  final WindowLaunchContext _launchContext;
  final MultiWindowApi _multiWindowApi;
  final ValueNotifier<bool> _sidebarHidden = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _fullscreen = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _windowFocused = ValueNotifier<bool>(true);
  final Completer<void> _initializedCompleter = Completer<void>();
  bool _fullscreenRefreshInFlight = false;
  bool _windowManagerReady = false;
  bool _settingsCloseNotified = false;
  bool _projectWorkspaceCloseInFlight = false;
  bool _allowProjectWorkspaceClose = false;
  Future<void>? _settingsOpenInFlight;
  bool _hubStartupRestoreSweepArmed = false;
  Future<void>? _hubStartupRestoreSweepFuture;
  final Set<String> _hubStaleStartupWindowIds = <String>{};

  @override
  ValueListenable<bool> get sidebarHidden => _sidebarHidden;

  @override
  ValueListenable<bool> get fullscreen => _fullscreen;

  @override
  ValueListenable<bool> get windowFocused => _windowFocused;

  @override
  Future<void> get initialized => _initializedCompleter.future;

  @override
  Future<void> initialize() async {
    try {
      _registerInterWindowHandler();
      if (_isRootProjectHubWindow) {
        _hubStaleStartupWindowIds
          ..clear()
          ..addAll(await _listSubWindowIds());
        _hubStartupRestoreSweepArmed = true;
        _hubStartupRestoreSweepFuture ??= _runHubStartupRestoreSweep();
        unawaited(_hubStartupRestoreSweepFuture);
      }
      final bool isProjectWorkspaceWindow =
          _launchContext.windowMode == DesktopWindowMode.projectWorkspace;
      try {
        await windowManager.ensureInitialized();
        windowManager.addListener(this);
        _windowManagerReady = true;

        final WindowOptions windowOptions = _windowOptionsFor(
          _launchContext.windowMode,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });

        // Force Flutter to re-layout after the window becomes visible.
        // waitUntilReadyToShow is an empty stub on macOS, so the engine may
        // have rendered its first frame at degenerate (1×1) constraints before
        // the native window reached its target size.
        _scheduleFrameIfBound();

        if (isProjectWorkspaceWindow) {
          await _configureProjectWorkspaceCloseInterception();
          await _closeStaleSettingsWindowsOnStartup();
        }

        await _refreshFullscreenState();
        if (kDebugMode) {
          debugPrint(
            '[WindowService] init ok mode=${_launchContext.windowModeKey} '
            'sub=${_launchContext.isSubWindow} id=${_launchContext.windowId}',
          );
        }
      } on MissingPluginException {
        _windowManagerReady = false;
        if (kDebugMode) {
          debugPrint(
            '[WindowService] init fallback missing-plugin '
            'mode=${_launchContext.windowModeKey} sub=${_launchContext.isSubWindow}',
          );
        }
      } on PlatformException {
        _windowManagerReady = false;
        if (kDebugMode) {
          debugPrint(
            '[WindowService] init fallback platform-exception '
            'mode=${_launchContext.windowModeKey} sub=${_launchContext.isSubWindow}',
          );
        }
      }
    } finally {
      if (!_initializedCompleter.isCompleted) {
        _initializedCompleter.complete();
      }
    }
  }

  bool get _isRootProjectHubWindow =>
      !_launchContext.isSubWindow &&
      _launchContext.windowMode == DesktopWindowMode.projectHub;

  @override
  Future<void> showWindow() async {
    await _focusCurrentWindow();
  }

  @override
  Future<void> hideWindow() async {
    if (!_windowManagerReady) {
      return;
    }
    try {
      await windowManager.hide().timeout(const Duration(milliseconds: 500));
    } on MissingPluginException {
      // Best-effort only.
    } on PlatformException {
      // Best-effort only.
    } on TimeoutException {
      // Best-effort only.
    }
  }

  WindowOptions _windowOptionsFor(DesktopWindowMode mode) {
    switch (mode) {
      case DesktopWindowMode.settingsWorkspace:
        return const WindowOptions(
          size: Size(1320, 860),
          minimumSize: Size(1040, 680),
          center: true,
          // Settings is intentionally opaque; only the project workspace uses
          // transparent window composition.
          backgroundColor: Color(0xFFF2F6FB),
          titleBarStyle: TitleBarStyle.hidden,
          title: 'Genaisys Settings',
        );
      case DesktopWindowMode.projectHub:
        return const WindowOptions(
          size: _projectHubSize,
          minimumSize: _projectHubSize,
          maximumSize: _projectHubSize,
          center: true,
          // Project hub is intentionally opaque to avoid black "frame" artifacts
          // on macOS/Windows when no blur composition is applied.
          backgroundColor: _opaqueHubBackground,
          titleBarStyle: TitleBarStyle.hidden,
          title: 'Genaisys',
        );
      case DesktopWindowMode.projectWorkspace:
        final String projectName =
            _coerceString(
              _launchContext.arguments[WindowLaunchContext
                  .payloadProjectNameKey],
            ) ??
            'Genaisys Project';
        return WindowOptions(
          size: const Size(1440, 920),
          minimumSize: const Size(1100, 720),
          center: true,
          // Acrylic has been intentionally removed for cross-platform stability.
          // Workspace windows are now rendered on an opaque base surface.
          backgroundColor: _opaqueWorkspaceBackground,
          titleBarStyle: TitleBarStyle.hidden,
          title: 'Genaisys — $projectName',
        );
    }
  }

  void _registerInterWindowHandler() {
    _multiWindowApi.setMessageHandler(_handleInterWindowMessage);
  }

  Future<Object?> _handleInterWindowMessage(MultiWindowMessage message) async {
    switch (message.method) {
      case _focusWindowMethod:
        return _focusCurrentWindow();
      case _identifyWindowMethod:
        return _describeCurrentWindow();
      case _windowClosedMethod:
        return _handleWindowClosed(message.arguments);
      default:
        return null;
    }
  }

  Future<Map<String, Object?>> _focusCurrentWindow() async {
    if (_launchContext.isSubWindow && _launchContext.windowId != null) {
      await _tryShowWindowById(_launchContext.windowId!);
    }
    if (_windowManagerReady) {
      await windowManager.show().timeout(const Duration(milliseconds: 500));
      await windowManager.focus().timeout(const Duration(milliseconds: 500));
    }

    return _describeCurrentWindow();
  }

  Map<String, Object?> _describeCurrentWindow() {
    final String? projectName = _coerceString(
      _launchContext.arguments[WindowLaunchContext.payloadProjectNameKey],
    );
    final String? projectRootPath = _coerceString(
      _launchContext.arguments[WindowLaunchContext.payloadProjectRootPathKey],
    );
    return <String, Object?>{
      WindowLaunchContext.payloadWindowModeKey: _launchContext.windowModeKey,
      'window_id': _launchContext.windowId ?? '',
      'sub_window': _launchContext.isSubWindow,
      if (projectName != null && projectName.trim().isNotEmpty)
        WindowLaunchContext.payloadProjectNameKey: projectName,
      if (projectRootPath != null && projectRootPath.trim().isNotEmpty)
        WindowLaunchContext.payloadProjectRootPathKey: projectRootPath,
    };
  }

  bool _handleWindowClosed(Object? arguments) {
    if (arguments is! Map) {
      return false;
    }

    final Object? mode = arguments[WindowLaunchContext.payloadWindowModeKey];
    final String? closedWindowId = _coerceString(arguments['window_id']);
    if (closedWindowId == null) {
      return false;
    }

    if (mode == DesktopWindowMode.settingsWorkspace.key) {
      if (_settingsWindowId == closedWindowId) {
        _settingsWindowId = null;
      }
      return true;
    }

    return false;
  }

  @override
  void onWindowEnterFullScreen() {
    _fullscreen.value = true;
  }

  @override
  void onWindowClose() {
    switch (_launchContext.windowMode) {
      case DesktopWindowMode.settingsWorkspace:
        unawaited(_notifyMainWindowOnSettingsClose());
        return;
      case DesktopWindowMode.projectHub:
        return;
      case DesktopWindowMode.projectWorkspace:
        if (_allowProjectWorkspaceClose) {
          return;
        }
        unawaited(_handleProjectWorkspaceCloseRequest());
        return;
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    _fullscreen.value = false;
  }

  @override
  void onWindowResize() {
    _scheduleFullscreenRefresh();
  }

  @override
  void onWindowResized() {
    _scheduleFullscreenRefresh();
  }

  @override
  void onWindowFocus() {
    _windowFocused.value = true;
    _scheduleFrameIfBound();
  }

  @override
  void onWindowBlur() {
    _windowFocused.value = false;
  }

  @override
  void onWindowMove() {
    // macOS sometimes fires a move event instead of a resize when the
    // window is first positioned.  Schedule a frame so Flutter re-layouts
    // in case the constraints changed.
    _scheduleFrameIfBound();
  }

  void _scheduleFullscreenRefresh() {
    if (_fullscreenRefreshInFlight) {
      return;
    }
    _fullscreenRefreshInFlight = true;
    _refreshFullscreenState().whenComplete(() {
      _fullscreenRefreshInFlight = false;
      // Force Flutter to re-layout after the native window resized.
      _scheduleFrameIfBound();
    });
  }

  Future<void> _refreshFullscreenState() async {
    final bool isFullscreen = await windowManager.isFullScreen();
    if (_fullscreen.value != isFullscreen) {
      _fullscreen.value = isFullscreen;
    }
  }

  /// Asks Flutter to schedule a new frame so that layout is recalculated.
  ///
  /// This is critical on macOS where [windowManager.waitUntilReadyToShow]
  /// is a no-op: the engine may have rendered its first frame at 1×1
  /// constraints before the native window reached its configured size.
  void _scheduleFrameIfBound() {
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Future<void> setSidebarHidden(bool hidden) async {
    _sidebarHidden.value = hidden;
  }

  @override
  Future<void> setBlur({required bool enabled, required bool darkMode}) async {
    // Intentionally no-op: acrylic/translucency effects were removed to
    // stabilize cross-platform window behavior.
  }

  @override
  Future<void> openGeneralSettingsWindow() async {
    _disarmHubStartupRestoreSweep();
    if (_settingsOpenInFlight != null) {
      return _settingsOpenInFlight;
    }

    _settingsOpenInFlight = _openGeneralSettingsWindow().whenComplete(() {
      _settingsOpenInFlight = null;
    });
    return _settingsOpenInFlight;
  }

  @override
  Future<void> openProjectWorkspaceWindow({
    required String projectName,
    required String projectRootPath,
  }) async {
    _disarmHubStartupRestoreSweep();
    final String normalizedName = projectName.trim().isEmpty
        ? 'Genaisys Project'
        : projectName.trim();
    final String normalizedPath = projectRootPath.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(
        projectRootPath,
        'projectRootPath',
        'must not be empty',
      );
    }

    if (_launchContext.windowMode == DesktopWindowMode.projectWorkspace &&
        !_launchContext.isSubWindow) {
      // Main project workspace window is already active; open/focus can stay in
      // this window class for now to avoid duplicate unmanaged main windows.
      await _focusCurrentWindow();
      return;
    }

    final String? existingWindowId =
        await _discoverProjectWorkspaceWindowIdByPath(normalizedPath);
    if (existingWindowId != null) {
      final bool focused = await _tryFocusRemoteWindow(
        windowId: existingWindowId,
        expectedMode: DesktopWindowMode.projectWorkspace,
      );
      if (focused) {
        return;
      }
    }

    final String payload = _projectWorkspacePayload(
      projectName: normalizedName,
      projectRootPath: normalizedPath,
    );
    final ManagedSubWindow projectWindow = await _multiWindowApi
        .createWindow(payload: payload)
        .timeout(const Duration(seconds: 3));
    // Title is set by the sub-window itself via WindowOptions during its
    // own initialization (from payload project_name).
    await projectWindow.show().timeout(const Duration(seconds: 2));
  }

  Future<void> _openGeneralSettingsWindow() async {
    if (_launchContext.windowMode == DesktopWindowMode.settingsWorkspace) {
      await _focusCurrentWindow();
      return;
    }

    final String? discoveredSettingsId = await _discoverWindowIdByMode(
      DesktopWindowMode.settingsWorkspace,
    );
    if (discoveredSettingsId != null) {
      _settingsWindowId = discoveredSettingsId;
      final bool focused = await _tryFocusRemoteWindow(
        windowId: discoveredSettingsId,
        expectedMode: DesktopWindowMode.settingsWorkspace,
      );
      if (focused) {
        return;
      }
      _settingsWindowId = null;
    }

    await _createAndShowSettingsWindowWithRetry();
  }

  Future<void> _createAndShowSettingsWindowWithRetry() async {
    try {
      await _createAndShowSettingsWindow();
      return;
    } on MissingPluginException {
      _settingsWindowId = null;
      rethrow;
    } on PlatformException {
      _settingsWindowId = null;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _createAndShowSettingsWindow();
    } on TimeoutException {
      _settingsWindowId = null;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _createAndShowSettingsWindow();
    }
  }

  Future<void> _createAndShowSettingsWindow() async {
    final String payload = _settingsWindowPayload();
    final ManagedSubWindow settingsWindow = await _multiWindowApi
        .createWindow(payload: payload)
        .timeout(const Duration(seconds: 3));
    _settingsWindowId = settingsWindow.windowId;
    // Title is set by the sub-window itself via WindowOptions during its
    // own initialization.
    await settingsWindow.show().timeout(const Duration(seconds: 2));
  }

  String _settingsWindowPayload() {
    return jsonEncode(<String, Object?>{
      WindowLaunchContext.payloadWindowModeKey:
          DesktopWindowMode.settingsWorkspace.key,
      WindowLaunchContext.payloadProjectNameKey: 'Application Settings',
      if (_launchContext.windowId != null)
        WindowLaunchContext.payloadParentWindowIdKey: _launchContext.windowId,
    });
  }

  String _projectWorkspacePayload({
    required String projectName,
    required String projectRootPath,
  }) {
    return jsonEncode(<String, Object?>{
      WindowLaunchContext.payloadWindowModeKey:
          DesktopWindowMode.projectWorkspace.key,
      WindowLaunchContext.payloadProjectNameKey: projectName,
      WindowLaunchContext.payloadProjectRootPathKey: projectRootPath,
      if (_launchContext.windowId != null)
        WindowLaunchContext.payloadParentWindowIdKey: _launchContext.windowId,
    });
  }

  Future<void> _focusMainWindow() async {
    if (!_launchContext.isSubWindow) {
      await _focusCurrentWindow();
      return;
    }

    // Discover the main (hub) window by scanning all sub-windows and finding
    // the one that identifies as project_hub, or use the parent_window_id if
    // available in the launch payload.
    final String? parentWindowId = _coerceString(
      _launchContext.arguments[WindowLaunchContext.payloadParentWindowIdKey],
    );
    if (parentWindowId == null || parentWindowId.isEmpty) {
      return;
    }

    try {
      await _multiWindowApi
          .invokeMethod(
            targetWindowId: parentWindowId,
            method: _focusWindowMethod,
          )
          .timeout(const Duration(milliseconds: 650));
    } on MissingPluginException {
      // Main window messaging is not available.
    } on PlatformException {
      // Main window may already be gone during process shutdown.
    } on TimeoutException {
      // Best-effort only.
    }
  }

  Future<bool> _tryFocusRemoteWindow({
    required String windowId,
    required DesktopWindowMode expectedMode,
  }) async {
    await _tryShowWindowById(windowId);

    final bool focused = await _invokeIdentityChecked(
      windowId: windowId,
      method: _focusWindowMethod,
      expectedMode: expectedMode,
    );
    if (focused) {
      return true;
    }

    // Fallback identity probe. Some platform/plugin combinations may fail to
    // handle the focus method even though the window still exists.
    final bool identified = await _invokeIdentityChecked(
      windowId: windowId,
      method: _identifyWindowMethod,
      expectedMode: expectedMode,
    );
    return identified;
  }

  Future<String?> _discoverWindowIdByMode(DesktopWindowMode mode) async {
    final List<String> ids = await _discoverWindowIdsByMode(mode);
    if (ids.isEmpty) {
      return null;
    }
    return ids.first;
  }

  Future<String?> _discoverProjectWorkspaceWindowIdByPath(
    String projectRootPath,
  ) async {
    final String targetPath = projectRootPath.trim();
    if (targetPath.isEmpty) {
      return null;
    }

    try {
      final List<String> subWindowIds = await _multiWindowApi
          .getAllSubWindowIds()
          .timeout(const Duration(milliseconds: 700));
      for (final String windowId in subWindowIds) {
        final Map<String, Object?>? identity = await _queryWindowIdentity(
          windowId,
        );
        if (identity == null) {
          continue;
        }
        final Object? mode = identity[WindowLaunchContext.payloadWindowModeKey];
        if (mode != DesktopWindowMode.projectWorkspace.key) {
          continue;
        }
        final String? windowPath = _coerceString(
          identity[WindowLaunchContext.payloadProjectRootPathKey],
        );
        if (windowPath == null) {
          continue;
        }
        if (windowPath.trim() == targetPath) {
          return windowId;
        }
      }
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on TimeoutException {
      return null;
    }

    return null;
  }

  Future<List<String>> _discoverWindowIdsByMode(DesktopWindowMode mode) async {
    try {
      final List<String> subWindowIds = await _multiWindowApi
          .getAllSubWindowIds()
          .timeout(const Duration(milliseconds: 700));
      final List<String> matchingIds = <String>[];
      for (final String windowId in subWindowIds) {
        final bool matchesMode = await _invokeIdentityChecked(
          windowId: windowId,
          method: _identifyWindowMethod,
          expectedMode: mode,
        );
        if (matchesMode) {
          matchingIds.add(windowId);
        }
      }
      return matchingIds;
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    } on TimeoutException {
      return const <String>[];
    }
  }

  Future<void> _closeStaleSettingsWindowsOnStartup() async {
    final List<String> settingsWindowIds = await _discoverWindowIdsByMode(
      DesktopWindowMode.settingsWorkspace,
    );
    if (settingsWindowIds.isEmpty) {
      return;
    }

    for (final String windowId in settingsWindowIds) {
      await _tryCloseWindowById(windowId);
    }

    _settingsWindowId = null;
  }

  Future<void> _runHubStartupRestoreSweep() async {
    // On newer macOS builds, stale subwindow state can be restored after the
    // root hub launches. Keep closing restored subwindows for a short startup
    // window until the user explicitly opens a new window.
    const int maxAttempts = 95;
    const Duration interval = Duration(milliseconds: 450);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!_hubStartupRestoreSweepArmed) {
        return;
      }

      if (_hubStaleStartupWindowIds.isEmpty) {
        _hubStartupRestoreSweepArmed = false;
        return;
      }

      final Set<String> activeSubWindowIds = (await _listSubWindowIds())
          .toSet();
      // Keep only IDs that still exist; once gone, they are considered cleaned.
      _hubStaleStartupWindowIds.removeWhere(
        (String staleId) => !activeSubWindowIds.contains(staleId),
      );

      if (!_hubStartupRestoreSweepArmed || _hubStaleStartupWindowIds.isEmpty) {
        _hubStartupRestoreSweepArmed = false;
        return;
      }

      final List<String> staleIdsToClose = _hubStaleStartupWindowIds.toList(
        growable: false,
      );
      for (final String windowId in staleIdsToClose) {
        if (!_hubStartupRestoreSweepArmed) {
          return;
        }
        await _tryCloseWindowById(windowId);
      }

      await Future<void>.delayed(interval);
    }

    _hubStartupRestoreSweepArmed = false;
    _settingsWindowId = null;
    _hubStaleStartupWindowIds.clear();
  }

  void _disarmHubStartupRestoreSweep() {
    _hubStartupRestoreSweepArmed = false;
    _hubStaleStartupWindowIds.clear();
  }

  Future<List<String>> _listSubWindowIds() async {
    try {
      return await _multiWindowApi.getAllSubWindowIds().timeout(
        const Duration(milliseconds: 500),
      );
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    } on TimeoutException {
      return const <String>[];
    }
  }

  Future<void> _closeSettingsWindowsForProjectClose() async {
    final String? knownSettingsWindowId = _settingsWindowId;
    final Set<String> settingsWindowIds = <String>{
      ...await _discoverWindowIdsByMode(DesktopWindowMode.settingsWorkspace),
      ?knownSettingsWindowId,
    };
    if (settingsWindowIds.isEmpty) {
      return;
    }

    for (final String windowId in settingsWindowIds) {
      await _tryCloseWindowById(windowId);
    }

    _settingsWindowId = null;
  }

  Future<void> _tryCloseWindowById(String windowId) async {
    try {
      await _multiWindowApi
          .closeWindowById(windowId)
          .timeout(const Duration(milliseconds: 500));
    } on MissingPluginException {
      // Best-effort only.
    } on PlatformException {
      // Best-effort only.
    } on TimeoutException {
      // Best-effort only.
    }
  }

  Future<void> _tryShowWindowById(String windowId) async {
    try {
      await _multiWindowApi
          .showWindowById(windowId)
          .timeout(const Duration(milliseconds: 350));
    } on MissingPluginException {
      // Best-effort only.
    } on PlatformException {
      // Best-effort only.
    } on TimeoutException {
      // Best-effort only.
    }
  }

  Future<bool> _invokeIdentityChecked({
    required String windowId,
    required String method,
    required DesktopWindowMode expectedMode,
  }) async {
    try {
      final Object? result = await _multiWindowApi
          .invokeMethod(targetWindowId: windowId, method: method)
          .timeout(const Duration(milliseconds: 650));
      return _isWindowIdentity(
        result,
        expectedWindowId: windowId,
        expectedMode: expectedMode,
      );
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<Map<String, Object?>?> _queryWindowIdentity(String windowId) async {
    try {
      final Object? result = await _multiWindowApi
          .invokeMethod(targetWindowId: windowId, method: _identifyWindowMethod)
          .timeout(const Duration(milliseconds: 650));
      if (result is! Map) {
        return null;
      }
      return result.map<String, Object?>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  bool _isWindowIdentity(
    Object? raw, {
    required String expectedWindowId,
    required DesktopWindowMode expectedMode,
  }) {
    if (raw is! Map) {
      return false;
    }
    final Object? mode = raw[WindowLaunchContext.payloadWindowModeKey];
    final String? windowId = _coerceString(raw['window_id']);
    return mode == expectedMode.key && windowId == expectedWindowId;
  }

  String? _coerceString(Object? raw) {
    if (raw is String) {
      return raw;
    }
    return null;
  }

  Future<void> _configureProjectWorkspaceCloseInterception() async {
    if (!_windowManagerReady ||
        _launchContext.windowMode != DesktopWindowMode.projectWorkspace) {
      return;
    }

    try {
      await windowManager.setPreventClose(true);
    } on MissingPluginException {
      // Best-effort only.
    } on PlatformException {
      // Best-effort only.
    }
  }

  Future<void> _handleProjectWorkspaceCloseRequest() async {
    if (_projectWorkspaceCloseInFlight) {
      return;
    }
    _projectWorkspaceCloseInFlight = true;
    try {
      await _closeSettingsWindowsForProjectClose();
      await _focusMainWindow();

      if (_launchContext.isSubWindow) {
        await _closeProjectWorkspaceSubWindow();
      } else {
        // Root project-workspace is not expected in the normal app flow
        // (project hub is the root window). If this happens anyway, fall back
        // to closing the root window to avoid running headless.
        _allowProjectWorkspaceClose = true;
        try {
          if (_windowManagerReady) {
            await windowManager.setPreventClose(false);
            await windowManager.close();
          }
        } finally {
          _allowProjectWorkspaceClose = false;
        }
      }
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to close project workspace cleanly: $error');
      }
    } finally {
      _projectWorkspaceCloseInFlight = false;
    }
  }

  Future<void> _closeProjectWorkspaceSubWindow() async {
    final String? windowId = _launchContext.windowId;
    if (windowId == null) {
      return;
    }

    _allowProjectWorkspaceClose = true;
    try {
      if (_windowManagerReady) {
        await windowManager.setPreventClose(false);
      }
      await _multiWindowApi
          .closeWindowById(windowId)
          .timeout(const Duration(milliseconds: 700));
    } on MissingPluginException {
      if (_windowManagerReady) {
        await windowManager.close();
      }
    } on PlatformException {
      if (_windowManagerReady) {
        await windowManager.close();
      }
    } on TimeoutException {
      if (_windowManagerReady) {
        await windowManager.close();
      }
    } finally {
      _allowProjectWorkspaceClose = false;
    }
  }

  @override
  Future<void> closeWindow() async {
    if (_launchContext.windowMode == DesktopWindowMode.projectWorkspace) {
      await _handleProjectWorkspaceCloseRequest();
      return;
    }

    if (_launchContext.isSubWindow && _launchContext.windowId != null) {
      await _multiWindowApi.closeWindowById(_launchContext.windowId!);
      return;
    }

    if (_windowManagerReady) {
      await windowManager.close();
    }
  }

  @override
  Future<void> dispose() async {
    _disarmHubStartupRestoreSweep();
    await _notifyMainWindowOnSettingsClose();
    if (!_launchContext.isSubWindow) {
      _multiWindowApi.setMessageHandler(null);
    }
    if (_windowManagerReady) {
      windowManager.removeListener(this);
    }
  }

  Future<void> _notifyMainWindowOnSettingsClose() async {
    if (_settingsCloseNotified) {
      return;
    }
    if (!_launchContext.isSubWindow ||
        _launchContext.windowMode != DesktopWindowMode.settingsWorkspace ||
        _launchContext.windowId == null) {
      return;
    }

    final String? parentWindowId = _coerceString(
      _launchContext.arguments[WindowLaunchContext.payloadParentWindowIdKey],
    );
    if (parentWindowId == null || parentWindowId.isEmpty) {
      return;
    }

    _settingsCloseNotified = true;
    try {
      await _multiWindowApi.invokeMethod(
        targetWindowId: parentWindowId,
        method: _windowClosedMethod,
        arguments: <String, Object?>{
          WindowLaunchContext.payloadWindowModeKey:
              DesktopWindowMode.settingsWorkspace.key,
          'window_id': _launchContext.windowId!,
        },
      );
    } on MissingPluginException {
      // Main-window channel is not available anymore.
    } on PlatformException {
      // The main window may already be gone during process shutdown.
    }
  }
}
