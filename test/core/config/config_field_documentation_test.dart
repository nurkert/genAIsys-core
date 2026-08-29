// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/config/config_field_registry.dart';

/// The settings UI renders `description` as the explanation under each setting.
/// Without one it falls back to the raw config key, which tells a user nothing.
/// These tests keep the settings surface self-explanatory as keys are added.
void main() {
  test('every config field carries a description', () {
    final undocumented = configFieldRegistry
        .where((f) => (f.description ?? '').trim().isEmpty)
        .map((f) => f.qualifiedKey)
        .toList();

    expect(
      undocumented,
      isEmpty,
      reason:
          'These config keys would show only their raw key in the settings '
          'UI. Add a `description:` to each:\n${undocumented.join('\n')}',
    );
  });

  test('descriptions are usable one-liners, not paragraphs', () {
    final tooLong = configFieldRegistry
        .where((f) => (f.description ?? '').length > 200)
        .map((f) => f.qualifiedKey)
        .toList();

    expect(
      tooLong,
      isEmpty,
      reason: 'Settings rows show one line; shorten:\n${tooLong.join('\n')}',
    );
  });

  test('every config field is covered by the configuration reference', () {
    final doc = File('docs/reference/configuration-reference.md');
    expect(doc.existsSync(), isTrue, reason: 'Reference doc must exist');
    final contents = doc.readAsStringSync();

    final missing = configFieldRegistry
        .map((f) => f.qualifiedKey)
        .where((key) => !contents.contains(key))
        .toList();

    expect(
      missing,
      isEmpty,
      reason:
          'Documentation parity: add these keys to '
          'docs/reference/configuration-reference.md:\n${missing.join('\n')}',
    );
  });
}
