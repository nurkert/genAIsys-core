import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

void main() {
  test('DoneService blockActive keeps repo clean in unattended mode', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_block_unattended_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    final active = tasks.first;
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(id: active.id, title: active.title),
        subtaskExecution: SubtaskExecutionState(current: 'Subtask A'),
      ),
    );

    _runGit(temp.path, ['init', '-b', 'main']);
    _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
    _runGit(temp.path, ['config', 'user.name', 'Test User']);
    File('${temp.path}${Platform.pathSeparator}.gitignore').writeAsStringSync(
      '.genaisys/RUN_LOG.jsonl\n.genaisys/STATE.json\n.genaisys/audit/\n.genaisys/locks/\n',
    );
    final tracked = File('${temp.path}${Platform.pathSeparator}tracked.txt')
      ..writeAsStringSync('base\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

    tracked.writeAsStringSync('block change\n');

    Directory(layout.locksDir).createSync(recursive: true);
    File(layout.autopilotLockPath).writeAsStringSync('lock');

    final service = DoneService();
    service.blockActive(temp.path, reason: 'Too many rejects');

    final status = Process.runSync('git', [
      'status',
      '--porcelain',
    ], workingDirectory: temp.path);
    expect(status.exitCode, 0);
    expect(status.stdout.toString().trim(), isEmpty);

    final commit = Process.runSync('git', [
      'log',
      '-1',
      '--pretty=%s',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);
    expect(commit.stdout.toString().trim(), contains('meta(task): block'));

    final stash = Process.runSync('git', [
      'stash',
      'list',
    ], workingDirectory: temp.path);
    expect(stash.exitCode, 0);
    expect(stash.stdout.toString(), contains('genaisys:task-block-context:'));

    final tasksText = File(layout.tasksPath).readAsStringSync();
    expect(tasksText, contains('[BLOCKED]'));
    expect(tasksText, contains('Too many rejects'));
  });
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode == 0) {
    return;
  }
  throw StateError(
    'git ${args.join(' ')} failed with ${result.exitCode}: ${result.stderr}',
  );
}
