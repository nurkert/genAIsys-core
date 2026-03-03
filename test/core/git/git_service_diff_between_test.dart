import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/git/git_service.dart';

// ---------------------------------------------------------------------------
// Feature D: GitService.diffPatchBetween / diffSummaryBetween integration tests
//
// These tests create a REAL temporary git repository with two commits and
// verify the output of the new between-diff methods.  The repo is fully
// self-contained inside a temp directory and is removed after each test.
// ---------------------------------------------------------------------------

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_git_diff_between_');
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  /// Run a git command in [dir] and return stdout.  Throws if the command
  /// fails.
  String git(String dir, List<String> args) {
    final result = Process.runSync(
      'git',
      args,
      workingDirectory: dir,
      environment: {
        ...Platform.environment,
        // Avoid user-level hooks and GPG signing that would fail in CI.
        'GIT_CONFIG_NOSYSTEM': '1',
        'HOME': dir, // isolate .gitconfig
      },
    );
    if (result.exitCode != 0) {
      throw StateError(
        'git ${args.join(' ')} failed in $dir:\n${result.stderr}',
      );
    }
    return result.stdout.toString().trim();
  }

  /// Creates a minimal git repo with two commits.
  ///
  /// Returns the SHA of the FIRST commit (sha1) — diffing sha1..HEAD should
  /// show only the changes from the second commit.
  String createTwoCommitRepo(String dir) {
    git(dir, ['init']);
    git(dir, ['config', 'user.email', 'test@genaisys.test']);
    git(dir, ['config', 'user.name', 'Genaisys Test']);
    git(dir, ['config', 'commit.gpgsign', 'false']);

    // First commit: add alpha.txt
    File('$dir/alpha.txt').writeAsStringSync('Hello from alpha\n');
    git(dir, ['add', 'alpha.txt']);
    git(dir, ['commit', '-m', 'Add alpha.txt']);
    final sha1 = git(dir, ['rev-parse', 'HEAD']);

    // Second commit: modify alpha.txt + add beta.txt
    File('$dir/alpha.txt').writeAsStringSync('Updated alpha content\n');
    File('$dir/beta.txt').writeAsStringSync('Hello from beta\n');
    git(dir, ['add', '.']);
    git(dir, ['commit', '-m', 'Add beta, update alpha']);

    return sha1; // SHA of the first commit
  }

  test(
    'diffPatchBetween returns the delta between two commits',
    () {
      final sha1 = createTwoCommitRepo(temp.path);
      final service = GitService();

      final patch = service.diffPatchBetween(temp.path, sha1, 'HEAD');

      // The delta should show changes to alpha.txt and addition of beta.txt.
      expect(patch, isNotEmpty, reason: 'Patch should not be empty');
      expect(patch, contains('alpha.txt'),
          reason: 'Patch should include the modified alpha.txt');
      expect(patch, contains('beta.txt'),
          reason: 'Patch should include the new beta.txt');
      expect(patch, contains('Updated alpha content'),
          reason: 'Patch should show the new content of alpha.txt');
      // The original first-commit content should appear as deleted lines.
      expect(patch, contains('Hello from alpha'),
          reason: 'Patch should show the removed line from alpha.txt');
    },
  );

  test(
    'diffSummaryBetween returns a stat summary between two commits',
    () {
      final sha1 = createTwoCommitRepo(temp.path);
      final service = GitService();

      final summary = service.diffSummaryBetween(temp.path, sha1, 'HEAD');

      // `git diff --stat sha1..HEAD` should produce a short summary.
      expect(summary, isNotEmpty, reason: 'Summary should not be empty');
      // The summary should mention files changed.
      expect(summary, contains('changed'),
          reason: 'Stat summary should contain the word "changed"');
    },
  );

  test(
    'diffPatchBetween with identical refs returns empty string',
    () {
      createTwoCommitRepo(temp.path);
      final service = GitService();
      final headSha = git(temp.path, ['rev-parse', 'HEAD']);

      // Diff HEAD..HEAD should show no changes.
      final patch = service.diffPatchBetween(temp.path, headSha, 'HEAD');

      expect(patch.trim(), isEmpty,
          reason: 'Diffing a ref against itself should produce no output');
    },
  );

  test(
    'diffSummaryBetween with identical refs returns empty string',
    () {
      createTwoCommitRepo(temp.path);
      final service = GitService();
      final headSha = git(temp.path, ['rev-parse', 'HEAD']);

      final summary = service.diffSummaryBetween(temp.path, headSha, 'HEAD');

      expect(summary.trim(), isEmpty,
          reason: 'Summary of identical refs should be empty');
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Fix 2: isCommitReachable
  // ─────────────────────────────────────────────────────────────────────

  test(
    'isCommitReachable returns true for a valid commit SHA',
    () {
      final sha1 = createTwoCommitRepo(temp.path);
      final service = GitService();

      expect(service.isCommitReachable(temp.path, sha1), isTrue,
          reason: 'A real commit SHA must be reported as reachable');
    },
  );

  test(
    'isCommitReachable returns false for a fake SHA',
    () {
      createTwoCommitRepo(temp.path);
      final service = GitService();

      expect(
        service.isCommitReachable(temp.path, 'deadbeefdeadbeefdeadbeef'),
        isFalse,
        reason: 'A non-existent SHA must be reported as unreachable',
      );
    },
  );

  test(
    'isCommitReachable returns false for an empty SHA',
    () {
      createTwoCommitRepo(temp.path);
      final service = GitService();

      expect(service.isCommitReachable(temp.path, ''), isFalse,
          reason: 'An empty SHA must be reported as unreachable');
    },
  );
}
