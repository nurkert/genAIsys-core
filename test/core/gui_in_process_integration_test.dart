import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/gui/gui_activate_task_use_case.dart';
import 'package:genaisys/core/gui/gui_block_task_use_case.dart';
import 'package:genaisys/core/gui/gui_cycle_use_case.dart';
import 'package:genaisys/core/gui/gui_dashboard_use_case.dart';
import 'package:genaisys/core/gui/gui_deactivate_task_use_case.dart';
import 'package:genaisys/core/gui/gui_done_task_use_case.dart';
import 'package:genaisys/core/gui/gui_initialize_project_use_case.dart';
import 'package:genaisys/core/gui/gui_next_task_use_case.dart';
import 'package:genaisys/core/gui/gui_review_actions_use_case.dart';
import 'package:genaisys/core/gui/gui_review_status_use_case.dart';
import 'package:genaisys/core/gui/gui_spec_artifacts_use_case.dart';
import 'package:genaisys/core/gui/gui_tasks_use_case.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

const _tasksWithStatuses = '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
- [x] [P2] [DOCS] Beta
- [ ] [P3] [UI] [BLOCKED] Gamma
''';

const _tasksForActions = '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
- [ ] [P2] [DOCS] Beta
- [ ] [P3] [UI] Gamma
''';

Future<ProjectLayout> _createProject() async {
  final temp = Directory.systemTemp.createTempSync('genaisys_gui_it_');
  addTearDown(() {
    temp.deleteSync(recursive: true);
  });

  final init = GuiInitializeProjectUseCase();
  final result = await init.run(temp.path);
  expect(result.ok, isTrue);
  final layout = ProjectLayout(temp.path);
  _initGitRepoWithLocalRemote(layout.projectRoot);
  return layout;
}

void _writeTasks(ProjectLayout layout, String content) {
  File(layout.tasksPath).writeAsStringSync(content);
}

Task _taskByTitle(ProjectLayout layout, String title) {
  return TaskStore(
    layout.tasksPath,
  ).readTasks().firstWhere((task) => task.title == title);
}

void main() {
  group('GUI use cases (in-process integration)', () {
    test('read flows report tasks, next task, and dashboard counts', () async {
      final layout = await _createProject();
      _writeTasks(layout, _tasksWithStatuses);

      final tasksUseCase = GuiTasksUseCase();
      final tasksResult = await tasksUseCase.load(layout.projectRoot);

      expect(tasksResult.ok, isTrue);
      expect(tasksResult.data!.total, 3);
      expect(tasksResult.data!.tasks.length, 3);

      final statusByTitle = <String, AppTaskStatus>{
        for (final task in tasksResult.data!.tasks) task.title: task.status,
      };
      expect(statusByTitle['Alpha'], AppTaskStatus.open);
      expect(statusByTitle['Beta'], AppTaskStatus.done);
      expect(statusByTitle['Gamma'], AppTaskStatus.blocked);

      final blockedResult = await tasksUseCase.load(
        layout.projectRoot,
        query: const TaskListQuery(blockedOnly: true),
      );
      expect(blockedResult.ok, isTrue);
      expect(blockedResult.data!.tasks.length, 1);
      expect(blockedResult.data!.tasks.single.title, 'Gamma');

      final nextResult = await GuiNextTaskUseCase().load(layout.projectRoot);
      expect(nextResult.ok, isTrue);
      expect(nextResult.data!.title, 'Alpha');

      final reviewResult = await GuiReviewStatusUseCase().load(
        layout.projectRoot,
      );
      expect(reviewResult.ok, isTrue);
      expect(reviewResult.data!.status, '(none)');

      final dashboard = await GuiDashboardUseCase().load(layout.projectRoot);
      expect(dashboard.ok, isTrue);
      expect(dashboard.data!.status.tasksTotal, 3);
      expect(dashboard.data!.status.tasksOpen, 2);
      expect(dashboard.data!.status.tasksDone, 1);
      expect(dashboard.data!.status.tasksBlocked, 1);
      expect(dashboard.data!.status.activeTaskTitle, isNull);
      expect(dashboard.data!.status.reviewStatus, isNull);
      expect(dashboard.data!.review.status, '(none)');

      final cycleResult = await GuiCycleUseCase().tick(layout.projectRoot);
      expect(cycleResult.ok, isTrue);
      expect(cycleResult.data!.cycleCount, 1);
    });

    test('action flow updates state and task completion', () async {
      final layout = await _createProject();
      _writeTasks(layout, _tasksForActions);

      final target = _taskByTitle(layout, 'Beta');
      final activateResult = await GuiActivateTaskUseCase().run(
        layout.projectRoot,
        id: target.id,
      );
      expect(activateResult.ok, isTrue);
      expect(activateResult.data!.task!.id, target.id);

      final specResult = await GuiSpecArtifactsUseCase().initializeSpec(
        layout.projectRoot,
      );
      expect(specResult.ok, isTrue);
      expect(specResult.data!.created, isTrue);
      expect(File(specResult.data!.path).existsSync(), isTrue);

      // Create a committed diff so review evidence contains a non-empty patch
      // while `done` delivery preflight sees a clean worktree.
      Directory('${layout.projectRoot}/lib').createSync(recursive: true);
      File(
        '${layout.projectRoot}/lib/gui_it_marker.txt',
      ).writeAsStringSync('marker\n');
      _runGit(layout.projectRoot, ['add', '-A']);
      _runGit(layout.projectRoot, [
        'commit',
        '--no-gpg-sign',
        '-m',
        'feat: gui it marker',
      ]);

      final approveResult = await GuiReviewActionsUseCase().approve(
        layout.projectRoot,
        note: 'LGTM',
      );
      expect(approveResult.ok, isTrue);
      expect(approveResult.data!.decision, 'approved');
      expect(approveResult.data!.note, 'LGTM');

      final stateAfterReview = StateStore(layout.statePath).read();
      expect(stateAfterReview.reviewStatus, 'approved');
      expect(stateAfterReview.workflowStage, WorkflowStage.done);

      final doneResult = await GuiDoneTaskUseCase().run(layout.projectRoot);
      expect(doneResult.ok, isTrue, reason: doneResult.error?.message);
      expect(doneResult.data!.done, isTrue);
      expect(doneResult.data!.taskTitle, 'Beta');

      final tasks = TaskStore(layout.tasksPath).readTasks();
      final doneTask = tasks.firstWhere((task) => task.title == 'Beta');
      expect(doneTask.completion, TaskCompletion.done);
    });

    test('block, reject, and deactivate keep review state', () async {
      final layout = await _createProject();
      _writeTasks(layout, _tasksForActions);

      final activateResult = await GuiActivateTaskUseCase().run(
        layout.projectRoot,
      );
      expect(activateResult.ok, isTrue);
      expect(activateResult.data!.task!.title, 'Alpha');

      final blockResult = await GuiBlockTaskUseCase().run(
        layout.projectRoot,
        reason: 'Waiting for input',
      );
      expect(blockResult.ok, isTrue);
      expect(blockResult.data!.blocked, isTrue);

      final alphaLine = File(
        layout.tasksPath,
      ).readAsLinesSync().firstWhere((line) => line.contains('Alpha'));
      expect(alphaLine.contains('[BLOCKED]'), isTrue);
      expect(alphaLine.contains('Reason: Waiting for input'), isTrue);

      final rejectResult = await GuiReviewActionsUseCase().reject(
        layout.projectRoot,
        note: 'Needs changes',
      );
      expect(rejectResult.ok, isTrue);
      expect(rejectResult.data!.decision, 'rejected');

      final deactivateResult = await GuiDeactivateTaskUseCase().run(
        layout.projectRoot,
        keepReview: true,
      );
      expect(deactivateResult.ok, isTrue);
      expect(deactivateResult.data!.deactivated, isTrue);
      expect(deactivateResult.data!.keepReview, isTrue);
      expect(deactivateResult.data!.activeTaskTitle, isNull);
      expect(deactivateResult.data!.reviewStatus, 'rejected');

      final stateAfterDeactivate = StateStore(layout.statePath).read();
      expect(stateAfterDeactivate.activeTaskTitle, isNull);
      expect(stateAfterDeactivate.reviewStatus, 'rejected');
    });
  });
}

void _initGitRepoWithLocalRemote(String root) {
  _runGit(root, ['init', '-b', 'main']);
  _runGit(root, ['config', 'user.email', 'test@genaisys.local']);
  _runGit(root, ['config', 'user.name', 'Genaisys Test']);

  File('$root/.gitignore').writeAsStringSync('.genaisys/\n.remote.git/\n');
  File('$root/README.md').writeAsStringSync('# GUI IT Repo\n');

  _runGit(root, ['add', '-A']);
  _runGit(root, ['commit', '--no-gpg-sign', '-m', 'chore: init']);

  _runGit(root, ['init', '--bare', '.remote.git']);
  _runGit(root, ['remote', 'add', 'origin', '$root/.remote.git']);
  _runGit(root, ['push', '-u', 'origin', 'main']);
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} failed: ${result.stderr.toString().trim()}',
    );
  }
}
