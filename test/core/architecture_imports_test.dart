import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('non-CLI layers do not import CLI types', () {
    final libDir = Directory('lib');
    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      if (!entity.path.endsWith('.dart')) {
        continue;
      }
      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (normalizedPath.contains('/core/cli/') ||
          normalizedPath.contains('/core/legacy/')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
        if (line.contains('/cli/') || line.contains('cli_models.dart')) {
          violations.add('${entity.path}:${i + 1} $line');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Forbidden CLI imports found:\n${violations.join('\n')}',
    );
  });
}
