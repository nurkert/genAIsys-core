import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/services/task_management/task_forensics_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;
  late StateStore stateStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_narrowing_test_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
    stateStore = StateStore(layout.statePath);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  void writeConfig({int narrowingMaxSize = 3}) {
    File(layout.configPath).writeAsStringSync(
      'pipeline:\n'
      '  forensic_recovery_enabled: true\n'
      '  subtask_forced_narrowing_max_size: $narrowingMaxSize\n',
    );
  }

  void seedState({
    required List<String> queue,
    bool forensicRecoveryAttempted = true,
  }) {
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(
          id: 'alpha-1',
          title: 'Alpha',
          forensicRecoveryAttempted: forensicRecoveryAttempted,
        ),
        subtaskExecution: SubtaskExecutionState(queue: queue),
      ),
    );
  }

  TaskCycleService buildService({
    required _FakeForensicsService forensics,
    int maxReviewRetries = 1,
  }) {
    return TaskCycleService(
      taskPipelineService: _FakeTaskPipelineService(
        _buildPipelineResult(review: _rejectReview()),
      ),
      reviewService: _FakeReviewService(),
      gitService: null,
      doneService: _FakeDoneService(),
      taskForensicsService: forensics,
      maxReviewRetries: maxReviewRetries,
    );
  }

  test(
    '2nd-pass narrowing: queue truncated to maxSize when specTooLarge and forensicRecoveryAttempted',
    () async {
      writeConfig(narrowingMaxSize: 3);
      seedState(
        queue: ['A', 'B', 'C', 'D', 'E'],
        forensicRecoveryAttempted: true,
      );

      final result = await buildService(
        forensics: _FakeForensicsService(ForensicClassification.specTooLarge),
      ).run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
      );

      // Narrowing succeeded — task is NOT blocked.
      expect(result.taskBlocked, isFalse);

      // Queue must be truncated to the first 3 items.
      final state = stateStore.read();
      expect(state.subtaskQueue, ['A', 'B', 'C']);
      expect(state.currentSubtask, isNull);
    },
  );

  test(
    '2nd-pass narrowing: hard block when queue already within maxSize',
    () async {
      writeConfig(narrowingMaxSize: 3);
      seedState(
        queue: ['A', 'B'],
        forensicRecoveryAttempted: true,
      );

      final result = await buildService(
        forensics: _FakeForensicsService(ForensicClassification.specTooLarge),
      ).run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
      );

      // Queue is small (2 <= 3) — narrowing cannot help → hard block.
      expect(result.taskBlocked, isTrue);
      // blockActive clears the active task (no stale id left).
      final state = stateStore.read();
      expect(state.activeTaskId, isNull);
    },
  );

  test(
    '2nd-pass narrowing: subtask_scope_forced_narrowing event emitted in run log',
    () async {
      writeConfig(narrowingMaxSize: 3);
      seedState(
        queue: ['A', 'B', 'C', 'D', 'E'],
        forensicRecoveryAttempted: true,
      );

      await buildService(
        forensics: _FakeForensicsService(ForensicClassification.specTooLarge),
      ).run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
      );

      final runLogLines =
          File(layout.runLogPath).readAsStringSync().split('\n');
      final events = runLogLines
          .where((l) => l.trim().isNotEmpty)
          .map((l) {
            try {
              return jsonDecode(l) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      expect(
        events.any((e) => e['event'] == 'subtask_scope_forced_narrowing'),
        isTrue,
        reason: 'Expected subtask_scope_forced_narrowing event in run log',
      );
    },
  );

  test(
    '1st-pass (forensicRecoveryAttempted=false): narrowing NOT applied, forensic recovery triggered',
    () async {
      writeConfig(narrowingMaxSize: 3);
      seedState(
        queue: ['A', 'B', 'C', 'D', 'E'],
        forensicRecoveryAttempted: false,
      );

      // 1st-pass: forensicRecoveryAttempted=false → _attemptForensicRecovery is
      // called instead of _tryForcedNarrowing.
      final result = await buildService(
        forensics: _FakeForensicsService(ForensicClassification.specTooLarge),
      ).run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
      );

      // Task is NOT blocked on the first forensic pass (recovery attempted).
      expect(result.taskBlocked, isFalse);

      // Queue must remain unchanged (forensic recovery, not forced narrowing).
      final state = stateStore.read();
      expect(
        state.subtaskQueue.length,
        5,
        reason: 'Queue must NOT be truncated on 1st-pass forensic recovery',
      );

      // forensicRecoveryAttempted should now be true after the 1st pass.
      expect(state.forensicRecoveryAttempted, isTrue);
    },
  );

  test(
    '2nd-pass: no narrowing when classification is NOT specTooLarge → hard block',
    () async {
      writeConfig(narrowingMaxSize: 3);
      seedState(
        queue: ['A', 'B', 'C', 'D', 'E'],
        forensicRecoveryAttempted: true,
      );

      // Forensics returns a non-specTooLarge classification.
      final result = await buildService(
        forensics:
            _FakeForensicsService(ForensicClassification.persistentTestFailure),
      ).run(
        temp.path,
        codingPrompt: 'Do work',
        isSubtask: true,
      );

      // Non-specTooLarge → narrowing not applicable → hard block.
      expect(result.taskBlocked, isTrue);
      // blockActive clears the active task (no stale id left).
      final state = stateStore.read();
      expect(state.activeTaskId, isNull);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

TaskPipelineResult _buildPipelineResult({ReviewAgentResult? review}) {
  return TaskPipelineResult(
    plan: _specResult(SpecKind.plan),
    spec: _specResult(SpecKind.spec),
    subtasks: _specResult(SpecKind.subtasks),
    coding: CodingAgentResult(
      path: '/tmp/attempt.txt',
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    ),
    review: review,
  );
}

SpecAgentResult _specResult(SpecKind kind) {
  return SpecAgentResult(
    path: '/tmp/${kind.name}.md',
    kind: kind,
    wrote: true,
    usedFallback: false,
    response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
  );
}

ReviewAgentResult _rejectReview() {
  return ReviewAgentResult(
    decision: ReviewDecision.reject,
    response: const AgentResponse(
      exitCode: 0,
      stdout: 'REJECT\nNeeds more work.',
      stderr: '',
    ),
    usedFallback: false,
  );
}

class _FakeTaskPipelineService extends TaskPipelineService {
  _FakeTaskPipelineService(this.result);

  final TaskPipelineResult result;

  @override
  Future<TaskPipelineResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    ReviewPersona reviewPersona = ReviewPersona.general,
    TaskCategory? taskCategory,
    List<String> contractNotes = const [],
    int retryCount = 0,
  }) async => result;
}

class _FakeReviewService extends ReviewService {
  @override
  String recordDecision(
    String projectRoot, {
    required String decision,
    String? note,
    String? testSummary,
  }) => super.recordDecision(
    projectRoot,
    decision: decision,
    note: note,
    testSummary: testSummary,
  );
}

class _FakeDoneService extends DoneService {
  int blockCalls = 0;

  @override
  Future<String> markDone(String projectRoot, {bool force = false}) async =>
      'Alpha';

  @override
  String blockActive(
    String projectRoot, {
    String? reason,
    Map<String, Object?>? diagnostics,
  }) {
    blockCalls += 1;
    return 'Alpha';
  }
}

/// Overrides [diagnose] to return a fixed [ForensicClassification] without
/// reading the file system. Used to deterministically trigger 2nd-pass paths.
class _FakeForensicsService extends TaskForensicsService {
  _FakeForensicsService(this.classification);

  final ForensicClassification classification;

  @override
  ForensicDiagnosis diagnose(
    String projectRoot, {
    String? taskTitle,
    int retryCount = 0,
    int requiredFileCount = 0,
    List<String>? errorKinds,
    DiffStats? diffStats,
    int qualityGateFailureCount = 0,
  }) {
    return ForensicDiagnosis(
      classification: classification,
      evidence: ['fake diagnosis for test'],
      suggestedAction: classification == ForensicClassification.specTooLarge
          ? ForensicAction.redecompose
          : ForensicAction.block,
    );
  }
}
