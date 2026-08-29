import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('ProjectInitializer creates .genaisys structure', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_test_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final initializer = ProjectInitializer(temp.path);
    initializer.ensureStructure();

    final layout = initializer.layout;
    expect(Directory(layout.genaisysDir).existsSync(), isTrue);
    expect(File(layout.visionPath).existsSync(), isTrue);
    expect(File(layout.rulesPath).existsSync(), isTrue);
    expect(File(layout.tasksPath).existsSync(), isTrue);
    expect(File(layout.rootVisionCompatPath).existsSync(), isTrue);
    expect(File(layout.rootRulesCompatPath).existsSync(), isTrue);
    expect(File(layout.rootTasksCompatPath).existsSync(), isTrue);
    expect(File(layout.statePath).existsSync(), isTrue);
    expect(File(layout.runLogPath).existsSync(), isTrue);
    expect(File(layout.configPath).existsSync(), isTrue);
    expect(File(layout.evalBenchmarksPath).existsSync(), isTrue);
    expect(File(layout.evalSummaryPath).existsSync(), isTrue);
    expect(Directory(layout.agentContextsDir).existsSync(), isTrue);
    final stateJson =
        jsonDecode(File(layout.statePath).readAsStringSync())
            as Map<String, dynamic>;
    expect(stateJson['autopilot_running'], false);
    expect(stateJson['last_loop_at'], isNull);
    expect(stateJson['consecutive_failures'], 0);
    expect(stateJson['last_error'], isNull);
    expect(stateJson['current_mode'], isNull);

    final rootVisionCompat = File(
      layout.rootVisionCompatPath,
    ).readAsStringSync();
    final rootRulesCompat = File(layout.rootRulesCompatPath).readAsStringSync();
    final rootTasksCompat = File(layout.rootTasksCompatPath).readAsStringSync();
    expect(rootVisionCompat, contains('.genaisys/VISION.md'));
    expect(rootRulesCompat, contains('.genaisys/RULES.md'));
    expect(rootTasksCompat, contains('.genaisys/TASKS.md'));
  });

  test('ensureStructure creates .genaisys/.gitignore for runtime artifacts',
      () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_test_gitignore_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure();

    final layout = ProjectLayout(temp.path);
    final gitignore = File(layout.gitignorePath);
    expect(gitignore.existsSync(), isTrue);
    final content = gitignore.readAsStringSync();
    expect(content, contains('locks/'));
    expect(content, contains('STATE.json'));
    expect(content, contains('RUN_LOG.jsonl'));
    expect(content, contains('audit/'));
    expect(content, contains('evals/'));
  });

  test('ensureStructure does not overwrite existing .gitignore', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_test_gitignore_no_overwrite_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.gitignorePath).writeAsStringSync('custom\n');

    ProjectInitializer(temp.path).ensureStructure();

    expect(File(layout.gitignorePath).readAsStringSync(), equals('custom\n'));
  });
}
