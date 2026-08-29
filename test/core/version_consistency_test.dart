// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/cli/cli_branding.dart';

/// The release pipeline refuses to build when the git tag does not match
/// `pubspec.yaml`. That guard is worthless if the version the binary *reports*
/// drifts from the version that was tagged, so every place the version is
/// written down must agree.
void main() {
  group('version consistency', () {
    late Directory projectRoot;

    setUpAll(() {
      var dir = Directory.current;
      while (!File('${dir.path}/pubspec.yaml').existsSync()) {
        final parent = dir.parent;
        if (parent.path == dir.path) {
          fail('Could not locate the project root from ${Directory.current}');
        }
        dir = parent;
      }
      projectRoot = dir;
    });

    String versionOf(String pubspecRelativePath) {
      final file = File('${projectRoot.path}/$pubspecRelativePath');
      expect(
        file.existsSync(),
        isTrue,
        reason: '$pubspecRelativePath must exist',
      );
      final line = file.readAsLinesSync().firstWhere(
        (l) => l.startsWith('version:'),
        orElse: () => fail('No version: line in $pubspecRelativePath'),
      );
      return line.split(':')[1].trim();
    }

    test('CliBranding.version matches pubspec.yaml', () {
      expect(
        CliBranding.version,
        versionOf('pubspec.yaml'),
        reason:
            'CliBranding.version is hard-coded; bump it together with '
            'pubspec.yaml or released binaries report the wrong version.',
      );
    });

    test('CLI build pubspec matches pubspec.yaml', () {
      expect(
        versionOf('tool/pubspec.cli.yaml'),
        versionOf('pubspec.yaml'),
        reason:
            'tool/pubspec.cli.yaml builds the released CLI binary and must '
            'carry the same version as the root pubspec.',
      );
    });
  });
}
