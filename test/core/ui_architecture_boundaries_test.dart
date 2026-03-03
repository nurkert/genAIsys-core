import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop UI does not import window manager packages directly', () {
    final List<String> violations = _findImportViolations(
      root: Directory('lib/ui'),
      forbiddenPatterns: <String>[
        'window_manager',
        'flutter_acrylic',
        'desktop_multi_window',
      ],
    );

    expect(
      violations,
      isEmpty,
      reason:
          'Desktop UI must stay decoupled from window packages.\n'
          '${violations.join('\n')}',
    );
  });

  test('only desktop service adapters may import window packages', () {
    final Directory libDir = Directory('lib');
    final List<String> violations = <String>[];

    for (final File file in _dartFiles(libDir)) {
      final String normalizedPath = file.path.replaceAll('\\', '/');
      final bool adapterFile = normalizedPath.contains('/desktop/services/');
      for (final (int lineNo, String line) in _importLines(file)) {
        final bool windowPackageImport =
            line.contains('window_manager') ||
            line.contains('flutter_acrylic') ||
            line.contains('desktop_multi_window');
        if (windowPackageImport && !adapterFile) {
          violations.add('${file.path}:$lineNo $line');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Window packages must be isolated in lib/desktop/services/**.\n'
          '${violations.join('\n')}',
    );
  });

  test('core layer does not import Flutter', () {
    final List<String> violations = _findImportViolations(
      root: Directory('lib/core'),
      forbiddenPatterns: <String>['package:flutter/'],
    );

    expect(
      violations,
      isEmpty,
      reason: 'Core must stay UI/runtime agnostic.\n${violations.join('\n')}',
    );
  });
}

List<String> _findImportViolations({
  required Directory root,
  required List<String> forbiddenPatterns,
}) {
  final List<String> violations = <String>[];

  for (final File file in _dartFiles(root)) {
    for (final (int lineNo, String line) in _importLines(file)) {
      for (final String pattern in forbiddenPatterns) {
        if (line.contains(pattern)) {
          violations.add('${file.path}:$lineNo $line');
          break;
        }
      }
    }
  }

  return violations;
}

Iterable<File> _dartFiles(Directory root) sync* {
  for (final FileSystemEntity entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    yield entity;
  }
}

Iterable<(int, String)> _importLines(File file) sync* {
  final List<String> lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i].trimLeft();
    if (line.startsWith('import ') || line.startsWith('export ')) {
      yield (i + 1, line);
    }
  }
}
