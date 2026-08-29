// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import 'desktop_strings.dart';

enum DesktopLanguage { english }

class DesktopLocalizationController extends ChangeNotifier {
  DesktopLocalizationController({
    DesktopLanguage initialLanguage = DesktopLanguage.english,
  }) : _language = initialLanguage;

  DesktopLanguage _language;

  DesktopLanguage get language => _language;

  Locale get locale {
    switch (_language) {
      case DesktopLanguage.english:
        return const Locale('en');
    }
  }

  List<Locale> get supportedLocales => const <Locale>[Locale('en')];

  DesktopStrings get strings {
    switch (_language) {
      case DesktopLanguage.english:
        return DesktopStrings.english;
    }
  }

  void setLanguage(DesktopLanguage language) {
    if (_language == language) {
      return;
    }
    _language = language;
    notifyListeners();
  }
}

class DesktopLocalizationScope
    extends InheritedNotifier<DesktopLocalizationController> {
  const DesktopLocalizationScope({
    super.key,
    required DesktopLocalizationController controller,
    required super.child,
  }) : super(notifier: controller);

  static DesktopLocalizationController of(BuildContext context) {
    final DesktopLocalizationScope? scope = context
        .dependOnInheritedWidgetOfExactType<DesktopLocalizationScope>();
    assert(
      scope?.notifier != null,
      'DesktopLocalizationScope is missing in the widget tree.',
    );
    return scope!.notifier!;
  }
}

extension DesktopLocalizationContextX on BuildContext {
  DesktopLocalizationController get localizationController =>
      DesktopLocalizationScope.of(this);

  DesktopStrings get strings => localizationController.strings;
}
