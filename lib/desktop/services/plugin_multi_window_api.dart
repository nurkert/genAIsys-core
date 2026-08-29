// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import 'multi_window_api.dart';

class DesktopMultiWindowApi implements MultiWindowApi {
  @override
  void setMessageHandler(MultiWindowMessageHandler? handler) {
    // In 0.3.0, setWindowMethodHandler is per-window and async.
    // Fire-and-forget the registration; the handler is effective once the
    // underlying platform channel call completes.
    _registerHandler(handler);
  }

  Future<void> _registerHandler(MultiWindowMessageHandler? handler) async {
    final WindowController controller =
        await WindowController.fromCurrentEngine();
    if (handler == null) {
      await controller.setWindowMethodHandler(null);
      return;
    }

    await controller.setWindowMethodHandler((MethodCall call) async {
      return handler(
        MultiWindowMessage(method: call.method, arguments: call.arguments),
      );
    });
  }

  @override
  Future<ManagedSubWindow> createWindow({required String payload}) async {
    final WindowController controller = await WindowController.create(
      WindowConfiguration(arguments: payload, hiddenAtLaunch: true),
    );
    return _DesktopManagedSubWindow(controller);
  }

  @override
  Future<List<String>> getAllSubWindowIds() async {
    final List<WindowController> all = await WindowController.getAll();
    final WindowController current = await WindowController.fromCurrentEngine();
    return all
        .where((WindowController c) => c.windowId != current.windowId)
        .map((WindowController c) => c.windowId)
        .toList();
  }

  @override
  Future<Object?> invokeMethod({
    required String targetWindowId,
    required String method,
    Object? arguments,
  }) {
    return WindowController.fromWindowId(
      targetWindowId,
    ).invokeMethod(method, arguments);
  }

  @override
  Future<void> showWindowById(String windowId) {
    return WindowController.fromWindowId(windowId).show();
  }

  @override
  Future<void> closeWindowById(String windowId) {
    // 0.3.0 removed close() from WindowController.
    // Send a window_close method call that the sub-window handles by exiting.
    return WindowController.fromWindowId(windowId).invokeMethod('window_close');
  }
}

class _DesktopManagedSubWindow implements ManagedSubWindow {
  _DesktopManagedSubWindow(this._controller);

  final WindowController _controller;

  @override
  String get windowId => _controller.windowId;

  @override
  Future<void> show() => _controller.show();
}
