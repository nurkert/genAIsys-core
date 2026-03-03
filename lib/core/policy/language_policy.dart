// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class LanguagePolicy {
  static const String internalLanguageCode = 'en';
  static const String defaultUserLocale = 'en-US';

  static String describe() {
    return 'Internal artifacts are always English. UI may be localized.';
  }

  static void enforceEnglish(String text, {String? context}) {
    if (!_isLikelyEnglish(text)) {
      final suffix = context == null || context.trim().isEmpty
          ? ''
          : ' ($context)';
      throw StateError('Non-English content detected$suffix.');
    }
  }

  static bool _isLikelyEnglish(String text) {
    if (text.trim().isEmpty) {
      return true;
    }
    final lower = text.toLowerCase();
    if (RegExp(r'[äöüß]').hasMatch(lower)) {
      return false;
    }
    const markers = [
      'nicht',
      'dass',
      'wegen',
      'über',
      'muss',
      'soll',
      'kann',
      'kein',
      'eine',
      'und',
    ];
    for (final marker in markers) {
      final pattern = RegExp('\\b$marker\\b');
      if (pattern.hasMatch(lower)) {
        return false;
      }
    }
    return true;
  }
}
