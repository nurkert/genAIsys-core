// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/product_info.dart';
import 'package:genaisys/ui/desktop/localization/desktop_strings.dart';
import 'package:genaisys/ui/desktop/models/settings_models.dart';
import 'package:genaisys/ui/desktop/widgets/shell/settings_sidebar.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SizedBox(width: 260, height: 600, child: child)),
    );
  }

  Widget sidebar() => SettingsSidebar(
    cornerRadius: 12,
    strings: DesktopStrings.english,
    selectedSection: DesktopSettingsSection.general,
    onSelectSection: (_) {},
  );

  testWidgets('settings sidebar shows the running build version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(sidebar()));

    expect(find.text(ProductInfo.versionLine), findsOneWidget);
  });

  testWidgets('version line is selectable so it can be copied into a report', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(sidebar()));

    expect(
      find.byWidgetPredicate(
        (Widget w) => w is SelectableText && w.data == ProductInfo.versionLine,
      ),
      findsOneWidget,
    );
  });

  testWidgets('version line renders in dark mode too', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(sidebar(), brightness: Brightness.dark));

    expect(find.text(ProductInfo.versionLine), findsOneWidget);
  });
}
