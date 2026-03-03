import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/review_bundle.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/audit_trail_service.dart';
import 'package:genaisys/core/services/review_bundle_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/builders.dart';
import '../../support/fake_services.dart';
import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late ReviewService service;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_review_svc_');
    workspace.ensureStructure();
    service = ReviewService(gitService: FakeGitService());
  });

  tearDown(() => workspace.dispose());

  /// Seed an active task at a given workflow stage.
  void seedActiveTask({
    String title = 'My Task',
    WorkflowStage stage = WorkflowStage.execution,
  }) {
    final state = ProjectStateBuilder()
        .withActiveTask('my-task-0', title)
        .withWorkflowStage(stage)
        .build();
    StateStore(workspace.layout.statePath).write(state);
  }

  test('recordDecision approve sets status to approved', () {
    seedActiveTask();

    final task = service.recordDecision(
      workspace.root.path,
      decision: 'approve',
    );

    expect(task, 'My Task');
    final state = StateStore(workspace.layout.statePath).read();
    expect(state.reviewStatus, 'approved');
    expect(state.reviewUpdatedAt, isNotNull);
    expect(state.reviewUpdatedAt, isNotEmpty);
  });

  test('recordDecision reject sets status to rejected', () {
    seedActiveTask();

    service.recordDecision(workspace.root.path, decision: 'reject');

    final state = StateStore(workspace.layout.statePath).read();
    expect(state.reviewStatus, 'rejected');
    expect(state.reviewUpdatedAt, isNotNull);
  });

  test('approve advances workflow execution → review → done', () {
    seedActiveTask(stage: WorkflowStage.execution);

    service.recordDecision(workspace.root.path, decision: 'approve');

    final state = StateStore(workspace.layout.statePath).read();
    // execution → review → done
    expect(state.workflowStage, WorkflowStage.done);
  });

  test('reject advances workflow execution → review → execution', () {
    seedActiveTask(stage: WorkflowStage.execution);

    service.recordDecision(workspace.root.path, decision: 'reject');

    final state = StateStore(workspace.layout.statePath).read();
    // execution → review → execution (back-loop)
    expect(state.workflowStage, WorkflowStage.execution);
  });

  test('status returns current review state', () {
    final state = ProjectStateBuilder()
        .withActiveTask('t-1', 'Task')
        .withReview('approved', updatedAt: '2026-01-15T12:00:00Z')
        .build();
    StateStore(workspace.layout.statePath).write(state);

    final snapshot = service.status(workspace.root.path);
    expect(snapshot.status, 'approved');
    expect(snapshot.updatedAt, '2026-01-15T12:00:00Z');
  });

  test('status returns (none) when no review recorded', () {
    final state = ProjectStateBuilder()
        .withActiveTask('t-1', 'Task')
        .withNoReview()
        .build();
    StateStore(workspace.layout.statePath).write(state);

    final snapshot = service.status(workspace.root.path);
    expect(snapshot.status, '(none)');
    expect(snapshot.updatedAt, '(none)');
  });

  test('recordDecision without active task throws', () {
    final state = ProjectStateBuilder().withNoActiveTask().build();
    StateStore(workspace.layout.statePath).write(state);

    expect(
      () => service.recordDecision(workspace.root.path, decision: 'approve'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No active task set'),
        ),
      ),
    );
  });

  test('clear resets review status and transitions to execution', () {
    final state = ProjectStateBuilder()
        .withActiveTask('t-1', 'Task')
        .withReview('rejected')
        .withWorkflowStage(WorkflowStage.review)
        .build();
    StateStore(workspace.layout.statePath).write(state);

    service.clear(workspace.root.path);

    final updated = StateStore(workspace.layout.statePath).read();
    expect(updated.reviewStatus, isNull);
    expect(updated.reviewUpdatedAt, isNull);
    // review → execution on clear.
    expect(updated.workflowStage, WorkflowStage.execution);
  });

  // -------------------------------------------------------------------------
  // Chunk 2: ReviewService normalizeAfterReject error paths
  // -------------------------------------------------------------------------

  test('normalizeAfterReject is no-op when not in unattended mode', () {
    seedActiveTask();
    service.recordDecision(workspace.root.path, decision: 'reject');

    // No lock file → not unattended → normalizeAfterReject should be no-op.
    expect(File(workspace.layout.autopilotLockPath).existsSync(), isFalse);

    service.normalizeAfterReject(workspace.root.path);

    // Review status should still be rejected (not cleared).
    final state = StateStore(workspace.layout.statePath).read();
    expect(state.reviewStatus, 'rejected');
  });

  test('normalizeAfterReject clears review in unattended mode', () {
    seedActiveTask();
    service.recordDecision(workspace.root.path, decision: 'reject');

    // Create lock file to simulate unattended mode.
    Directory(workspace.layout.locksDir).createSync(recursive: true);
    File(workspace.layout.autopilotLockPath).writeAsStringSync('lock');

    service.normalizeAfterReject(workspace.root.path);

    // Review status should be cleared.
    final state = StateStore(workspace.layout.statePath).read();
    expect(state.reviewStatus, isNull);
    expect(state.reviewUpdatedAt, isNull);
  });

  test('normalizeAfterReject handles stash failure gracefully', () {
    final throwingGit = _ThrowOnStashGitService();
    final throwingService = ReviewService(gitService: throwingGit);

    seedActiveTask();
    throwingService.recordDecision(workspace.root.path, decision: 'reject');

    // Create lock file to simulate unattended mode.
    Directory(workspace.layout.locksDir).createSync(recursive: true);
    File(workspace.layout.autopilotLockPath).writeAsStringSync('lock');

    // Should NOT throw — stash failure is caught internally.
    expect(
      () => throwingService.normalizeAfterReject(workspace.root.path),
      returnsNormally,
    );

    // Review should still be cleared despite stash failure.
    final state = StateStore(workspace.layout.statePath).read();
    expect(state.reviewStatus, isNull);
  });

  test('normalizeAfterReject logs stash failure to run log', () {
    final throwingGit = _ThrowOnStashGitService();
    final throwingService = ReviewService(gitService: throwingGit);

    seedActiveTask();
    throwingService.recordDecision(workspace.root.path, decision: 'reject');

    Directory(workspace.layout.locksDir).createSync(recursive: true);
    File(workspace.layout.autopilotLockPath).writeAsStringSync('lock');

    throwingService.normalizeAfterReject(workspace.root.path);

    // Verify the stash failure was logged.
    final runLogFile = File(workspace.layout.runLogPath);
    expect(runLogFile.existsSync(), isTrue);
    final lines = runLogFile.readAsLinesSync().where(
      (l) => l.trim().isNotEmpty,
    );
    final stashFailLines = lines.where((line) {
      try {
        final entry = jsonDecode(line) as Map<String, Object?>;
        return entry['event'] == 'review_reject_autostash_failed';
      } catch (_) {
        return false;
      }
    });
    expect(
      stashFailLines,
      isNotEmpty,
      reason: 'Expected review_reject_autostash_failed log event',
    );
  });

  test(
    'recordDecision with approve sets updatedAt to a valid ISO8601 timestamp',
    () {
      seedActiveTask();

      final before = DateTime.now().toUtc();
      service.recordDecision(workspace.root.path, decision: 'approve');
      final after = DateTime.now().toUtc();

      final state = StateStore(workspace.layout.statePath).read();
      expect(state.reviewUpdatedAt, isNotNull);
      final updatedAt = DateTime.parse(state.reviewUpdatedAt!);
      expect(
        updatedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    },
  );

  test('audit trail is created even when review bundle build throws', () {
    seedActiveTask();

    // Use an AuditTrailService with a throwing ReviewBundleService.
    final auditService = AuditTrailService(
      gitService: FakeGitService(),
      reviewBundleService: _ThrowingReviewBundleService(),
    );

    // Should not throw — bundle failure is caught internally.
    expect(
      () => auditService.recordReviewDecision(
        workspace.root.path,
        decision: 'reject',
        note: 'bad code',
        testSummary: '3 tests passed',
      ),
      returnsNormally,
    );

    // Verify audit directory was created despite bundle failure.
    final auditDir = Directory(workspace.layout.auditDir);
    expect(auditDir.existsSync(), isTrue);

    // Verify summary.json was written with decision and fallback diff.
    final entries = auditDir.listSync(recursive: true);
    final summaryFiles = entries.whereType<File>().where(
      (f) => f.path.endsWith('summary.json'),
    );
    expect(summaryFiles, isNotEmpty, reason: 'summary.json must be created');

    final summary = jsonDecode(summaryFiles.first.readAsStringSync())
        as Map<String, Object?>;
    expect(summary['decision'], 'reject');
    expect(summary['kind'], 'review');

    // Verify run log captured the bundle build failure.
    final runLogFile = File(workspace.layout.runLogPath);
    expect(runLogFile.existsSync(), isTrue);
    final lines = runLogFile
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty);
    final bundleFailLines = lines.where((line) {
      try {
        final entry = jsonDecode(line) as Map<String, Object?>;
        return entry['event'] == 'audit_diff_bundle_failed';
      } catch (_) {
        return false;
      }
    });
    expect(
      bundleFailLines,
      isNotEmpty,
      reason: 'Expected audit_diff_bundle_failed log event',
    );
  });

  test('recordDecision returns (unknown) in unattended mode with no active task',
      () {
    // Seed state without an active task.
    StateStore(workspace.layout.statePath)
        .write(ProjectStateBuilder().build());
    // Create autopilot lock to simulate unattended mode.
    final lockDir = Directory(workspace.layout.locksDir);
    if (!lockDir.existsSync()) lockDir.createSync(recursive: true);
    File(workspace.layout.autopilotLockPath).writeAsStringSync('{}');

    final result = service.recordDecision(
      workspace.root.path,
      decision: 'reject',
    );

    expect(result, '(unknown)');
    final logContent = File(workspace.layout.runLogPath).readAsStringSync();
    expect(logContent, contains('review_decision_no_active_task'));
  });

  test('recordDecision throws in attended mode with no active task', () {
    // Seed state without an active task and no autopilot lock.
    StateStore(workspace.layout.statePath)
        .write(ProjectStateBuilder().build());

    expect(
      () => service.recordDecision(
        workspace.root.path,
        decision: 'reject',
      ),
      throwsA(isA<StateError>()),
    );
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A GitService that throws on [stashPush] but reports changes exist.
class _ThrowOnStashGitService extends FakeGitService {
  _ThrowOnStashGitService() : super(isCleanValue: false);

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    throw StateError('Simulated stash failure');
  }
}

/// A ReviewBundleService that always throws on [build].
class _ThrowingReviewBundleService extends ReviewBundleService {
  _ThrowingReviewBundleService() : super(gitService: FakeGitService());

  @override
  ReviewBundle build(
    String projectRoot, {
    String? testSummary,
    String? sinceCommitSha,
  }) {
    throw StateError('Simulated bundle build failure');
  }
}
