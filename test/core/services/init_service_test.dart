import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/init_service.dart';

void main() {
  late Directory tempDir;
  late InitService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('genaisys_init_svc_');
    service = InitService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('creates all required files and directories', () {
    final result = service.initialize(tempDir.path);

    expect(result.root, tempDir.path);
    final layout = ProjectLayout(tempDir.path);
    expect(result.genaisysDir, layout.genaisysDir);

    // Verify required directories exist.
    for (final dir in layout.requiredDirs) {
      expect(Directory(dir).existsSync(), isTrue, reason: '$dir should exist');
    }

    // Verify required files exist.
    expect(File(layout.configPath).existsSync(), isTrue);
    expect(File(layout.tasksPath).existsSync(), isTrue);
    expect(File(layout.visionPath).existsSync(), isTrue);
    expect(File(layout.rulesPath).existsSync(), isTrue);
    expect(File(layout.statePath).existsSync(), isTrue);
    expect(File(layout.runLogPath).existsSync(), isTrue);
  });

  test('idempotent re-init does not overwrite existing files', () {
    service.initialize(tempDir.path);

    final layout = ProjectLayout(tempDir.path);
    const customContent = 'Custom vision content — do not overwrite';
    File(layout.visionPath).writeAsStringSync(customContent);

    // Re-initialize without overwrite.
    service.initialize(tempDir.path);

    expect(
      File(layout.visionPath).readAsStringSync(),
      customContent,
      reason:
          'Re-init with overwrite=false should not overwrite existing files',
    );
  });

  test('re-init with overwrite=true resets files to defaults', () {
    service.initialize(tempDir.path);

    final layout = ProjectLayout(tempDir.path);
    File(layout.visionPath).writeAsStringSync('Custom vision');

    // Re-initialize with overwrite.
    service.initialize(tempDir.path, overwrite: true);

    final content = File(layout.visionPath).readAsStringSync();
    expect(
      content,
      isNot('Custom vision'),
      reason: 'Re-init with overwrite=true should reset to default template',
    );
    expect(content, isNotEmpty);
  });

  test('generated files are valid (config parses, state has checksum)', () {
    service.initialize(tempDir.path);

    final layout = ProjectLayout(tempDir.path);

    // Config YAML should parse without error.
    final config = ProjectConfig.loadFromFile(layout.configPath);
    expect(config.gitBaseBranch, isNotEmpty);
    expect(config.safeWriteRoots, isNotEmpty);

    // STATE.json should be valid JSON with expected structure.
    final stateContent = File(layout.statePath).readAsStringSync();
    final stateJson = jsonDecode(stateContent) as Map<String, dynamic>;
    expect(stateJson, contains('version'));
    expect(stateJson['version'], 1);
    expect(stateJson, contains('workflow_stage'));
    expect(stateJson['workflow_stage'], 'idle');
  });

  test('run log contains init event after initialize', () {
    service.initialize(tempDir.path);

    final layout = ProjectLayout(tempDir.path);
    final runLogContent = File(layout.runLogPath).readAsStringSync();
    final lines = runLogContent
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(lines, isNotEmpty, reason: 'Run log should have at least one entry');

    final initEntry = lines
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .firstWhere((e) => e['event'] == 'init');
    expect(initEntry['data'], isNotNull);
    expect((initEntry['data'] as Map)['root'], tempDir.path);
  });
}
