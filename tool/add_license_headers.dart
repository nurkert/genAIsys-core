// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// ignore_for_file: avoid_print

import 'dart:io';

/// Prepends a BSL 1.1 license header to every .dart file under lib/ and bin/
/// that does not already have one.
///
/// Usage: dart run tool/add_license_headers.dart
/// Idempotent: re-running this script does not duplicate headers.
void main() {
  const header = '// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.\n'
      '// Licensed under the Business Source License 1.1.\n'
      '// See LICENSE in the project root for license information.\n';

  final root = Directory.current;
  final dirs = [Directory('${root.path}/lib'), Directory('${root.path}/bin')];

  var modified = 0;
  var skipped = 0;

  for (final dir in dirs) {
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final content = entity.readAsStringSync();
      if (content.startsWith('// Copyright')) {
        skipped++;
        continue;
      }

      entity.writeAsStringSync('$header\n$content');
      modified++;
    }
  }

  print('Done. $modified files modified, $skipped files skipped.');
}
