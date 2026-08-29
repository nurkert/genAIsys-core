// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` are meant to be the same document.
/// They are kept as hard links, but a hard link does not survive `git checkout`
/// — switching branches silently splits them into three files that then drift
/// apart. This checks the property that actually matters: identical content.
void main() {
  test('agent instruction files stay identical', () {
    const paths = <String>['CLAUDE.md', 'AGENTS.md', 'GEMINI.md'];
    final present = paths.map(File.new).where((f) => f.existsSync()).toList();

    // The public snapshot strips all three; nothing to compare there.
    if (present.isEmpty) {
      return;
    }

    expect(
      present.length,
      paths.length,
      reason:
          'Either all three agent instruction files exist or none do. '
          'Present: ${present.map((f) => f.path).join(', ')}',
    );

    final reference = present.first.readAsStringSync();
    for (final file in present.skip(1)) {
      expect(
        file.readAsStringSync(),
        reference,
        reason:
            '${file.path} has drifted from ${present.first.path}. Re-sync them '
            '(and re-establish the hard link) before committing.',
      );
    }
  });
}
