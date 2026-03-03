import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:genaisys/desktop/services/window_service_interface.dart';

class FakeWindowService implements WindowServiceInterface {
  final ValueNotifier<bool> _sidebarHidden = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _fullscreen = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _windowFocused = ValueNotifier<bool>(true);
  int openGeneralSettingsWindowCallCount = 0;
  int openProjectWorkspaceWindowCallCount = 0;
  int setBlurCallCount = 0;
  int showWindowCallCount = 0;
  int hideWindowCallCount = 0;
  bool? lastSetBlurEnabled;
  bool? lastSetBlurDarkMode;
  String? lastProjectWorkspaceName;
  String? lastProjectWorkspaceRootPath;
  Duration openGeneralSettingsWindowDelay = Duration.zero;

  @override
  ValueListenable<bool> get sidebarHidden => _sidebarHidden;

  @override
  ValueListenable<bool> get fullscreen => _fullscreen;

  @override
  ValueListenable<bool> get windowFocused => _windowFocused;

  /// Always immediately complete — no real window initialization to wait for.
  @override
  Future<void> get initialized => Future<void>.value();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> showWindow() async {
    showWindowCallCount += 1;
  }

  @override
  Future<void> hideWindow() async {
    hideWindowCallCount += 1;
  }

  @override
  Future<void> setSidebarHidden(bool hidden) async {
    _sidebarHidden.value = hidden;
  }

  @override
  Future<void> setBlur({required bool enabled, required bool darkMode}) async {
    setBlurCallCount += 1;
    lastSetBlurEnabled = enabled;
    lastSetBlurDarkMode = darkMode;
  }

  @override
  Future<void> openGeneralSettingsWindow() async {
    openGeneralSettingsWindowCallCount += 1;
    if (openGeneralSettingsWindowDelay > Duration.zero) {
      await Future<void>.delayed(openGeneralSettingsWindowDelay);
    }
  }

  @override
  Future<void> openProjectWorkspaceWindow({
    required String projectName,
    required String projectRootPath,
  }) async {
    openProjectWorkspaceWindowCallCount += 1;
    lastProjectWorkspaceName = projectName;
    lastProjectWorkspaceRootPath = projectRootPath;
  }

  @override
  Future<void> closeWindow() async {}

  void setFullscreenForTest(bool value) {
    _fullscreen.value = value;
  }

  void setWindowFocusedForTest(bool value) {
    _windowFocused.value = value;
  }
}
