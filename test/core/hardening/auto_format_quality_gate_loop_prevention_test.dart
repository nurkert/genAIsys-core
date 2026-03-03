import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/review_bundle.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/services/build_test_runner_service.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_bundle_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';

import '../../support/fake_services.dart';

/// §13 Anti-Block Regression Suite — Test #4
///
/// AGENTS.md §13 requirement:
///   "Auto-format executes before quality gate so pure format drift does not
///    produce reject loops."
///
/// Three scenarios:
/// 1. Format-only diff → auto-format clears diff → pipeline stops before QG
///    (StageEarlyReturn from _PostFormatNoDiffCheckStage → review == null).
/// 2. Semantic diff → QG IS reached and passes (control test).
/// 3. Format-only diff WITHOUT auto-format clearing → QG IS reached, throws
///    retryable error → reject (shows what happens if auto-format is absent).
void main() {
  group('§13 Test #4 — Auto-format prevents quality-gate reject loops', () {
    // -----------------------------------------------------------------------
    // 1. Format-only drift → auto-format clears diff → QG NOT reached
    // -----------------------------------------------------------------------
    test(
      'format-only drift: auto-format clears diff, QG not reached, no reject',
      () async {
        final calls = <String>[];
        // git reports: pre-format = dirty, post-format = clean (format fixed it)
        final git = _SequentialGitService([
          ['lib/core/drift_only.dart'], // call #1: initial changedPaths
          ['lib/core/drift_only.dart'], // call #2: safe_write check
          [], // call #3: post-format — auto-format cleared all changes
        ]);
        final runner = _TrackingBuildTestRunnerService(calls);
        final pipeline = TaskPipelineService(
          specAgentService: _AlwaysOkSpecAgent(calls),
          codingAgentService: _AlwaysOkCodingAgent(calls),
          reviewAgentService: _AlwaysApproveReviewAgent(calls),
          reviewBundleService: _FakeBundle(calls),
          buildTestRunnerService: runner,
          gitService: git,
        );

        final root = _createRoot();
        final result = await pipeline.run(
          root,
          codingPrompt: 'Fix format drift',
          testSummary: 'All tests passed',
        );

        // Pipeline stopped at _PostFormatNoDiffCheckStage: no review, no reject.
        expect(
          result.review,
          isNull,
          reason: 'Format-only drift must not produce a reject review',
        );
        expect(calls, contains('format'), reason: 'Auto-format must run');
        expect(
          calls,
          isNot(contains('quality')),
          reason: 'QG must NOT be reached for format-only diff',
        );
      },
    );

    // -----------------------------------------------------------------------
    // 2. Semantic diff → QG IS reached (control test)
    // -----------------------------------------------------------------------
    test(
      'semantic diff: QG is reached and passes (control test)',
      () async {
        final calls = <String>[];
        // Same changed paths before and after format — semantic change persists.
        final git = FakeGitService(
          changedPathsValue: ['lib/core/feature.dart'],
        );
        final runner = _TrackingBuildTestRunnerService(calls);
        final pipeline = TaskPipelineService(
          specAgentService: _AlwaysOkSpecAgent(calls),
          codingAgentService: _AlwaysOkCodingAgent(calls),
          reviewAgentService: _AlwaysApproveReviewAgent(calls),
          reviewBundleService: _FakeBundle(calls),
          buildTestRunnerService: runner,
          gitService: git,
        );

        final root = _createRoot();
        final result = await pipeline.run(
          root,
          codingPrompt: 'Add feature',
          testSummary: 'All tests passed',
        );

        expect(
          result.review,
          isNotNull,
          reason: 'Semantic diff must reach review agent',
        );
        expect(result.review!.decision, ReviewDecision.approve);
        expect(
          calls,
          contains('quality'),
          reason: 'QG must be reached for semantic diff',
        );
      },
    );

    // -----------------------------------------------------------------------
    // 3. Format-only drift WITHOUT auto-format clearing → QG reached → reject
    // -----------------------------------------------------------------------
    test(
      'format-only drift without auto-format clearing: QG reached, produces reject',
      () async {
        // Simulates what happens WITHOUT auto-format fixing the drift:
        // git still reports the file as changed even after auto-format ran
        // (i.e., auto-format did not resolve the formatting issue).
        // _PostFormatNoDiffCheckStage sees non-empty changedPaths → continues.
        // QG then fails (format-check rejects) → StageReject → review reject.
        final calls = <String>[];
        final git = FakeGitService(
          changedPathsValue: ['lib/core/drift_only.dart'],
        );
        final runner = _FailingQgBuildTestRunnerService(calls);
        final pipeline = TaskPipelineService(
          specAgentService: _AlwaysOkSpecAgent(calls),
          codingAgentService: _AlwaysOkCodingAgent(calls),
          reviewAgentService: _AlwaysApproveReviewAgent(calls),
          reviewBundleService: _FakeBundle(calls),
          buildTestRunnerService: runner,
          gitService: git,
        );

        final root = _createRoot();
        final result = await pipeline.run(root, codingPrompt: 'Drift');

        expect(
          calls,
          contains('quality'),
          reason:
              'Without format-clearing, QG must be reached (drift still visible)',
        );
        expect(result.review, isNotNull);
        expect(
          result.review!.decision,
          ReviewDecision.reject,
          reason:
              'Format-only drift without clearing causes QG reject loop '
              '(this is the failure mode auto-format prevents)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _createRoot() {
  final temp = Directory.systemTemp.createTempSync('genaisys_af_qg_loop_');
  addTearDown(() => temp.deleteSync(recursive: true));
  ProjectInitializer(temp.path).ensureStructure(overwrite: true);
  return temp.path;
}

// ---------------------------------------------------------------------------
// Sequential git service — returns different changedPaths per successive call.
// All other GitService methods delegate to FakeGitService defaults.
// ---------------------------------------------------------------------------

class _SequentialGitService extends FakeGitService {
  _SequentialGitService(this._results)
    : super(changedPathsValue: _results.first);

  final List<List<String>> _results;
  int _idx = 0;

  @override
  List<String> changedPaths(String path) {
    final r = _idx < _results.length ? _results[_idx] : _results.last;
    _idx++;
    return r;
  }
}

// ---------------------------------------------------------------------------
// Build test runner that records auto-format and QG invocations (QG passes).
// ---------------------------------------------------------------------------

class _TrackingBuildTestRunnerService extends BuildTestRunnerService {
  _TrackingBuildTestRunnerService(this._calls)
    : super(commandRunner: _NoopShellRunner());

  final List<String> _calls;

  @override
  Future<AutoFormatOutcome> autoFormatChangedDartFiles(
    String projectRoot, {
    required List<String> changedPaths,
  }) async {
    _calls.add('format');
    return const AutoFormatOutcome(executed: true, files: 0);
  }

  @override
  Future<BuildTestRunnerOutcome> run(
    String projectRoot, {
    List<String>? changedPaths,
  }) async {
    _calls.add('quality');
    return const BuildTestRunnerOutcome(
      executed: true,
      summary: 'Quality Gate: passed',
    );
  }
}

// ---------------------------------------------------------------------------
// Build test runner that records calls and makes QG fail with a retryable
// StateError (simulates a format-check failure → StageReject → reject loop).
// ---------------------------------------------------------------------------

class _FailingQgBuildTestRunnerService extends BuildTestRunnerService {
  _FailingQgBuildTestRunnerService(this._calls)
    : super(commandRunner: _NoopShellRunner());

  final List<String> _calls;

  @override
  Future<AutoFormatOutcome> autoFormatChangedDartFiles(
    String projectRoot, {
    required List<String> changedPaths,
  }) async {
    _calls.add('format');
    return const AutoFormatOutcome(executed: true, files: 0);
  }

  @override
  Future<BuildTestRunnerOutcome> run(
    String projectRoot, {
    List<String>? changedPaths,
  }) async {
    _calls.add('quality');
    // Retryable pattern: 'Policy violation: quality_gate command failed' →
    // TaskPipelineService catches this as StageReject.
    throw StateError(
      'Policy violation: quality_gate command failed (exit 1): '
      '"dart format --output=none --set-exit-if-changed .".',
    );
  }
}

class _NoopShellRunner implements ShellCommandRunner {
  const _NoopShellRunner();

  @override
  Future<ShellCommandResult> run(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  }) {
    throw UnimplementedError(
      '_NoopShellRunner: should not be called in these tests.',
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal fake spec/coding/review/bundle agents.
// ---------------------------------------------------------------------------

class _AlwaysOkSpecAgent extends SpecAgentService {
  _AlwaysOkSpecAgent(this._calls);
  final List<String> _calls;

  @override
  Future<SpecAgentResult> generate(
    String projectRoot, {
    required SpecKind kind,
    bool overwrite = false,
    String? guidanceContext,
  }) async {
    return SpecAgentResult(
      path: '/tmp/${kind.name}.md',
      kind: kind,
      wrote: true,
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    );
  }

  @override
  Future<AcSelfCheckResult> checkImplementationAgainstAc(
    String projectRoot, {
    required String requirement,
    required String diffSummary,
  }) async =>
      const AcSelfCheckResult(passed: true, skipped: false);
}

class _AlwaysOkCodingAgent extends CodingAgentService {
  _AlwaysOkCodingAgent(this._calls);
  final List<String> _calls;

  @override
  Future<CodingAgentResult> run(
    String projectRoot, {
    required String prompt,
    String? systemPrompt,
    TaskCategory? taskCategory,
  }) async {
    _calls.add('coding');
    return CodingAgentResult(
      path: '/tmp/attempt.txt',
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    );
  }
}

class _AlwaysApproveReviewAgent extends ReviewAgentService {
  _AlwaysApproveReviewAgent(this._calls);
  final List<String> _calls;

  @override
  Future<ReviewAgentResult> reviewBundle(
    String projectRoot, {
    required ReviewBundle bundle,
    ReviewPersona persona = ReviewPersona.general,
    String strictness = 'standard',
    List<String> contractNotes = const [],
  }) async {
    _calls.add('review');
    return ReviewAgentResult(
      decision: ReviewDecision.approve,
      response: const AgentResponse(exitCode: 0, stdout: 'APPROVE', stderr: ''),
      usedFallback: false,
    );
  }
}

class _FakeBundle extends ReviewBundleService {
  _FakeBundle(this._calls);
  final List<String> _calls;

  @override
  ReviewBundle build(
    String projectRoot, {
    String? testSummary,
    String? sinceCommitSha,
  }) {
    _calls.add('bundle');
    return ReviewBundle(
      diffSummary: 'diff summary',
      diffPatch: '@@ diff patch @@',
      testSummary: testSummary,
      taskTitle: 'Task',
      spec: 'Spec',
    );
  }
}
