// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'window_service_interface.dart';

class NoopWindowService implements WindowServiceInterface {
  final ValueNotifier<bool> _sidebarHidden = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _fullscreen = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _windowFocused = ValueNotifier<bool>(true);

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
  Future<void> showWindow() async {}

  @override
  Future<void> hideWindow() async {}

  @override
  Future<void> setSidebarHidden(bool hidden) async {
    _sidebarHidden.value = hidden;
  }

  @override
  Future<void> setBlur({required bool enabled, required bool darkMode}) async {}

  @override
  Future<void> openGeneralSettingsWindow() async {}

  @override
  Future<void> openProjectWorkspaceWindow({
    required String projectName,
    required String projectRootPath,
  }) async {}

  @override
  Future<void> closeWindow() async {}

  @override
  Future<void> dispose() async {}
}
