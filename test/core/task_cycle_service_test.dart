import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/services/error_pattern_registry_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/task_forensics_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/models/retry_scheduling_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('TaskCycleService records review decision when present', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    final projectRoot = _setupProject();
    final pipeline = _FakeTaskPipelineService(
      _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
    );
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
    );

    final result = await service.run(projectRoot, codingPrompt: 'Do work');

    expect(result.reviewRecorded, isTrue);
    expect(result.reviewDecision, ReviewDecision.approve);
    expect(result.retryCount, 0);
    expect(result.taskBlocked, isFalse);
    expect(reviewService.calls, 1);
    expect(reviewService.decisions.single, 'approve');
    expect(gitService.calls, [
      'add',
      'commit: task: Alpha',
      'push origin main',
      // Post-done cleanup commit to maintain clean-end invariant.
      'add',
      'commit: meta(state): finalize task completion',
    ]);
    expect(doneService.calls, 1);
    expect(doneService.blockCalls, 0);
  });

  test(
    'TaskCycleService retries push even when commit is already present',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService(hasChangesValue: false);
      final doneService = _FakeDoneService();
      final projectRoot = _setupProject();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.reviewRecorded, isTrue);
      expect(result.reviewDecision, ReviewDecision.approve);
      expect(gitService.calls, ['push origin main']);
      expect(doneService.calls, 1);
    },
  );

  test(
    'TaskCycleService resumes approved delivery without a new pipeline run',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService(hasChangesValue: false);
      final doneService = _FakeDoneService();
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: stateStore.read().activeTask.copyWith(
            reviewStatus: 'approved',
            reviewUpdatedAt: '2026-02-08T00:00:00Z',
          ),
        ),
      );
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.reviewRecorded, isFalse);
      expect(result.reviewDecision, ReviewDecision.approve);
      expect(result.autoMarkedDone, isTrue);
      expect(result.retryCount, 0);
      expect(pipeline.calls, 0);
      expect(gitService.calls, ['push origin main']);
      expect(doneService.calls, 1);
    },
  );

  test(
    'TaskCycleService clears approved review after subtask delivery resume',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService(hasChangesValue: false);
      final doneService = _FakeDoneService();
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: stateStore.read().activeTask.copyWith(
            reviewStatus: 'approved',
            reviewUpdatedAt: '2026-02-08T00:00:00Z',
          ),
          subtaskExecution: const SubtaskExecutionState(current: 'subtask-1'),
        ),
      );
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final result = await service.run(
        projectRoot,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'subtask-1',
      );

      expect(result.reviewRecorded, isFalse);
      expect(result.reviewDecision, ReviewDecision.approve);
      expect(result.autoMarkedDone, isFalse);
      expect(pipeline.calls, 0);
      expect(gitService.calls, ['push origin main']);
      expect(doneService.calls, 0);
      expect(reviewService.clearCalls, 1);
      expect(reviewService.lastClearNote, contains('subtask delivery resume'));

      final updated = stateStore.read();
      expect(updated.reviewStatus, isNull);
      expect(updated.reviewUpdatedAt, isNull);
    },
  );

  test(
    'TaskCycleService clears approved review after successful subtask approve delivery',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService(hasChangesValue: false);
      final doneService = _FakeDoneService();
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(stateStore.read().copyWith(
        subtaskExecution: const SubtaskExecutionState(current: 'subtask-1'),
      ));
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final result = await service.run(
        projectRoot,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'subtask-1',
      );

      expect(result.reviewRecorded, isTrue);
      expect(result.reviewDecision, ReviewDecision.approve);
      expect(result.autoMarkedDone, isFalse);
      expect(pipeline.calls, 1);
      // Feature 3: per-subtask commit (no push); no changes → nothing recorded.
      expect(gitService.calls, isEmpty);
      expect(doneService.calls, 0);
      expect(reviewService.clearCalls, 1);
      expect(
        reviewService.lastClearNote,
        contains('successful subtask delivery'),
      );

      final updated = stateStore.read();
      expect(updated.reviewStatus, isNull);
      expect(updated.reviewUpdatedAt, isNull);
    },
  );

  test('TaskCycleService records retry when no diff produced', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    final pipeline = _FakeTaskPipelineService(_buildPipelineResult());
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
    );

    final projectRoot = _setupProject();
    final result = await service.run(projectRoot, codingPrompt: 'Do work');

    expect(result.reviewRecorded, isFalse);
    expect(result.reviewDecision, isNull);
    expect(result.retryCount, 1);
    expect(result.taskBlocked, isFalse);
    expect(reviewService.calls, 0);
    expect(gitService.calls, isEmpty);
    expect(doneService.calls, 0);
    expect(doneService.blockCalls, 0);
  });

  test('TaskCycleService skips git when review rejects', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    final pipeline = _FakeTaskPipelineService(
      _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
    );
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
    );

    final projectRoot = _setupProject();
    final result = await service.run(projectRoot, codingPrompt: 'Do work');

    expect(result.reviewRecorded, isTrue);
    expect(result.reviewDecision, ReviewDecision.reject);
    expect(result.retryCount, 1);
    expect(result.taskBlocked, isFalse);
    expect(reviewService.decisions.single, 'reject');
    expect(gitService.calls, isEmpty);
    expect(doneService.calls, 0);
    expect(doneService.blockCalls, 0);
  });

  test(
    'TaskCycleService keeps worktree clean after reject in unattended mode',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cycle_unattended_reject_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'alpha-1',
            title: 'Alpha Task',
          ),
          subtaskExecution: const SubtaskExecutionState(
            current: 'Fix parser edge cases',
          ),
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
      tracked.writeAsStringSync('reject change\n');

      Directory(layout.locksDir).createSync(recursive: true);
      File(layout.autopilotLockPath).writeAsStringSync('lock');

      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout: 'REJECT\nNeeds follow-up changes.',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: ReviewService(),
      );

      final result = await service.run(temp.path, codingPrompt: 'Do work');

      expect(result.reviewRecorded, isTrue);
      expect(result.reviewDecision, ReviewDecision.reject);
      expect(result.retryCount, 1);
      expect(result.taskBlocked, isFalse);

      final state = stateStore.read();
      expect(state.reviewStatus, isNull);
      expect(state.reviewUpdatedAt, isNull);

      final status = Process.runSync('git', [
        'status',
        '--porcelain',
      ], workingDirectory: temp.path);
      expect(status.exitCode, 0);
      expect(status.stdout.toString().trim(), isEmpty);

      final stash = Process.runSync('git', [
        'stash',
        'list',
      ], workingDirectory: temp.path);
      expect(stash.exitCode, 0);
      expect(stash.stdout.toString(), contains('genaisys:review-reject:'));

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"review_reject_autostash"'));
      expect(runLog, contains('"event":"review_cleared"'));
    },
  );

  test(
    'TaskCycleService blocks active task after max review retries',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 2,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      final seeded = stateStore.read().copyWith(
        retryScheduling: const RetrySchedulingState(
          retryCounts: {'id:alpha-1': 1},
        ),
      );
      stateStore.write(seeded);

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.reviewRecorded, isTrue);
      expect(result.reviewDecision, ReviewDecision.reject);
      expect(result.retryCount, 2);
      expect(result.taskBlocked, isTrue);
      expect(doneService.calls, 0);
      expect(doneService.blockCalls, 1);
      expect(doneService.lastBlockReason, contains('review rejected 2 time'));
      final updated = stateStore.read();
      expect(updated.activeTaskId, isNull);
      expect(updated.activeTaskTitle, isNull);
    },
  );

  test(
    'TaskCycleService recovers stale active task when blockActive cannot find TASKS entry',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService(throwNotFoundOnBlock: true);
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 2,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          retryScheduling: const RetrySchedulingState(
            retryCounts: {'id:alpha-1': 1},
          ),
        ),
      );

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.reviewRecorded, isTrue);
      expect(result.reviewDecision, ReviewDecision.reject);
      expect(result.retryCount, 2);
      expect(result.taskBlocked, isTrue);
      expect(doneService.blockCalls, 1);
      final updated = stateStore.read();
      expect(updated.activeTaskId, isNull);
      expect(updated.activeTaskTitle, isNull);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(
        runLog,
        contains('"event":"task_cycle_stale_active_task_recovered"'),
      );
      expect(runLog, contains('"error_class":"pipeline"'));
      expect(runLog, contains('"error_kind":"not_found"'));
    },
  );

  test('TaskCycleService honors per-run max review retries override', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    final pipeline = _FakeTaskPipelineService(
      _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
    );
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
      maxReviewRetries: 5,
    );
    final projectRoot = _setupProject();
    final layout = ProjectLayout(projectRoot);
    final stateStore = StateStore(layout.statePath);
    final seeded = stateStore.read().copyWith(
      retryScheduling: const RetrySchedulingState(
        retryCounts: {'id:alpha-1': 1},
      ),
    );
    stateStore.write(seeded);

    final result = await service.run(
      projectRoot,
      codingPrompt: 'Do work',
      maxReviewRetries: 2,
    );

    expect(result.retryCount, 2);
    expect(result.taskBlocked, isTrue);
    expect(doneService.blockCalls, 1);
    expect(doneService.lastBlockReason, contains('review rejected 2 time'));
  });

  test(
    'TaskCycleService records retry on quality gate analyze failure reject',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout:
                  'REJECT\n'
                  'Quality gate failed before review.\n'
                  'Policy violation: quality_gate command failed (exit 1): '
                  '"dart analyze".',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final projectRoot = _setupProject();
      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.reviewRecorded, isTrue);
      expect(result.reviewDecision, ReviewDecision.reject);
      expect(result.retryCount, 1);
      expect(result.taskBlocked, isFalse);
      expect(reviewService.decisions.single, 'reject');
      expect(gitService.calls, isEmpty);
      expect(doneService.calls, 0);
      expect(doneService.blockCalls, 0);
    },
  );

  test(
    'TaskCycleService records retry on quality gate test failure reject',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(
          review: ReviewAgentResult(
            decision: ReviewDecision.reject,
            response: const AgentResponse(
              exitCode: 0,
              stdout:
                  'REJECT\n'
                  'Quality gate failed before review.\n'
                  'Policy violation: quality_gate command failed (exit 1): '
                  '"flutter test".',
              stderr: '',
            ),
            usedFallback: false,
          ),
        ),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final projectRoot = _setupProject();
      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.reviewRecorded, isTrue);
      expect(result.reviewDecision, ReviewDecision.reject);
      expect(result.retryCount, 1);
      expect(result.taskBlocked, isFalse);
      expect(reviewService.decisions.single, 'reject');
      expect(gitService.calls, isEmpty);
      expect(doneService.calls, 0);
      expect(doneService.blockCalls, 0);
    },
  );

  test(
    'TaskCycleService fails fast on policy violation without side effects',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(),
        error: StateError('Policy violation: safe_write blocked ".git/HEAD".'),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      final before = stateStore.read();

      await expectLater(
        service.run(projectRoot, codingPrompt: 'Do work'),
        throwsA(
          isA<PolicyViolationError>().having(
            (error) => error.message,
            'message',
            contains('Policy violation: safe_write blocked'),
          ),
        ),
      );

      final after = stateStore.read();
      expect(reviewService.calls, 0);
      expect(gitService.calls, isEmpty);
      expect(doneService.calls, 0);
      expect(doneService.blockCalls, 0);
      expect(after.taskRetryCounts, before.taskRetryCounts);
      expect(after.activeTaskId, before.activeTaskId);
      expect(after.activeTaskTitle, before.activeTaskTitle);
    },
  );

  test('TaskCycleService triggers forensic recovery (retryWithGuidance) '
      'instead of blocking when enabled', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    final forensicsService = _FakeTaskForensicsService(
      diagnosisResult: const ForensicDiagnosis(
        classification: ForensicClassification.persistentTestFailure,
        evidence: ['Test failures in 3 consecutive runs'],
        suggestedAction: ForensicAction.retryWithGuidance,
        guidanceText: 'Focus on edge case handling in parser.',
      ),
    );
    final pipeline = _FakeTaskPipelineService(
      _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
    );
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
      taskForensicsService: forensicsService,
      maxReviewRetries: 2,
    );
    final projectRoot = _setupProjectWithConfig(forensicRecoveryEnabled: true);
    final layout = ProjectLayout(projectRoot);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(retryScheduling: const RetrySchedulingState(retryCounts: {'id:alpha-1': 1})),
    );

    final result = await service.run(projectRoot, codingPrompt: 'Do work');

    // Forensic recovery means task is NOT blocked — it gets another chance.
    expect(result.taskBlocked, isFalse);
    expect(result.retryCount, 2);
    expect(doneService.blockCalls, 0);
    expect(forensicsService.diagnoseCalls, 1);

    final state = stateStore.read();
    expect(state.forensicRecoveryAttempted, isTrue);
    expect(state.forensicGuidance, contains('Focus on edge case'));
    // Retry counter should be reset by forensic recovery.
    expect(state.taskRetryCounts['id:alpha-1'], isNull);
  });

  test(
    'TaskCycleService hard-blocks task when forensic recovery was already attempted',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final forensicsService = _FakeTaskForensicsService(
        diagnosisResult: const ForensicDiagnosis(
          classification: ForensicClassification.persistentTestFailure,
          evidence: ['Still failing'],
          suggestedAction: ForensicAction.retryWithGuidance,
          guidanceText: 'Try again',
        ),
      );
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        taskForensicsService: forensicsService,
        maxReviewRetries: 2,
      );
      final projectRoot = _setupProjectWithConfig(
        forensicRecoveryEnabled: true,
      );
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          retryScheduling: const RetrySchedulingState(
            retryCounts: {'id:alpha-1': 1},
          ),
          activeTask: stateStore.read().activeTask.copyWith(
            forensicRecoveryAttempted: true,
          ),
        ),
      );

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      // Recovery was already attempted → hard block.
      expect(result.taskBlocked, isTrue);
      expect(result.retryCount, 2);
      expect(doneService.blockCalls, 1);
      expect(
        doneService.lastBlockReason,
        contains('forensic recovery exhausted'),
      );
      // Feature 4: _tryForcedNarrowing calls diagnose() once to check
      // classification before deciding narrowing doesn't apply (not specTooLarge).
      expect(forensicsService.diagnoseCalls, 1);
    },
  );

  test('TaskCycleService blocks task after max no-diff retries', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    // Pipeline produces no review → no-diff path.
    final pipeline = _FakeTaskPipelineService(_buildPipelineResult());
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
      maxReviewRetries: 2,
    );
    final projectRoot = _setupProject();
    final layout = ProjectLayout(projectRoot);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(retryScheduling: const RetrySchedulingState(retryCounts: {'id:alpha-1': 1})),
    );

    final result = await service.run(projectRoot, codingPrompt: 'Do work');

    expect(result.reviewDecision, isNull);
    expect(result.retryCount, 2);
    expect(result.taskBlocked, isTrue);
    expect(doneService.blockCalls, 1);
    expect(doneService.lastBlockReason, contains('no diff'));
  });

  test('TaskCycleService skips push when no remote is available', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    gitService.defaultRemoteValue = null;
    final doneService = _FakeDoneService();
    final pipeline = _FakeTaskPipelineService(
      _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
    );
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
    );
    final projectRoot = _setupProject();

    final result = await service.run(projectRoot, codingPrompt: 'Do work');

    expect(result.reviewDecision, ReviewDecision.approve);
    // Should add + commit, but NOT push (no remote).
    // Post-done cleanup commit also fires.
    expect(gitService.calls, [
      'add',
      'commit: task: Alpha',
      'add',
      'commit: meta(state): finalize task completion',
    ]);
    expect(gitService.calls, isNot(contains(startsWith('push'))));
    expect(doneService.calls, 1);
  });

  test(
    'TaskCycleService increments subtask-specific retry key on reject',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(subtaskExecution: const SubtaskExecutionState(current: 'fix-parsing')),
      );

      await service.run(
        projectRoot,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'fix-parsing',
      );

      final state = stateStore.read();
      // Both task-level and subtask-level retry keys should be incremented.
      // Task-level key is used for blocking decisions (stable across replans).
      expect(state.taskRetryCounts['id:alpha-1'], 1);
      // Subtask-specific retry key for granular diagnostics.
      // Key format: subtask:id:<taskId>:<subtask>
      expect(state.taskRetryCounts['subtask:id:alpha-1:fix-parsing'], 1);
    },
  );

  test(
    'TaskCycleService task-level retry reaches threshold despite changing subtask descriptions',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 3,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(subtaskExecution: const SubtaskExecutionState(current: 'subtask-v1')),
      );

      // Simulate 3 reject cycles with DIFFERENT subtask descriptions each time
      // (mimics replanning after rejection). Task-level key must still accumulate.
      final r1 = await service.run(
        projectRoot,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'subtask-v1',
      );
      expect(r1.retryCount, 1);

      // Subtask description changes after replanning.
      stateStore.write(
        stateStore.read().copyWith(subtaskExecution: const SubtaskExecutionState(current: 'subtask-v2')),
      );
      final r2 = await service.run(
        projectRoot,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'subtask-v2',
      );
      expect(r2.retryCount, 2);

      // Third different subtask — task-level retry must hit threshold.
      stateStore.write(
        stateStore.read().copyWith(subtaskExecution: const SubtaskExecutionState(current: 'subtask-v3')),
      );
      final r3 = await service.run(
        projectRoot,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'subtask-v3',
      );
      expect(r3.retryCount, 3);
      expect(r3.taskBlocked, isTrue);

      // Verify: task-level key accumulated, each subtask key has 1.
      final state = stateStore.read();
      expect(state.taskRetryCounts['id:alpha-1'], 3);
      expect(state.taskRetryCounts['subtask:id:alpha-1:subtask-v1'], 1);
      expect(state.taskRetryCounts['subtask:id:alpha-1:subtask-v2'], 1);
      expect(state.taskRetryCounts['subtask:id:alpha-1:subtask-v3'], 1);
    },
  );

  test(
    'TaskCycleService retry count persists across multiple run calls',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 5,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);

      // First run: retry count starts at 0 → increments to 1.
      final r1 = await service.run(projectRoot, codingPrompt: 'Do work');
      expect(r1.retryCount, 1);

      // Second run: persisted count (1) → increments to 2.
      final r2 = await service.run(projectRoot, codingPrompt: 'Do work');
      expect(r2.retryCount, 2);

      // Third run: persisted count (2) → increments to 3.
      final r3 = await service.run(projectRoot, codingPrompt: 'Do work');
      expect(r3.retryCount, 3);

      // Verify persisted state matches.
      final state = stateStore.read();
      expect(state.taskRetryCounts['id:alpha-1'], 3);
    },
  );

  test(
    'TaskCycleService forensic redecompose deletes spec artifacts',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final forensicsService = _FakeTaskForensicsService(
        diagnosisResult: const ForensicDiagnosis(
          classification: ForensicClassification.specTooLarge,
          evidence: ['Spec targets 12 files'],
          suggestedAction: ForensicAction.redecompose,
          guidanceText: 'Break into smaller pieces.',
        ),
      );
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        taskForensicsService: forensicsService,
        maxReviewRetries: 2,
      );
      final projectRoot = _setupProjectWithConfig(
        forensicRecoveryEnabled: true,
      );
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(retryScheduling: const RetrySchedulingState(retryCounts: {'id:alpha-1': 1})),
      );

      // Create a spec artifact that should be deleted on redecompose.
      final specDir = Directory(layout.taskSpecsDir);
      specDir.createSync(recursive: true);
      final specFile = File('${specDir.path}/alpha.md');
      specFile.writeAsStringSync('# Old spec');

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.taskBlocked, isFalse);
      expect(forensicsService.diagnoseCalls, 1);
      // Spec artifact should be deleted for redecompose.
      expect(specFile.existsSync(), isFalse);

      final state = stateStore.read();
      expect(state.forensicRecoveryAttempted, isTrue);
      expect(state.forensicGuidance, contains('REDECOMPOSITION REQUIRED'));
    },
  );

  test('TaskCycleService updates error pattern registry on reject', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    final errorPatternService = _FakeErrorPatternRegistryService();
    final pipeline = _FakeTaskPipelineService(
      _buildPipelineResult(
        review: ReviewAgentResult(
          decision: ReviewDecision.reject,
          response: const AgentResponse(
            exitCode: 0,
            stdout:
                'REJECT\n'
                'The implementation does not handle the null case correctly '
                'and this will cause a runtime error in production.',
            stderr: '',
          ),
          usedFallback: false,
        ),
      ),
    );
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
      errorPatternRegistryService: errorPatternService,
    );
    final projectRoot = _setupProjectWithConfig(
      errorPatternLearningEnabled: true,
    );

    await service.run(projectRoot, codingPrompt: 'Do work');

    expect(errorPatternService.mergeCalls, 1);
    // Review note is > 50 chars, so resolution should be recorded.
    expect(errorPatternService.recordResolutionCalls, 1);
  });

  test(
    'TaskCycleService persists STATE.json cleanup after block via addAll + commit',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 2,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(retryScheduling: const RetrySchedulingState(retryCounts: {'id:alpha-1': 1})),
      );

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.taskBlocked, isTrue);
      expect(doneService.blockCalls, 1);
      // After blockActive → clearActiveTask → clearSubtasks, the service
      // must call _persistStateCleanupAfterBlock which does addAll + commit.
      // The FakeGitService records hasChanges=true, so both calls are expected.
      expect(gitService.calls, contains('add'));
      expect(
        gitService.calls,
        contains(
          predicate<String>(
            (call) =>
                call.startsWith('commit:') &&
                call.contains('clear active task after block'),
            'commit with block cleanup message',
          ),
        ),
      );
      // Verify the add+commit happen AFTER the block, not before.
      final addIndex = gitService.calls.indexOf('add');
      final commitIndex = gitService.calls.indexWhere(
        (call) => call.contains('clear active task after block'),
      );
      expect(addIndex, lessThan(commitIndex));
    },
  );

  // ---------------------------------------------------------------------------
  // Chunk 3: TaskCycleService error paths
  // ---------------------------------------------------------------------------

  test(
    'TaskCycleService clears retry count on approve after previous rejects',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);

      // Simulate 2 previous rejects.
      stateStore.write(
        stateStore.read().copyWith(retryScheduling: const RetrySchedulingState(retryCounts: {'id:alpha-1': 2})),
      );

      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 5,
      );

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.reviewDecision, ReviewDecision.approve);
      expect(result.retryCount, 0);
      // Retry count should be cleared on approval.
      final state = stateStore.read();
      expect(state.taskRetryCounts['id:alpha-1'], isNull);
    },
  );

  test('TaskCycleService propagates pipeline error as-is', () async {
    final reviewService = _FakeReviewService();
    final gitService = _FakeGitService();
    final doneService = _FakeDoneService();
    final pipeline = _FakeTaskPipelineService(
      _buildPipelineResult(),
      error: PolicyViolationError('safe_write: blocked'),
    );
    final service = TaskCycleService(
      taskPipelineService: pipeline,
      reviewService: reviewService,
      gitService: gitService,
      doneService: doneService,
    );
    final projectRoot = _setupProject();

    expect(
      () => service.run(projectRoot, codingPrompt: 'Do work'),
      throwsA(isA<PolicyViolationError>()),
    );
  });

  test(
    'TaskCycleService recovers gracefully when blockActive throws (stale task)',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      // DoneService that throws on blockActive — simulates stale task.
      final doneService = _FakeDoneService(throwNotFoundOnBlock: true);
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 1,
      );
      final projectRoot = _setupProject();

      // Should NOT propagate the blockActive error — should handle it.
      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.retryCount, 1);
      expect(result.taskBlocked, isTrue);
      expect(doneService.blockCalls, 1);
    },
  );

  test(
    'TaskCycleService clears subtask retry key on subtask approve',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);

      // Simulate previous subtask rejects.
      stateStore.write(
        stateStore.read().copyWith(
          subtaskExecution: const SubtaskExecutionState(current: 'fix-parsing'),
          retryScheduling: const RetrySchedulingState(
            retryCounts: {'subtask:id:alpha-1:fix-parsing': 2},
          ),
        ),
      );

      await service.run(
        projectRoot,
        codingPrompt: 'Do work',
        isSubtask: true,
        subtaskDescription: 'fix-parsing',
      );

      final state = stateStore.read();
      // Subtask retry key should be cleared on approval.
      expect(state.taskRetryCounts['subtask:id:alpha-1:fix-parsing'], isNull);
      // Done should NOT be called for subtask.
      expect(doneService.calls, 0);
    },
  );

  test(
    'TaskCycleService review clearing on subtask delivery does not call markDone',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );
      final projectRoot = _setupProject();

      final result = await service.run(
        projectRoot,
        codingPrompt: 'Do subtask',
        isSubtask: true,
        subtaskDescription: 'implement-feature',
      );

      expect(result.reviewDecision, ReviewDecision.approve);
      expect(result.autoMarkedDone, isFalse);
      // markDone must NOT be called for subtask delivery.
      expect(doneService.calls, 0);
      // But commit+push should still happen.
      expect(gitService.calls, contains('add'));
    },
  );

  // ---------------------------------------------------------------------------
  // Change #21: Retry key persistence (activeTaskRetryKey)
  // ---------------------------------------------------------------------------

  test(
    'TaskCycleService persists activeTaskRetryKey to STATE.json on first retry increment',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);

      // Verify no retry key is set initially.
      expect(stateStore.read().activeTaskRetryKey, isNull);

      await service.run(projectRoot, codingPrompt: 'Do work');

      // After the first reject, activeTaskRetryKey should be persisted.
      final state = stateStore.read();
      expect(state.activeTaskRetryKey, isNotNull);
      expect(state.activeTaskRetryKey, 'id:alpha-1');
      expect(state.taskRetryCounts['id:alpha-1'], 1);
    },
  );

  test(
    'TaskCycleService subsequent increments use persisted retry key, not recomputed',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 5,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);

      // First reject: sets the key.
      await service.run(projectRoot, codingPrompt: 'Do work');
      expect(stateStore.read().activeTaskRetryKey, 'id:alpha-1');

      // Now change the activeTaskId in STATE.json to simulate mid-cycle
      // context drift.  The persisted retry key should be used, NOT the
      // recomputed one from the new activeTaskId.
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: stateStore.read().activeTask.copyWith(id: 'changed-id'),
        ),
      );

      await service.run(projectRoot, codingPrompt: 'Do work');

      final state = stateStore.read();
      // Retry key should still be the original one, not 'id:changed-id'.
      expect(state.activeTaskRetryKey, 'id:alpha-1');
      // Counter should have incremented under the original key.
      expect(state.taskRetryCounts['id:alpha-1'], 2);
      // New key should NOT have been created.
      expect(state.taskRetryCounts['id:changed-id'], isNull);
    },
  );

  test(
    'TaskCycleService _clearActiveTask clears activeTaskRetryKey',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 1,
      );
      final projectRoot = _setupProject();
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);

      // First reject triggers retry + block at maxReviewRetries=1.
      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      expect(result.taskBlocked, isTrue);
      // After blocking, _clearActiveTask should have cleared the retry key.
      final state = stateStore.read();
      expect(state.activeTaskId, isNull);
      expect(state.activeTaskTitle, isNull);
      expect(state.activeTaskRetryKey, isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // Change #22 & #23: Post-done / post-block discard fallback
  // ---------------------------------------------------------------------------

  test(
    'TaskCycleService post-done stash failure triggers discard fallback',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cycle_done_discard_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'alpha-1',
            title: 'Alpha',
          ),
        ),
      );

      // Set up a real git repo so the discard commands work.
      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      File('${temp.path}${Platform.pathSeparator}.gitignore').writeAsStringSync(
        '.genaisys/RUN_LOG.jsonl\n.genaisys/STATE.json\n.genaisys/audit/\n.genaisys/locks/\n',
      );
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      // Use a git service that fails on both commit (for post-done cleanup)
      // and stash — this forces the discard fallback path.
      final gitService = _FakeGitServiceWithFailures(
        commitFailsOnMessages: ['meta(state): finalize task completion'],
        stashAlwaysFails: true,
      );
      final reviewService = _FakeReviewService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.approve)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
      );

      final result = await service.run(temp.path, codingPrompt: 'Do work');

      expect(result.reviewDecision, ReviewDecision.approve);
      expect(result.autoMarkedDone, isTrue);
      // Run log should contain the discard fallback event.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"done_state_discard_fallback"'));
      expect(runLog, contains('"error_kind":"done_cleanup_discard"'));
    },
  );

  test(
    'TaskCycleService post-block stash failure triggers discard fallback',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cycle_block_discard_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          activeTask: const ActiveTaskState(
            id: 'alpha-1',
            title: 'Alpha',
          ),
          retryScheduling: const RetrySchedulingState(
            retryCounts: {'id:alpha-1': 1},
          ),
        ),
      );

      // Set up real git repo.
      _runGit(temp.path, ['init', '-b', 'main']);
      _runGit(temp.path, ['config', 'user.email', 'test@example.com']);
      _runGit(temp.path, ['config', 'user.name', 'Test User']);
      File('${temp.path}${Platform.pathSeparator}.gitignore').writeAsStringSync(
        '.genaisys/RUN_LOG.jsonl\n.genaisys/STATE.json\n.genaisys/audit/\n.genaisys/locks/\n',
      );
      _runGit(temp.path, ['add', '-A']);
      _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'init']);

      final gitService = _FakeGitServiceWithFailures(
        commitFailsOnMessages: ['meta(state): clear active task after block'],
        stashAlwaysFails: true,
      );
      final reviewService = _FakeReviewService();
      final doneService = _FakeDoneService();
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        maxReviewRetries: 2,
      );

      final result = await service.run(temp.path, codingPrompt: 'Do work');

      expect(result.taskBlocked, isTrue);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"event":"block_state_discard_fallback"'));
      expect(runLog, contains('"error_kind":"block_cleanup_discard"'));
    },
  );

  // ---------------------------------------------------------------------------
  // Change #24: Forensic recovery skips retryWithGuidance in unattended mode
  // ---------------------------------------------------------------------------

  test(
    'TaskCycleService skips retryWithGuidance and blocks in unattended mode',
    () async {
      final reviewService = _FakeReviewService();
      final gitService = _FakeGitService();
      final doneService = _FakeDoneService();
      final forensicsService = _FakeTaskForensicsService(
        diagnosisResult: const ForensicDiagnosis(
          classification: ForensicClassification.persistentTestFailure,
          evidence: ['Test failures in 3 consecutive runs'],
          suggestedAction: ForensicAction.retryWithGuidance,
          guidanceText: 'Focus on edge case handling in parser.',
        ),
      );
      final pipeline = _FakeTaskPipelineService(
        _buildPipelineResult(review: _reviewResult(ReviewDecision.reject)),
      );
      final service = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        taskForensicsService: forensicsService,
        maxReviewRetries: 2,
      );
      final projectRoot = _setupProjectWithConfig(
        forensicRecoveryEnabled: true,
      );
      final layout = ProjectLayout(projectRoot);
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(
          retryScheduling: const RetrySchedulingState(
            retryCounts: {'id:alpha-1': 1},
          ),
          // Simulate unattended mode via state flag (not lock file, since
          // that would also activate ReviewService's unattended stash path
          // which uses a real GitService on a non-git temp dir).
          autopilotRun: const AutopilotRunState(
            running: true,
            currentMode: 'autopilot_run',
          ),
        ),
      );

      final result = await service.run(projectRoot, codingPrompt: 'Do work');

      // In unattended mode, retryWithGuidance should be skipped — task blocked.
      expect(result.taskBlocked, isTrue);
      expect(result.retryCount, 2);
      expect(doneService.blockCalls, 1);
      expect(
        doneService.lastBlockReason,
        contains('guidance skipped in unattended mode'),
      );
      // Forensics should still diagnose (to decide the action).
      expect(forensicsService.diagnoseCalls, 1);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(
        runLog,
        contains('"event":"forensic_retry_guidance_skipped_unattended"'),
      );
    },
  );
}

TaskPipelineResult _buildPipelineResult({ReviewAgentResult? review}) {
  return TaskPipelineResult(
    plan: _specResult(SpecKind.plan),
    spec: _specResult(SpecKind.spec),
    subtasks: _specResult(SpecKind.subtasks),
    coding: _codingResult(),
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

CodingAgentResult _codingResult() {
  return CodingAgentResult(
    path: '/tmp/attempt.txt',
    usedFallback: false,
    response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
  );
}

ReviewAgentResult _reviewResult(ReviewDecision decision) {
  return ReviewAgentResult(
    decision: decision,
    response: const AgentResponse(
      exitCode: 0,
      stdout: 'APPROVE\nOK',
      stderr: '',
    ),
    usedFallback: false,
  );
}

class _FakeTaskPipelineService extends TaskPipelineService {
  _FakeTaskPipelineService(this.result, {this.error});

  final TaskPipelineResult result;
  final Object? error;
  int calls = 0;

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
  }) async {
    calls += 1;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

class _FakeReviewService extends ReviewService {
  int calls = 0;
  final List<String> decisions = [];
  int clearCalls = 0;
  String? lastClearNote;

  @override
  String recordDecision(
    String projectRoot, {
    required String decision,
    String? note,
    String? testSummary,
  }) {
    calls += 1;
    decisions.add(decision);
    // Use the real implementation so STATE.json reflects approved/rejected.
    return super.recordDecision(
      projectRoot,
      decision: decision,
      note: note,
      testSummary: testSummary,
    );
  }

  @override
  void clear(String projectRoot, {String? note}) {
    clearCalls += 1;
    lastClearNote = note;
    super.clear(projectRoot, note: note);
  }
}

class _FakeDoneService extends DoneService {
  _FakeDoneService({this.throwNotFoundOnBlock = false});

  final bool throwNotFoundOnBlock;
  int calls = 0;
  int blockCalls = 0;
  String? lastBlockReason;

  @override
  Future<String> markDone(String projectRoot, {bool force = false}) async {
    calls += 1;
    return 'Task';
  }

  @override
  String blockActive(
    String projectRoot, {
    String? reason,
    Map<String, Object?>? diagnostics,
  }) {
    blockCalls += 1;
    lastBlockReason = reason;
    if (throwNotFoundOnBlock) {
      throw StateError('Active task not found in TASKS.md');
    }
    return 'Task';
  }
}

String _setupProject() {
  final temp = Directory.systemTemp.createTempSync('genaisys_cycle_git_');
  final root = temp.path;
  ProjectInitializer(root).ensureStructure(overwrite: true);
  final layout = ProjectLayout(root);
  final stateStore = StateStore(layout.statePath);
  final state = stateStore.read().copyWith(
    activeTask: const ActiveTaskState(title: 'Alpha', id: 'alpha-1'),
  );
  stateStore.write(state);
  return root;
}

class _FakeGitService implements GitService {
  _FakeGitService({this.hasChangesValue = true});

  final List<String> calls = [];
  final bool hasChangesValue;
  String? defaultRemoteValue = 'origin';

  @override
  bool isGitRepo(String path) => true;

  @override
  bool hasChanges(String path) => hasChangesValue;

  @override
  void addAll(String path) {
    calls.add('add');
  }

  @override
  void commit(String path, String message) {
    calls.add('commit: $message');
  }

  @override
  String? defaultRemote(String path) => defaultRemoteValue;

  @override
  String currentBranch(String path) => 'main';

  @override
  bool branchExists(String path, String branch) => true;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) =>
      const <String>[];

  @override
  void push(String path, String remote, String branch) {
    calls.add('push $remote $branch');
  }

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) =>
      ProcessResult(0, 0, '', '');

  @override
  bool tagExists(String path, String tag) => false;

  @override
  void createAnnotatedTag(String path, String tag, {required String message}) {
    calls.add('tag $tag');
  }

  @override
  void pushTag(String path, String remote, String tag) {
    calls.add('push-tag $remote $tag');
  }

  @override
  List<String> changedPaths(String path) => [];

  @override
  void checkout(String path, String ref) {}

  @override
  void createBranch(String path, String branch, {String? startPoint}) {}

  @override
  void abortMerge(String path) {}

  @override
  List<String> conflictPaths(String path) => [];

  @override
  void deleteBranch(String path, String branch, {bool force = false}) {}

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {}

  @override
  String diffPatch(String path) => '';

  @override
  DiffStats diffStats(String path) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  String diffSummary(String path) => '';

  @override
  void ensureClean(String path) {}

  @override
  void fetch(String path, String remote) {}

  @override
  bool hasRemote(String path, String remote) => true;

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    calls.add('stash push');
    return true;
  }

  @override
  void stashPop(String path) {
    calls.add('stash pop');
  }

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool isClean(String path) => true;

  @override
  void merge(String path, String branch) {}

  @override
  void pullFastForward(String path, String remote, String branch) {}

  @override
  bool remoteBranchExists(String path, String remote, String branch) => true;

  @override
  String repoRoot(String path) => path;

  @override
  DiffStats diffStatsBetween(String path, String fromRef, String toRef) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  void discardWorkingChanges(String path) {}

  @override
  int stashCount(String path) => 0;

  @override
  void dropOldestStashes(String path, {required int maxKeep}) {}

  @override
  void removeFromIndexIfTracked(String path, List<String> relativePaths) {}
  @override
  void hardReset(String path, {String ref = 'HEAD'}) {}
  @override
  void cleanUntracked(String path) {}
  @override
  bool hasRebaseInProgress(String path) => false;
  @override
  List<String> recentCommitMessages(String path, {int count = 10}) => const [];
  @override
  String headCommitSha(String path, {bool short = false}) => 'abc1234';
  @override
  void resetIndex(String path) {}
  @override
  int commitCount(String path) => 1;
  @override
  bool hasStagedChanges(String path) => false;
  @override
  String diffSummaryBetween(String path, String fromRef, String toRef) => '';
  @override
  String diffPatchBetween(String path, String fromRef, String toRef) => '';
  @override
  bool isCommitReachable(String path, String sha) => true;
}

/// A [GitService] fake that fails selectively on certain commit messages
/// and optionally on all stash pushes, to exercise the discard fallback paths.
class _FakeGitServiceWithFailures implements GitService {
  _FakeGitServiceWithFailures({
    this.commitFailsOnMessages = const [],
    this.stashAlwaysFails = false,
  });

  final List<String> commitFailsOnMessages;
  final bool stashAlwaysFails;
  final List<String> calls = [];

  @override
  bool isGitRepo(String path) => true;

  @override
  bool hasChanges(String path) => true;

  @override
  void addAll(String path) {
    calls.add('add');
  }

  @override
  void commit(String path, String message) {
    if (commitFailsOnMessages.any((m) => message.contains(m))) {
      calls.add('commit-FAIL: $message');
      throw StateError('Simulated commit failure for: $message');
    }
    calls.add('commit: $message');
  }

  @override
  String? defaultRemote(String path) => 'origin';

  @override
  String currentBranch(String path) => 'main';

  @override
  bool branchExists(String path, String branch) => true;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) =>
      const <String>[];

  @override
  void push(String path, String remote, String branch) {
    calls.add('push $remote $branch');
  }

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) =>
      ProcessResult(0, 0, '', '');

  @override
  bool tagExists(String path, String tag) => false;

  @override
  void createAnnotatedTag(String path, String tag, {required String message}) {
    calls.add('tag $tag');
  }

  @override
  void pushTag(String path, String remote, String tag) {
    calls.add('push-tag $remote $tag');
  }

  @override
  List<String> changedPaths(String path) => [];

  @override
  void checkout(String path, String ref) {}

  @override
  void createBranch(String path, String branch, {String? startPoint}) {}

  @override
  void abortMerge(String path) {}

  @override
  List<String> conflictPaths(String path) => [];

  @override
  void deleteBranch(String path, String branch, {bool force = false}) {}

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {}

  @override
  String diffPatch(String path) => '';

  @override
  DiffStats diffStats(String path) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  String diffSummary(String path) => '';

  @override
  void ensureClean(String path) {}

  @override
  void fetch(String path, String remote) {}

  @override
  bool hasRemote(String path, String remote) => true;

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    if (stashAlwaysFails) {
      throw StateError('Simulated stash failure');
    }
    calls.add('stash push');
    return true;
  }

  @override
  void stashPop(String path) {
    calls.add('stash pop');
  }

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool isClean(String path) => true;

  @override
  void merge(String path, String branch) {}

  @override
  void pullFastForward(String path, String remote, String branch) {}

  @override
  bool remoteBranchExists(String path, String remote, String branch) => true;

  @override
  String repoRoot(String path) => path;

  @override
  DiffStats diffStatsBetween(String path, String fromRef, String toRef) =>
      const DiffStats(filesChanged: 0, additions: 0, deletions: 0);

  @override
  void discardWorkingChanges(String path) {}

  @override
  int stashCount(String path) => 0;

  @override
  void dropOldestStashes(String path, {required int maxKeep}) {}

  @override
  void removeFromIndexIfTracked(String path, List<String> relativePaths) {}
  @override
  void hardReset(String path, {String ref = 'HEAD'}) {}
  @override
  void cleanUntracked(String path) {}
  @override
  bool hasRebaseInProgress(String path) => false;
  @override
  List<String> recentCommitMessages(String path, {int count = 10}) => const [];
  @override
  String headCommitSha(String path, {bool short = false}) => 'abc1234';
  @override
  void resetIndex(String path) {}
  @override
  int commitCount(String path) => 1;
  @override
  bool hasStagedChanges(String path) => false;
  @override
  String diffSummaryBetween(String path, String fromRef, String toRef) => '';
  @override
  String diffPatchBetween(String path, String fromRef, String toRef) => '';
  @override
  bool isCommitReachable(String path, String sha) => true;
}

class _FakeTaskForensicsService extends TaskForensicsService {
  _FakeTaskForensicsService({required this.diagnosisResult});

  final ForensicDiagnosis diagnosisResult;
  int diagnoseCalls = 0;

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
    diagnoseCalls += 1;
    return diagnosisResult;
  }
}

class _FakeErrorPatternRegistryService extends ErrorPatternRegistryService {
  int mergeCalls = 0;
  int recordResolutionCalls = 0;

  @override
  void mergeObservations(
    String projectRoot, {
    required Map<String, int> errorKindCounts,
  }) {
    mergeCalls += 1;
  }

  @override
  bool recordResolutionIfNew(
    String projectRoot,
    String errorKind,
    String strategy,
  ) {
    recordResolutionCalls += 1;
    return true;
  }
}

/// Creates a project with custom config.yml for forensic/error-pattern tests.
String _setupProjectWithConfig({
  bool forensicRecoveryEnabled = false,
  bool errorPatternLearningEnabled = false,
}) {
  final temp = Directory.systemTemp.createTempSync('genaisys_cycle_config_');
  final root = temp.path;
  ProjectInitializer(root).ensureStructure(overwrite: true);
  final layout = ProjectLayout(root);
  final stateStore = StateStore(layout.statePath);
  final state = stateStore.read().copyWith(
    activeTask: const ActiveTaskState(title: 'Alpha', id: 'alpha-1'),
  );
  stateStore.write(state);

  // Write custom config to enable forensic/error-pattern features.
  final configContent = StringBuffer();
  configContent.writeln('pipeline:');
  configContent.writeln(
    '  forensic_recovery_enabled: $forensicRecoveryEnabled',
  );
  configContent.writeln(
    '  error_pattern_learning_enabled: $errorPatternLearningEnabled',
  );
  File(layout.configPath).writeAsStringSync(configContent.toString());

  return root;
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
