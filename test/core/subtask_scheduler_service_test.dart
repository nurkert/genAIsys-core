import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/subtask_scheduler_service.dart';

void main() {
  test(
    'SubtaskSchedulerService falls back to queue order without spec file',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_no_spec_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final scheduler = SubtaskSchedulerService();
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const ['A', 'B', 'C'],
      );

      expect(result.selectedSubtask, 'A');
      expect(result.remainingQueue, equals(['B', 'C']));
      expect(result.dependencyAware, isFalse);
      expect(result.cycleFallback, isFalse);
      expect(result.tieBreakerFields, isNotEmpty);
      expect(result.candidates, hasLength(3));
    },
  );

  test('SubtaskSchedulerService selects dependency-ready subtask', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_subtask_scheduler_deps_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final path =
        '${layout.taskSpecsDir}${Platform.pathSeparator}main-task-subtasks.md';
    File(path).writeAsStringSync('''
# Subtasks

Parent: Main Task

## Subtasks
1. Run integration checks (depends on: 2)
2. Implement command scheduler service
3. Update docs (depends on: 2)
''');

    final scheduler = SubtaskSchedulerService();
    final result = scheduler.selectNext(
      temp.path,
      activeTaskTitle: 'Main Task',
      activeTaskId: 'task-1',
      queue: const [
        'Run integration checks',
        'Implement command scheduler service',
        'Update docs',
      ],
    );

    expect(result.selectedSubtask, 'Implement command scheduler service');
    expect(
      result.remainingQueue,
      equals(['Run integration checks', 'Update docs']),
    );
    expect(result.dependencyAware, isTrue);
    expect(result.cycleFallback, isFalse);
  });

  test(
    'SubtaskSchedulerService uses cycle fallback when all queued are blocked',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_cycle_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final path =
          '${layout.taskSpecsDir}${Platform.pathSeparator}main-task-subtasks.md';
      File(path).writeAsStringSync('''
# Subtasks

## Subtasks
1. Build API client (depends on: 2)
2. Build transport layer (depends on: 1)
''');

      final scheduler = SubtaskSchedulerService();
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const ['Build API client', 'Build transport layer'],
      );

      expect(result.selectedSubtask, 'Build API client');
      expect(result.remainingQueue, equals(['Build transport layer']));
      expect(result.dependencyAware, isTrue);
      expect(result.cycleFallback, isTrue);
    },
  );

  test('SubtaskSchedulerService is repeatable for identical input', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_subtask_scheduler_repeatable_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);

    final scheduler = SubtaskSchedulerService();
    final picks = <String>[];
    for (var i = 0; i < 10; i += 1) {
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const [
          '[P2] [DOCS] Document rollout',
          '[P1] [CORE] Implement scheduler engine',
          '[P1] [SEC] Add policy hardening',
        ],
      );
      picks.add(result.selectedSubtask);
    }

    expect(picks.toSet(), hasLength(1));
    expect(picks.first, '[P1] [CORE] Implement scheduler engine');
  });

  test('SubtaskSchedulerService can replay saved candidate snapshot', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_subtask_scheduler_replay_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);

    final scheduler = SubtaskSchedulerService();
    final selection = scheduler.selectNext(
      temp.path,
      activeTaskTitle: 'Main Task',
      activeTaskId: 'task-1',
      queue: const [
        '[P2] [DOCS] Document rollout',
        '[P1] [CORE] Implement scheduler engine',
        '[P1] [SEC] Add policy hardening',
      ],
    );
    final replayed = scheduler.replaySelection(
      candidates: selection.candidates,
    );
    expect(replayed.subtask, selection.selectedSubtask);
    expect(replayed.stableFinalKey, selection.selectedCandidate.stableFinalKey);
  });

  test(
    'SubtaskSchedulerService preserves authored queue order before lexical tie-break',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_queue_order_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final scheduler = SubtaskSchedulerService();
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const [
          'Zeta implement feature hook',
          'Alpha add regression tests',
        ],
      );

      expect(
        result.tieBreakerFields,
        equals(<String>[
          'dependency_ready',
          'priority_rank',
          'category_rank',
          'queue_position',
          'stable_final_key',
        ]),
      );
      expect(result.selectedSubtask, 'Zeta implement feature hook');
    },
  );

  test(
    'SubtaskSchedulerService deprioritizes verify-and-gate subtasks behind implementation work',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_deprioritize_verify_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);

      final scheduler = SubtaskSchedulerService();
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const [
          'Verify and gate: run `dart analyze` and full tests',
          'Baseline and contract lock: add regression tests',
          'Extract schema module: create foo.dart',
        ],
      );

      expect(
        result.selectedSubtask,
        'Baseline and contract lock: add regression tests',
      );
      expect(
        result.remainingQueue,
        equals([
          'Verify and gate: run `dart analyze` and full tests',
          'Extract schema module: create foo.dart',
        ]),
      );
    },
  );

  test(
    'SubtaskSchedulerService skips subtask not found in spec and selects next',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_skip_not_in_spec_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final specPath =
          '${layout.taskSpecsDir}${Platform.pathSeparator}main-task-subtasks.md';
      File(specPath).writeAsStringSync('''
# Subtasks

## Subtasks
1. Implement the parser
2. Add regression tests
''');

      final scheduler = SubtaskSchedulerService();
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const [
          'Orphaned subtask that is not in spec',
          'Implement the parser',
          'Add regression tests',
        ],
      );

      // The orphaned subtask should be skipped.
      expect(result.selectedSubtask, 'Implement the parser');
      expect(result.remainingQueue, equals(['Add regression tests']));
      expect(result.skippedSubtasks, hasLength(1));
      expect(result.skippedSubtasks.first.subtask,
          'Orphaned subtask that is not in spec');
      expect(result.skippedSubtasks.first.reason, 'not_in_spec');
      // Only valid subtasks appear as candidates.
      expect(result.candidates, hasLength(2));
    },
  );

  test(
    'SubtaskSchedulerService throws when all queue entries are not in spec',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_all_pruned_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final specPath =
          '${layout.taskSpecsDir}${Platform.pathSeparator}main-task-subtasks.md';
      File(specPath).writeAsStringSync('''
# Subtasks

## Subtasks
1. Real subtask Alpha
''');

      final scheduler = SubtaskSchedulerService();
      expect(
        () => scheduler.selectNext(
          temp.path,
          activeTaskTitle: 'Main Task',
          activeTaskId: 'task-1',
          queue: const [
            'Ghost entry one',
            'Ghost entry two',
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('all queue entries were pruned'),
          ),
        ),
      );
    },
  );

  test(
    'SubtaskSchedulerService does not prune when spec file is missing',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_no_spec_no_prune_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      // Deliberately do NOT create a spec file.

      final scheduler = SubtaskSchedulerService();
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const ['Alpha', 'Beta', 'Gamma'],
      );

      // All entries should pass through (no spec = no validation).
      expect(result.selectedSubtask, 'Alpha');
      expect(result.remainingQueue, equals(['Beta', 'Gamma']));
      expect(result.skippedSubtasks, isEmpty);
      expect(result.candidates, hasLength(3));
    },
  );

  test(
    'SubtaskSchedulerService prunes multiple orphaned entries and keeps valid ones',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_multi_prune_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final specPath =
          '${layout.taskSpecsDir}${Platform.pathSeparator}main-task-subtasks.md';
      File(specPath).writeAsStringSync('''
# Subtasks

## Subtasks
1. Build the API
2. Write documentation
''');

      final scheduler = SubtaskSchedulerService();
      final result = scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const [
          'Stale item X',
          'Stale item Y',
          'Build the API',
          'Stale item Z',
          'Write documentation',
        ],
      );

      expect(result.selectedSubtask, 'Build the API');
      expect(result.remainingQueue, equals(['Write documentation']));
      expect(result.skippedSubtasks, hasLength(3));
      final skippedNames =
          result.skippedSubtasks.map((entry) => entry.subtask).toList();
      expect(skippedNames, contains('Stale item X'));
      expect(skippedNames, contains('Stale item Y'));
      expect(skippedNames, contains('Stale item Z'));
      for (final entry in result.skippedSubtasks) {
        expect(entry.reason, 'not_in_spec');
      }
    },
  );

  test(
    'SubtaskSchedulerService logs subtask_spec_not_found to run log',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_run_log_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final specPath =
          '${layout.taskSpecsDir}${Platform.pathSeparator}main-task-subtasks.md';
      File(specPath).writeAsStringSync('''
# Subtasks

## Subtasks
1. Valid subtask
''');

      final scheduler = SubtaskSchedulerService();
      scheduler.selectNext(
        temp.path,
        activeTaskTitle: 'Main Task',
        activeTaskId: 'task-1',
        queue: const ['Orphan', 'Valid subtask'],
      );

      // Verify a run-log entry was written.
      final runLogFile = File(layout.runLogPath);
      expect(runLogFile.existsSync(), isTrue);
      final logContent = runLogFile.readAsStringSync();
      expect(logContent, contains('subtask_spec_not_found'));
      expect(logContent, contains('Orphan'));
    },
  );

  test(
    'SubtaskSchedulerService treats empty spec subtask section as pruning all entries',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_subtask_scheduler_empty_spec_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final specPath =
          '${layout.taskSpecsDir}${Platform.pathSeparator}main-task-subtasks.md';
      // Spec file exists but has no subtask items (no ## Subtasks section content).
      File(specPath).writeAsStringSync('''
# Subtasks

## Subtasks

## Notes
Some notes here.
''');

      final scheduler = SubtaskSchedulerService();
      expect(
        () => scheduler.selectNext(
          temp.path,
          activeTaskTitle: 'Main Task',
          activeTaskId: 'task-1',
          queue: const ['Alpha', 'Beta'],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('all queue entries were pruned'),
          ),
        ),
      );
    },
  );
}
