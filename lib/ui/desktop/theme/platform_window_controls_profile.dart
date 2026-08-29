// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ui_chrome_config.dart';

enum DesktopWindowControlsSide { left, right }

@immutable
class PlatformWindowControlsProfile {
  const PlatformWindowControlsProfile({
    required this.side,
    required this.regularInset,
    required this.fullscreenInset,
  });

  final DesktopWindowControlsSide side;
  final double regularInset;
  final double fullscreenInset;

  bool get animatesWithFullscreen => regularInset != fullscreenInset;

  double insetFor({required bool fullscreen}) {
    return fullscreen ? fullscreenInset : regularInset;
  }
}

class PlatformWindowControlsResolver {
  const PlatformWindowControlsResolver({Map<String, String>? environment})
    : _environment = environment;

  final Map<String, String>? _environment;

  PlatformWindowControlsProfile resolve({
    required TargetPlatform platform,
    bool fullscreenAware = true,
  }) {
    switch (platform) {
      case TargetPlatform.macOS:
        return PlatformWindowControlsProfile(
          side: DesktopWindowControlsSide.left,
          regularInset: UiChromeConfig.topBarWindowControlsInsetMac,
          fullscreenInset: fullscreenAware
              ? UiChromeConfig.topBarWindowControlsInsetMacFullscreen
              : UiChromeConfig.topBarWindowControlsInsetMac,
        );
      case TargetPlatform.windows:
        return const PlatformWindowControlsProfile(
          side: DesktopWindowControlsSide.right,
          regularInset: UiChromeConfig.topBarWindowControlsInsetWindows,
          fullscreenInset: UiChromeConfig.topBarWindowControlsInsetWindows,
        );
      case TargetPlatform.linux:
        final DesktopWindowControlsSide linuxSide = _resolveLinuxSide();
        return PlatformWindowControlsProfile(
          side: linuxSide,
          regularInset: UiChromeConfig.topBarWindowControlsInsetLinux,
          fullscreenInset: UiChromeConfig.topBarWindowControlsInsetLinux,
        );
      default:
        return const PlatformWindowControlsProfile(
          side: DesktopWindowControlsSide.right,
          regularInset: UiChromeConfig.topBarWindowControlsInsetDesktop,
          fullscreenInset: UiChromeConfig.topBarWindowControlsInsetDesktop,
        );
    }
  }

  DesktopWindowControlsSide _resolveLinuxSide() {
    final DesktopWindowControlsSide? explicitOverride = _parseSide(
      _readEnv('GENAISYS_WINDOW_CONTROLS_SIDE'),
    );
    if (explicitOverride != null) {
      return explicitOverride;
    }

    final String desktopSession =
        '${_readEnv('XDG_CURRENT_DESKTOP') ?? ''}'
                '${_readEnv('DESKTOP_SESSION') ?? ''}'
            .toLowerCase();
    if (desktopSession.contains('unity') ||
        desktopSession.contains('pantheon')) {
      return DesktopWindowControlsSide.left;
    }
    return DesktopWindowControlsSide.right;
  }

  String? _readEnv(String key) {
    final String? value = (_environment ?? Platform.environment)[key];
    if (value == null) {
      return null;
    }
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  DesktopWindowControlsSide? _parseSide(String? rawValue) {
    if (rawValue == null) {
      return null;
    }

    switch (rawValue.trim().toLowerCase()) {
      case 'left':
      case 'leading':
        return DesktopWindowControlsSide.left;
      case 'right':
      case 'trailing':
        return DesktopWindowControlsSide.right;
      default:
        return null;
    }
  }
}
