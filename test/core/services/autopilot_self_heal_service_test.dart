import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_self_heal_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/storage/run_log_store.dart';

void main() {
  group('AutopilotSelfHealService', () {
    group('canAttemptSelfHeal', () {
      late AutopilotSelfHealService service;

      setUp(() {
        service = AutopilotSelfHealService();
      });

      test('returns false when disabled', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: false,
            attemptsUsed: 0,
            maxAttempts: 3,
            errorKind: 'test_failed',
            unattendedMode: false,
          ),
          isFalse,
        );
      });

      test('returns false when max attempts exhausted', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 3,
            maxAttempts: 3,
            errorKind: 'test_failed',
            unattendedMode: false,
          ),
          isFalse,
        );
      });

      test('returns false for maxAttempts < 1', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 0,
            maxAttempts: 0,
            errorKind: 'test_failed',
            unattendedMode: false,
          ),
          isFalse,
        );
      });

      test('returns false for ineligible error kind', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 0,
            maxAttempts: 3,
            errorKind: 'unknown_error',
            unattendedMode: false,
          ),
          isFalse,
        );
      });

      test('returns true for eligible error kind with budget', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 0,
            maxAttempts: 3,
            errorKind: 'test_failed',
            unattendedMode: false,
          ),
          isTrue,
        );
      });

      test('blocks review_rejected in unattended mode', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 0,
            maxAttempts: 3,
            errorKind: 'review_rejected',
            unattendedMode: true,
          ),
          isFalse,
        );
      });

      test('blocks no_diff in unattended mode', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 0,
            maxAttempts: 3,
            errorKind: 'no_diff',
            unattendedMode: true,
          ),
          isFalse,
        );
      });

      test('blocks timeout in unattended mode', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 0,
            maxAttempts: 3,
            errorKind: 'timeout',
            unattendedMode: true,
          ),
          isFalse,
        );
      });

      test('allows review_rejected in attended mode', () {
        expect(
          service.canAttemptSelfHeal(
            enabled: true,
            attemptsUsed: 0,
            maxAttempts: 3,
            errorKind: 'review_rejected',
            unattendedMode: false,
          ),
          isTrue,
        );
      });
    });

    group('isSelfHealEligibleErrorKind', () {
      late AutopilotSelfHealService service;

      setUp(() {
        service = AutopilotSelfHealService();
      });

      test('returns false for null', () {
        expect(service.isSelfHealEligibleErrorKind(null), isFalse);
      });

      test('returns false for empty', () {
        expect(service.isSelfHealEligibleErrorKind(''), isFalse);
      });

      test('returns false for unknown errors', () {
        expect(service.isSelfHealEligibleErrorKind('random_unknown'), isFalse);
      });

      test('returns true for all eligible error kinds', () {
        for (final kind in [
          'policy_violation',
          'quality_gate_failed',
          'analyze_failed',
          'test_failed',
          'timeout',
          'review_rejected',
          'no_diff',
          'diff_budget',
          'merge_conflict',
          'git_dirty',
          'not_found',
          'no_active_task',
        ]) {
          expect(
            service.isSelfHealEligibleErrorKind(kind),
            isTrue,
            reason: 'Expected $kind to be eligible',
          );
        }
      });
    });

    group('buildSelfHealPrompt', () {
      late AutopilotSelfHealService service;
      late Directory temp;

      setUp(() {
        service = AutopilotSelfHealService();
        temp = Directory.systemTemp.createTempSync('self_heal_prompt_');
      });

      tearDown(() {
        temp.deleteSync(recursive: true);
      });

      test('includes base coding prompt', () {
        final result = service.buildSelfHealPrompt(
          projectRoot: temp.path,
          codingPrompt: 'Implement feature X',
          errorKind: 'test_failed',
          errorMessage: 'Tests failed',
        );

        expect(result, contains('Implement feature X'));
        expect(result, contains('AUTOPILOT SELF-HEAL MODE'));
        expect(result, contains('test_failed'));
        expect(result, contains('Tests failed'));
      });

      test('includes no-diff guidance for no_diff errors', () {
        final result = service.buildSelfHealPrompt(
          projectRoot: temp.path,
          codingPrompt: 'Do the task',
          errorKind: 'no_diff',
          errorMessage: 'No diff produced',
        );

        expect(result, contains('No-diff guidance'));
        expect(result, contains('BLOCK: no_diff_no_op'));
      });

      test('includes timeout guidance for timeout errors', () {
        final result = service.buildSelfHealPrompt(
          projectRoot: temp.path,
          codingPrompt: 'Do the task',
          errorKind: 'timeout',
          errorMessage: 'Agent timed out',
        );

        expect(result, contains('Timeout guidance'));
        expect(result, contains('BLOCK: timeout_scope_too_large'));
      });

      test('includes review note when provided', () {
        final result = service.buildSelfHealPrompt(
          projectRoot: temp.path,
          codingPrompt: 'Do the task',
          errorKind: 'review_rejected',
          errorMessage: 'Review rejected',
          reviewNote: 'Missing test coverage for edge case',
        );

        expect(result, contains('Latest review note:'));
        expect(result, contains('Missing test coverage for edge case'));
      });

      test('omits review block when review note is null', () {
        final result = service.buildSelfHealPrompt(
          projectRoot: temp.path,
          codingPrompt: 'Do the task',
          errorKind: 'review_rejected',
          errorMessage: 'Review rejected',
        );

        expect(result, isNot(contains('Latest review note:')));
      });
    });

    group('attemptSelfHealFallback', () {
      test('returns true when recovery step makes progress', () async {
        final temp = Directory.systemTemp.createTempSync('self_heal_ok_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final stepService = _FakeStepService(
          OrchestratorStepResult(
            executedCycle: true,
            activatedTask: false,
            activeTaskId: 'task-1',
            activeTaskTitle: 'Task',
            plannedTasksAdded: 0,
            reviewDecision: 'approve',
            retryCount: 0,
            blockedTask: false,
            deactivatedTask: false,
            currentSubtask: null,
            autoMarkedDone: true,
            approvedDiffStats: null,
          ),
        );

        final service = AutopilotSelfHealService(stepService: stepService);

        final result = await service.attemptSelfHealFallback(
          temp.path,
          codingPrompt: 'Fix it',
          testSummary: null,
          overwriteArtifacts: false,
          minOpenTasks: 1,
          maxPlanAdd: 1,
          stepId: 'step-1',
          stepIndex: 1,
          errorKind: 'test_failed',
          errorMessage: 'Tests failed',
          attempt: 1,
          maxAttempts: 3,
          maxTaskRetries: 3,
        );

        expect(result, isTrue);

        final runLog = File(
          ProjectLayout(temp.path).runLogPath,
        ).readAsStringSync();
        expect(runLog, contains('orchestrator_run_self_heal_attempt'));
        expect(runLog, contains('orchestrator_run_self_heal_success'));
      });

      test('returns false when recovery step has no progress', () async {
        final temp = Directory.systemTemp.createTempSync('self_heal_nop_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final stepService = _FakeStepService(
          OrchestratorStepResult(
            executedCycle: true,
            activatedTask: false,
            activeTaskId: 'task-1',
            activeTaskTitle: 'Task',
            plannedTasksAdded: 0,
            reviewDecision: null,
            retryCount: 0,
            blockedTask: false,
            deactivatedTask: false,
            currentSubtask: null,
            autoMarkedDone: false,
            approvedDiffStats: null,
          ),
        );

        final service = AutopilotSelfHealService(stepService: stepService);

        final result = await service.attemptSelfHealFallback(
          temp.path,
          codingPrompt: 'Fix it',
          testSummary: null,
          overwriteArtifacts: false,
          minOpenTasks: 1,
          maxPlanAdd: 1,
          stepId: 'step-1',
          stepIndex: 1,
          errorKind: 'no_diff',
          errorMessage: 'No diff produced',
          attempt: 1,
          maxAttempts: 3,
          maxTaskRetries: 3,
        );

        expect(result, isFalse);

        final runLog = File(
          ProjectLayout(temp.path).runLogPath,
        ).readAsStringSync();
        expect(runLog, contains('orchestrator_run_self_heal_no_progress'));
      });

      test('returns false when recovery step throws', () async {
        final temp = Directory.systemTemp.createTempSync('self_heal_err_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final stepService = _ThrowingStepService(StateError('boom'));
        final service = AutopilotSelfHealService(stepService: stepService);

        final result = await service.attemptSelfHealFallback(
          temp.path,
          codingPrompt: 'Fix it',
          testSummary: null,
          overwriteArtifacts: false,
          minOpenTasks: 1,
          maxPlanAdd: 1,
          stepId: 'step-1',
          stepIndex: 1,
          errorKind: 'test_failed',
          errorMessage: 'Tests failed',
          attempt: 1,
          maxAttempts: 3,
          maxTaskRetries: 3,
        );

        expect(result, isFalse);

        final runLog = File(
          ProjectLayout(temp.path).runLogPath,
        ).readAsStringSync();
        expect(runLog, contains('orchestrator_run_self_heal_failed'));
      });

      test('reads review reject note from run log', () async {
        final temp = Directory.systemTemp.createTempSync('self_heal_note_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        // Write a review_reject event to the run log.
        final layout = ProjectLayout(temp.path);
        RunLogStore(layout.runLogPath).append(
          event: 'review_reject',
          message: 'Review rejected',
          data: {'note': 'Missing test for edge case'},
        );

        final prompts = <String>[];
        final stepService = _PromptCapturingStepService(
          prompts,
          OrchestratorStepResult(
            executedCycle: true,
            activatedTask: false,
            activeTaskId: null,
            activeTaskTitle: null,
            plannedTasksAdded: 0,
            reviewDecision: 'approve',
            retryCount: 0,
            blockedTask: false,
            deactivatedTask: false,
            currentSubtask: null,
            autoMarkedDone: true,
            approvedDiffStats: null,
          ),
        );

        final service = AutopilotSelfHealService(stepService: stepService);
        await service.attemptSelfHealFallback(
          temp.path,
          codingPrompt: 'Fix it',
          testSummary: null,
          overwriteArtifacts: false,
          minOpenTasks: 1,
          maxPlanAdd: 1,
          stepId: 'step-1',
          stepIndex: 1,
          errorKind: 'review_rejected',
          errorMessage: 'Review rejected',
          attempt: 1,
          maxAttempts: 3,
          maxTaskRetries: 3,
        );

        expect(prompts, hasLength(1));
        expect(prompts.first, contains('Missing test for edge case'));
      });
    });
  });
}

class _FakeStepService extends OrchestratorStepService {
  _FakeStepService(this._result);
  final OrchestratorStepResult _result;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    return _result;
  }
}

class _ThrowingStepService extends OrchestratorStepService {
  _ThrowingStepService(this._error);
  final Object _error;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    throw _error;
  }
}

class _PromptCapturingStepService extends OrchestratorStepService {
  _PromptCapturingStepService(this._prompts, this._result);
  final List<String> _prompts;
  final OrchestratorStepResult _result;

  @override
  Future<OrchestratorStepResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    int? maxTaskRetries,
  }) async {
    _prompts.add(codingPrompt);
    return _result;
  }
}
