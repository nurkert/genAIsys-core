// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Lightweight cross-window message model independent from package types.
class MultiWindowMessage {
  const MultiWindowMessage({required this.method, required this.arguments});

  final String method;
  final Object? arguments;
}

typedef MultiWindowMessageHandler =
    Future<Object?> Function(MultiWindowMessage message);

/// Package-agnostic contract for desktop sub-window orchestration.
///
/// This boundary allows replacing `desktop_multi_window` later with Flutter's
/// native multi-window APIs without changing window service or UI layers.
abstract class MultiWindowApi {
  void setMessageHandler(MultiWindowMessageHandler? handler);

  Future<ManagedSubWindow> createWindow({required String payload});
  Future<List<String>> getAllSubWindowIds();

  Future<Object?> invokeMethod({
    required String targetWindowId,
    required String method,
    Object? arguments,
  });

  Future<void> showWindowById(String windowId);
  Future<void> closeWindowById(String windowId);
}

abstract class ManagedSubWindow {
  String get windowId;

  Future<void> show();
}
