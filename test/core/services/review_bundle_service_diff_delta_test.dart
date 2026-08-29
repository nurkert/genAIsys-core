import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/review_bundle_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/fake_services.dart';

// ---------------------------------------------------------------------------
// Feature D: ReviewBundleService.build — sinceCommitSha / diff-delta logic
//
// The service chooses between a delta diff (diffPatchBetween / diffSummaryBetween)
// and the normal working-tree diff (diffPatch / diffSummary) based on:
//   - sinceCommitSha == null               → normal diff
//   - sinceCommitSha == HEAD commit sha    → normal diff (HEAD not advanced)
//   - sinceCommitSha != HEAD commit sha    → delta diff (between sha and HEAD)
// ---------------------------------------------------------------------------

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_review_bundle_delta_test_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);

    // Seed a minimal active task so the service can read state.
    final store = StateStore(layout.statePath);
    store.write(
      store.read().copyWith(
        activeTask: ActiveTaskState(
          id: 'some-task-1',
          title: 'Some task',
        ),
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  // Helper: build a FakeGitService configured with the specified HEAD SHA and
  // separate values for working-tree vs. between-diff output.
  FakeGitService buildFakeGit({
    required String headSha,
    String workingTreeDiff = 'working-tree-patch',
    String workingTreeSummary = 'working-tree-summary',
    String betweenDiff = 'between-patch',
    String betweenSummary = 'between-summary',
  }) {
    return _ConfigurableFakeGitService(
      headSha: headSha,
      workingTreeDiff: workingTreeDiff,
      workingTreeSummary: workingTreeSummary,
      betweenDiff: betweenDiff,
      betweenSummary: betweenSummary,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // sinceCommitSha == null → normal diff
  // ─────────────────────────────────────────────────────────────────────

  test(
    'null sinceCommitSha → uses normal diffPatch / diffSummary',
    () {
      final git = buildFakeGit(headSha: 'abc123');
      final service = ReviewBundleService(gitService: git);

      final bundle = service.build(temp.path, sinceCommitSha: null);

      expect(bundle.diffPatch, 'working-tree-patch');
      expect(bundle.diffSummary, 'working-tree-summary');
      expect(
        (git as _ConfigurableFakeGitService).diffPatchCalled,
        isTrue,
        reason: 'Should call diffPatch (not diffPatchBetween)',
      );
      expect(
        git.diffPatchBetweenCalled,
        isFalse,
        reason: 'Should NOT call diffPatchBetween when sinceCommitSha is null',
      );
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // sinceCommitSha == HEAD → fallback to normal diff (HEAD not advanced)
  // ─────────────────────────────────────────────────────────────────────

  test(
    'sinceCommitSha == HEAD sha → uses normal diff (HEAD not advanced)',
    () {
      const headSha = 'headsha1234567890abcdef';
      final git = buildFakeGit(headSha: headSha);
      final service = ReviewBundleService(gitService: git);

      // sinceCommitSha matches HEAD → useDelta = false.
      final bundle = service.build(temp.path, sinceCommitSha: headSha);

      expect(bundle.diffPatch, 'working-tree-patch');
      expect(bundle.diffSummary, 'working-tree-summary');
      expect(
        (git as _ConfigurableFakeGitService).diffPatchBetweenCalled,
        isFalse,
        reason: 'Must not use delta when HEAD matches sinceCommitSha',
      );
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // sinceCommitSha != HEAD → uses diffPatchBetween
  // ─────────────────────────────────────────────────────────────────────

  test(
    'sinceCommitSha != HEAD sha → uses diffPatchBetween(sha, HEAD)',
    () {
      const headSha = 'newcommitsha9876543210ab';
      const oldSha = 'oldsha1234567890abcdefgh';
      final git = buildFakeGit(headSha: headSha);
      final service = ReviewBundleService(gitService: git);

      final bundle = service.build(temp.path, sinceCommitSha: oldSha);

      expect(bundle.diffPatch, 'between-patch');
      expect(bundle.diffSummary, 'between-summary');
      expect(
        (git as _ConfigurableFakeGitService).diffPatchBetweenCalled,
        isTrue,
        reason: 'Must use delta diff when HEAD differs from sinceCommitSha',
      );
      expect(
        git.lastBetweenFromRef,
        oldSha,
        reason: 'fromRef should be the sinceCommitSha',
      );
      expect(
        git.lastBetweenToRef,
        'HEAD',
        reason: 'toRef should be HEAD',
      );
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // testSummary is forwarded to the bundle
  // ─────────────────────────────────────────────────────────────────────

  test(
    'testSummary is normalized and included in the bundle',
    () {
      final git = buildFakeGit(headSha: 'abc123');
      final service = ReviewBundleService(gitService: git);

      final bundle = service.build(
        temp.path,
        testSummary: '  42 passed, 0 failed  ',
        sinceCommitSha: null,
      );

      // testSummary is trimmed via _normalizeOptional.
      expect(bundle.testSummary, '42 passed, 0 failed');
    },
  );

  test(
    'empty testSummary → bundle.testSummary is null',
    () {
      final git = buildFakeGit(headSha: 'abc123');
      final service = ReviewBundleService(gitService: git);

      final bundle = service.build(temp.path, testSummary: '   ');

      expect(bundle.testSummary, isNull);
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Fix 2: SHA reachability guard — unreachable sinceCommitSha falls back
  // to normal working-tree diff instead of broken between-diff.
  // ─────────────────────────────────────────────────────────────────────

  test(
    'unreachable sinceCommitSha → falls back to normal diffPatch (not between-diff)',
    () {
      const headSha = 'newcommitsha9876543210ab';
      const unreachableSha = 'deadbeefdeadbeefdeadbeef';
      final git = _ConfigurableFakeGitService(
        headSha: headSha,
        workingTreeDiff: 'working-tree-patch',
        workingTreeSummary: 'working-tree-summary',
        betweenDiff: 'between-patch',
        betweenSummary: 'between-summary',
      );
      // Mark the sinceCommitSha as unreachable.
      git.isCommitReachableOverride = (sha) => sha != unreachableSha;

      final service = ReviewBundleService(gitService: git);
      final bundle = service.build(temp.path, sinceCommitSha: unreachableSha);

      // Must fall back to working-tree diff.
      expect(bundle.diffPatch, 'working-tree-patch');
      expect(bundle.diffSummary, 'working-tree-summary');
      expect(
        git.diffPatchBetweenCalled,
        isFalse,
        reason:
            'Should not use between-diff when sinceCommitSha is not reachable',
      );
    },
  );

  test(
    'reachable sinceCommitSha != HEAD → still uses between-diff',
    () {
      const headSha = 'newcommitsha9876543210ab';
      const reachableSha = 'oldsha1234567890abcdefgh';
      final git = _ConfigurableFakeGitService(
        headSha: headSha,
        workingTreeDiff: 'working-tree-patch',
        workingTreeSummary: 'working-tree-summary',
        betweenDiff: 'between-patch',
        betweenSummary: 'between-summary',
      );
      // SHA is reachable.
      git.isCommitReachableOverride = (_) => true;

      final service = ReviewBundleService(gitService: git);
      final bundle = service.build(temp.path, sinceCommitSha: reachableSha);

      expect(bundle.diffPatch, 'between-patch');
      expect(
        git.diffPatchBetweenCalled,
        isTrue,
        reason: 'Reachable SHA should use between-diff',
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Configurable fake that tracks which diff methods were called.
// ─────────────────────────────────────────────────────────────────────────────

class _ConfigurableFakeGitService extends FakeGitService {
  _ConfigurableFakeGitService({
    required this.headSha,
    required this.workingTreeDiff,
    required this.workingTreeSummary,
    required this.betweenDiff,
    required this.betweenSummary,
  }) : super(isRepoValue: false);

  final String headSha;
  final String workingTreeDiff;
  final String workingTreeSummary;
  final String betweenDiff;
  final String betweenSummary;

  bool diffPatchCalled = false;
  bool diffPatchBetweenCalled = false;
  String? lastBetweenFromRef;
  String? lastBetweenToRef;

  @override
  String headCommitSha(String path, {bool short = false}) => headSha;

  @override
  String diffPatch(String path) {
    diffPatchCalled = true;
    return workingTreeDiff;
  }

  @override
  String diffSummary(String path) {
    return workingTreeSummary;
  }

  @override
  String diffPatchBetween(String path, String fromRef, String toRef) {
    diffPatchBetweenCalled = true;
    lastBetweenFromRef = fromRef;
    lastBetweenToRef = toRef;
    return betweenDiff;
  }

  @override
  String diffSummaryBetween(String path, String fromRef, String toRef) {
    return betweenSummary;
  }
}
