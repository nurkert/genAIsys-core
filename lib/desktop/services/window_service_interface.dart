// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Contract that isolates all desktop window and sidebar state behavior.
abstract class WindowServiceInterface {
  ValueListenable<bool> get sidebarHidden;
  ValueListenable<bool> get fullscreen;

  /// Whether the native window currently has user focus.
  ///
  /// Widgets that manage background work (polling, isolate spawning) should
  /// pause when this is `false` and resume when it becomes `true` to avoid
  /// a burst of main-thread callbacks that starve the frame scheduler on
  /// focus regain.
  ValueListenable<bool> get windowFocused;

  /// Completes when [initialize] has finished (successfully or with an error).
  ///
  /// Widgets that need the native window to be ready before they start heavy
  /// work (e.g. spawning background isolates) should `await` this future
  /// instead of racing with [initialize] via independent post-frame callbacks.
  Future<void> get initialized;

  Future<void> initialize();
  Future<void> dispose();

  /// Shows the current window. On desktop this should restore the window from
  /// minimized/hidden state and focus it.
  Future<void> showWindow();

  /// Hides the current window without terminating the process.
  ///
  /// Used for "project hub" style shells that should stay alive while
  /// workspace windows are open.
  Future<void> hideWindow();

  Future<void> setSidebarHidden(bool hidden);

  Future<void> setBlur({required bool enabled, required bool darkMode});
  Future<void> openGeneralSettingsWindow();
  Future<void> openProjectWorkspaceWindow({
    required String projectName,
    required String projectRootPath,
  });
  Future<void> closeWindow();
}
