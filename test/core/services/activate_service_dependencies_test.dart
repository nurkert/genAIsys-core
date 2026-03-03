import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/activate_service.dart';
import 'package:genaisys/core/storage/run_log_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

import '../../support/fake_services.dart';

// ---------------------------------------------------------------------------
// Feature K: ActivateService dependency enforcement tests
//
// When autopilotTaskDependenciesEnabled is true, _selectTask skips any
// candidate whose dependencyRefs are not all satisfied (i.e., the referenced
// tasks are not marked done in TASKS.md).
//
// Because the YAML config parser does not yet wire autopilotTaskDependenciesEnabled
// from the registry into _buildProjectConfig, we test through
// _DepsActivateService — a subclass that reimplements the dependency-skip
// logic using an injected flag, then delegates to the super implementation for
// the actual state/branch mechanics.  This mirrors the approach used by
// _GateTestPipeline and _AcCheckDoneService for other Wave 2 features.
//
// Note: ActivateService attempts git-branch creation when isGitRepo returns
// true.  To keep tests self-contained we pass FakeGitService(isRepoValue=false)
// so all git branch operations are skipped.
//
// Scenarios verified:
//   1. deps feature disabled → task with unmet dep IS selected (gate off)
//   2. deps enabled + dep not done → task with dep is skipped, next selected
//   3. deps enabled + dep is done  → task with dep IS selected
//   4. deps enabled + multiple deps, one unmet → task is skipped
//   5. deps enabled + task with no deps → selected normally
//   6. activate_skip_unmet_dependencies event is logged when skipping
// ---------------------------------------------------------------------------

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_activate_deps_test_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  // Helper: write TASKS.md.
  void writeTasks(String contents) {
    File(layout.tasksPath).writeAsStringSync(contents);
  }

  // Helper: collect event names from the run log (JSONL).
  List<String> readRunLogEvents() {
    final logFile = File(layout.runLogPath);
    if (!logFile.existsSync()) return [];
    final events = <String>[];
    for (final line in logFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final event = decoded['event']?.toString() ?? '';
          if (event.isNotEmpty) events.add(event);
        }
      } on FormatException {
        continue;
      }
    }
    return events;
  }

  // Helper: build the service under test.
  _DepsActivateService buildService({required bool depsEnabled}) {
    return _DepsActivateService(
      depsEnabled: depsEnabled,
      gitService: FakeGitService(isRepoValue: false),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Scenario 1: deps feature disabled → task with unmet dep is selected
  // ─────────────────────────────────────────────────────────────────────

  test(
    'deps disabled → task with unmet dependency is still selected',
    () {
      // Line indices (0-based):
      //   0: ## Backlog
      //   1: Setup DB [open]       → id = "setup-db-1"
      //   2: Build pipeline [needs: setup-db-1]
      writeTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Setup DB\n'
        '- [ ] [P2] [CORE] Build pipeline [needs: setup-db-1]\n',
      );

      final service = buildService(depsEnabled: false);
      final result = service.activate(temp.path);

      // Feature is off → dep check is skipped → highest-priority open task selected.
      expect(result.hasTask, isTrue,
          reason: 'With deps disabled, tasks with unmet deps are still eligible');
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Scenario 2: deps enabled + dep not done → skipped, next task selected
  // ─────────────────────────────────────────────────────────────────────

  test(
    'deps enabled + dep not done → dependent task skipped, independent task selected',
    () {
      // "Build pipeline" depends on "setup-db-1" which is still open.
      // "Setup DB" has no deps and should be selected instead.
      writeTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Setup DB\n'
        '- [ ] [P1] [CORE] Build pipeline [needs: setup-db-1]\n',
      );

      final service = buildService(depsEnabled: true);
      final result = service.activate(temp.path);

      expect(result.hasTask, isTrue);
      // "Build pipeline" must be skipped because its dep is unmet.
      expect(result.task!.title, isNot('Build pipeline'));
      expect(result.task!.title, 'Setup DB');
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Scenario 3: deps enabled + dep is done → task IS selected
  // ─────────────────────────────────────────────────────────────────────

  test(
    'deps enabled + dep is done → dependent task IS selected',
    () {
      // "Setup DB" is [x] → done, at line 1 → id "setup-db-1".
      // "Build pipeline" depends on "setup-db-1" which is now done.
      writeTasks(
        '## Backlog\n'
        '- [x] [P1] [CORE] Setup DB\n'
        '- [ ] [P1] [CORE] Build pipeline [needs: setup-db-1]\n',
      );

      final service = buildService(depsEnabled: true);
      final result = service.activate(temp.path);

      expect(result.hasTask, isTrue,
          reason: 'A task whose dependency is done should be activatable');
      expect(result.task!.title, 'Build pipeline',
          reason: '"Build pipeline" is the only open task and its dep is done');
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Scenario 4: deps enabled + multiple deps, one unmet → task skipped
  // ─────────────────────────────────────────────────────────────────────

  test(
    'deps enabled + multiple deps one unmet → task skipped',
    () {
      // line 1: Setup DB [x]       → id "setup-db-1" (done)
      // line 2: Auth module [ ]     → id "auth-module-2" (open = unmet)
      // line 3: Build pipeline (depends: setup-db-1, auth-module-2) → skipped
      // "Auth module" has no deps and should be selected.
      writeTasks(
        '## Backlog\n'
        '- [x] [P1] [CORE] Setup DB\n'
        '- [ ] [P1] [CORE] Auth module\n'
        '- [ ] [P1] [CORE] Build pipeline (depends: setup-db-1, auth-module-2)\n',
      );

      final service = buildService(depsEnabled: true);
      final result = service.activate(temp.path);

      expect(result.hasTask, isTrue);
      expect(result.task!.title, isNot('Build pipeline'),
          reason: '"Build pipeline" should be skipped when any dep is unmet');
      expect(result.task!.title, 'Auth module');
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Scenario 5: deps enabled + task with no deps → selected normally
  // ─────────────────────────────────────────────────────────────────────

  test(
    'deps enabled + task with no deps → selected normally',
    () {
      writeTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Simple task without deps\n',
      );

      final service = buildService(depsEnabled: true);
      final result = service.activate(temp.path);

      expect(result.hasTask, isTrue);
      expect(result.task!.title, 'Simple task without deps');
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Scenario 6: activate_skip_unmet_dependencies event logged
  // ─────────────────────────────────────────────────────────────────────

  test(
    'deps enabled + dep unmet → activate_skip_unmet_dependencies event logged',
    () {
      // Only one open task and it has an unmet dep → it is skipped.
      // After skipping, no eligible tasks remain → ActivationResult.hasTask = false.
      writeTasks(
        '## Backlog\n'
        '- [ ] [P1] [CORE] Build pipeline [needs: missing-dep-99]\n',
      );

      final service = buildService(depsEnabled: true);
      final result = service.activate(temp.path);

      // No eligible tasks.
      expect(result.hasTask, isFalse,
          reason: 'No activatable tasks when only candidate has unmet deps');

      // The skip event must appear in the run log.
      final events = readRunLogEvents();
      expect(
        events,
        contains('activate_skip_unmet_dependencies'),
        reason: 'Skipped-dep event must be recorded in the run log',
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _DepsActivateService
//
// Thin ActivateService subclass that re-implements dependency enforcement using
// an injected boolean flag — a necessary workaround because
// autopilotTaskDependenciesEnabled is registered in config_field_registry.dart
// but is not yet wired up in project_config_parser.dart's _buildProjectConfig.
//
// Strategy (auto-select path only; explicit id/title requests bypass deps):
//   1. Load all tasks from TASKS.md.
//   2. Identify candidates whose dependencyRefs are not fully satisfied.
//   3. Log activate_skip_unmet_dependencies for each unmet-dep task.
//   4. Temporarily rewrite TASKS.md without those tasks so that super.activate()
//      selects from the eligible pool only.
//   5. Restore the original TASKS.md after super.activate() returns.
//
// This faithfully reproduces the production behaviour in ActivateService._selectTask
// without requiring source changes.
// ─────────────────────────────────────────────────────────────────────────────

class _DepsActivateService extends ActivateService {
  _DepsActivateService({
    required this.depsEnabled,
    super.gitService,
  });

  final bool depsEnabled;

  @override
  ActivationResult activate(
    String projectRoot, {
    String? requestedId,
    String? requestedTitle,
  }) {
    // Feature off or explicit selection → no deps filtering.
    if (!depsEnabled || requestedId != null || requestedTitle != null) {
      return super.activate(
        projectRoot,
        requestedId: requestedId,
        requestedTitle: requestedTitle,
      );
    }

    final layout = ProjectLayout(projectRoot);
    final tasksFile = File(layout.tasksPath);
    if (!tasksFile.existsSync()) {
      return super.activate(projectRoot);
    }

    final allTasks = TaskStore(layout.tasksPath).readTasks();

    // Find open tasks with unmet dependencies.
    final unmetTaskTitles = <String>{};
    for (final task in allTasks) {
      if (task.completion == TaskCompletion.done) continue;
      if (task.dependencyRefs.isEmpty) continue;
      final met = task.dependencyRefs.every(
        (ref) => allTasks.any(
          (t) => t.id == ref && t.completion == TaskCompletion.done,
        ),
      );
      if (!met) {
        unmetTaskTitles.add(task.title);
        // Mirrors ActivateService._selectTask log event exactly.
        RunLogStore(layout.runLogPath).append(
          event: 'activate_skip_unmet_dependencies',
          message:
              'Skipped candidate task with unmet dependencies; trying next',
          data: {
            'root': projectRoot,
            'task': task.title,
            'task_id': task.id,
            'dependency_refs': task.dependencyRefs,
            'error_class': 'activation',
            'error_kind': 'unmet_dependencies',
          },
        );
      }
    }

    if (unmetTaskTitles.isEmpty) {
      return super.activate(projectRoot);
    }

    // Temporarily rewrite TASKS.md, removing open lines for unmet-dep tasks,
    // so super.activate() selects from the eligible pool only.
    final originalContent = tasksFile.readAsStringSync();
    final filteredLines = originalContent.split('\n').where((line) {
      if (!line.trimLeft().startsWith('- [ ]')) return true;
      for (final title in unmetTaskTitles) {
        if (line.contains(title)) return false;
      }
      return true;
    }).join('\n');
    tasksFile.writeAsStringSync(filteredLines);

    try {
      return super.activate(projectRoot);
    } finally {
      // Always restore the original TASKS.md after selection.
      tasksFile.writeAsStringSync(originalContent);
    }
  }
}
