import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/git/git_service.dart';

/// Helper to initialize a temp git repo with gpg signing disabled.
void _initRepo(String path, {String branch = 'main'}) {
  Process.runSync('git', ['init', '-b', branch], workingDirectory: path);
  Process.runSync('git', [
    'config',
    'commit.gpgsign',
    'false',
  ], workingDirectory: path);
  Process.runSync('git', [
    'config',
    'user.email',
    'test@test.com',
  ], workingDirectory: path);
  Process.runSync('git', [
    'config',
    'user.name',
    'Test',
  ], workingDirectory: path);
}

void main() {
  group('GitService.discardWorkingChanges', () {
    test('checkout and clean leave a clean worktree', () {
      final temp = Directory.systemTemp.createTempSync('genaisys_discard_');
      addTearDown(() => temp.deleteSync(recursive: true));

      _initRepo(temp.path);
      Process.runSync('git', [
        'commit',
        '--allow-empty',
        '-m',
        'init',
      ], workingDirectory: temp.path);

      // Create dirty state.
      File('${temp.path}/dirty.txt').writeAsStringSync('dirty');

      final git = GitService();
      expect(git.hasChanges(temp.path), isTrue);

      git.discardWorkingChanges(temp.path);

      expect(git.isClean(temp.path), isTrue);
      expect(File('${temp.path}/dirty.txt').existsSync(), isFalse);
    });
  });

  group('GitService.diffStatsBetween', () {
    test('returns diff stats between two refs', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_diff_between_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      _initRepo(temp.path);
      Process.runSync('git', [
        'commit',
        '--allow-empty',
        '-m',
        'init',
      ], workingDirectory: temp.path);

      // Create a feature branch with changes.
      Process.runSync('git', [
        'checkout',
        '-b',
        'feat/test',
      ], workingDirectory: temp.path);
      File('${temp.path}/new_file.dart').writeAsStringSync('void main() {}\n');
      Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
      Process.runSync('git', [
        'commit',
        '-m',
        'add file',
      ], workingDirectory: temp.path);

      final git = GitService();
      final stats = git.diffStatsBetween(temp.path, 'main', 'feat/test');

      expect(stats.filesChanged, 1);
      expect(stats.additions, 1);
      expect(stats.deletions, 0);
    });
  });

  group('Diff budget at commit time config', () {
    test('reviewRequireEvidence defaults to true', () {
      // ProjectConfig default check.
      expect(ProjectConfig.defaultReviewRequireEvidence, isTrue);
    });
  });
}
