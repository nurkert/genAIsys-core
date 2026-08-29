import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI done succeeds after review approval', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_approved_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);
    _initGitWithRemote(temp.path);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(title: 'Alpha'),
        workflowStage: WorkflowStage.execution,
      ),
    );

    await runner.run([
      'review',
      'approve',
      '--note',
      'Quality gate passed: analyze/test green.',
      temp.path,
    ]);

    exitCode = 0;
    await runner.run(['done', temp.path]);

    expect(exitCode, 0);
    final updated = File(layout.tasksPath).readAsStringSync();
    expect(updated, contains('- [x] [P1] [CORE] Alpha'));

    final state = stateStore.read();
    expect(state.workflowStage, WorkflowStage.done);
  });
}

void _initGitWithRemote(String projectRoot) {
  final remote = Directory.systemTemp.createTempSync('genaisys_done_remote_');
  addTearDown(() {
    if (remote.existsSync()) {
      remote.deleteSync(recursive: true);
    }
  });

  Process.runSync('git', ['init', '-b', 'main'], workingDirectory: projectRoot);
  Process.runSync('git', [
    'config',
    'user.email',
    'test@example.com',
  ], workingDirectory: projectRoot);
  Process.runSync('git', [
    'config',
    'user.name',
    'Test',
  ], workingDirectory: projectRoot);
  Process.runSync('git', ['add', '-A'], workingDirectory: projectRoot);
  Process.runSync('git', [
    'commit',
    '--no-gpg-sign',
    '-m',
    'init',
  ], workingDirectory: projectRoot);

  Process.runSync('git', ['init', '--bare', remote.path]);
  Process.runSync('git', [
    'remote',
    'add',
    'origin',
    remote.path,
  ], workingDirectory: projectRoot);
  Process.runSync('git', [
    'push',
    '-u',
    'origin',
    'main',
  ], workingDirectory: projectRoot);
}
