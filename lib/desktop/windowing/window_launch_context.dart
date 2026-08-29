// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';

import 'desktop_window_mode.dart';

/// Immutable bootstrap context for one desktop window isolate.
class WindowLaunchContext {
  const WindowLaunchContext({
    required this.windowMode,
    required this.windowModeKey,
    required this.isSubWindow,
    required this.windowId,
    required this.arguments,
  });

  static const String payloadWindowModeKey = 'window_mode';
  static const String payloadProjectNameKey = 'project_name';
  static const String payloadProjectRootPathKey = 'project_root_path';
  static const String payloadParentWindowIdKey = 'parent_window_id';
  static const String payloadThemeModeKey = 'theme_mode';
  static const String multiWindowFlag = 'multi_window';

  final DesktopWindowMode windowMode;
  final String windowModeKey;
  final bool isSubWindow;
  final String? windowId;
  final Map<String, Object?> arguments;

  WindowLaunchContext copyWith({
    DesktopWindowMode? windowMode,
    String? windowModeKey,
    bool? isSubWindow,
    Object? windowId = _noChange,
    Map<String, Object?>? arguments,
  }) {
    return WindowLaunchContext(
      windowMode: windowMode ?? this.windowMode,
      windowModeKey: windowModeKey ?? this.windowModeKey,
      isSubWindow: isSubWindow ?? this.isSubWindow,
      windowId: identical(windowId, _noChange)
          ? this.windowId
          : windowId as String?,
      arguments: arguments ?? this.arguments,
    );
  }

  factory WindowLaunchContext.fromProcessArgs({
    required List<String> args,
    required String fallbackWindowMode,
  }) {
    final bool isSubWindow = args.length >= 3 && args.first == multiWindowFlag;
    final String? windowId = isSubWindow ? args[1] : null;
    final Map<String, Object?> payload = isSubWindow
        ? _parsePayload(args[2])
        : const <String, Object?>{};

    final String requestedMode =
        _asString(payload[payloadWindowModeKey]) ?? fallbackWindowMode;
    final DesktopWindowMode resolvedMode = DesktopWindowModeParser.parse(
      requestedMode,
    );

    return WindowLaunchContext(
      windowMode: resolvedMode,
      windowModeKey: resolvedMode.key,
      isSubWindow: isSubWindow,
      windowId: windowId,
      arguments: payload,
    );
  }

  static Map<String, Object?> _parsePayload(String rawPayload) {
    if (rawPayload.trim().isEmpty) {
      return const <String, Object?>{};
    }

    try {
      final dynamic decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        return const <String, Object?>{};
      }
      return decoded.map<String, Object?>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }
}

const Object _noChange = Object();
