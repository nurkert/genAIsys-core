import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/ui/desktop/theme/platform_window_controls_profile.dart';
import 'package:genaisys/ui/desktop/theme/ui_chrome_config.dart';

void main() {
  test('resolver returns left controls for macOS with fullscreen inset', () {
    const resolver = PlatformWindowControlsResolver();

    final profile = resolver.resolve(platform: TargetPlatform.macOS);

    expect(profile.side, DesktopWindowControlsSide.left);
    expect(profile.regularInset, UiChromeConfig.topBarWindowControlsInsetMac);
    expect(
      profile.fullscreenInset,
      UiChromeConfig.topBarWindowControlsInsetMacFullscreen,
    );
  });

  test('resolver returns right controls for Windows', () {
    const resolver = PlatformWindowControlsResolver();

    final profile = resolver.resolve(platform: TargetPlatform.windows);

    expect(profile.side, DesktopWindowControlsSide.right);
    expect(
      profile.regularInset,
      UiChromeConfig.topBarWindowControlsInsetWindows,
    );
    expect(
      profile.fullscreenInset,
      UiChromeConfig.topBarWindowControlsInsetWindows,
    );
  });

  test('linux resolver honors explicit left override', () {
    const resolver = PlatformWindowControlsResolver(
      environment: <String, String>{'GENAISYS_WINDOW_CONTROLS_SIDE': 'left'},
    );

    final profile = resolver.resolve(platform: TargetPlatform.linux);

    expect(profile.side, DesktopWindowControlsSide.left);
    expect(profile.regularInset, UiChromeConfig.topBarWindowControlsInsetLinux);
  });

  test('linux resolver honors explicit right override', () {
    const resolver = PlatformWindowControlsResolver(
      environment: <String, String>{'GENAISYS_WINDOW_CONTROLS_SIDE': 'right'},
    );

    final profile = resolver.resolve(platform: TargetPlatform.linux);

    expect(profile.side, DesktopWindowControlsSide.right);
    expect(profile.regularInset, UiChromeConfig.topBarWindowControlsInsetLinux);
  });
}
