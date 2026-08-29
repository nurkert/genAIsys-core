import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test('CLI done --json returns valid JSON payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_done_json_output_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    _initGitRepoWithLocalRemote(temp.path);

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha "Beta"

## Done
''');
    await runner.run(['activate', '--title', 'Alpha "Beta"', temp.path]);

    // Create a committed feature-branch diff so delivery preflight is clean
    // while review evidence contains a non-empty patch.
    _runGit(temp.path, ['checkout', '-b', 'feat/done-json']);
    File('${temp.path}/README.md').writeAsStringSync('# Done JSON Test\n');
    _runGit(temp.path, ['add', '-A']);
    _runGit(temp.path, ['commit', '--no-gpg-sign', '-m', 'feat: done json']);
    _runGit(temp.path, ['push', '-u', 'origin', 'feat/done-json']);
    await runner.run(['review', 'approve', '--note', 'LGTM', temp.path]);

    final result = runLockedDartSync([
      'run',
      '--verbosity=error',
      '--',
      'bin/genaisys_cli.dart',
      'done',
      '--json',
      temp.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString().trim();
    expect(output, isNotEmpty);
    final decoded = jsonDecode(output) as Map<String, dynamic>;
    expect(decoded['done'], true);
    expect(decoded['task_title'], 'Alpha "Beta"');
  });
}

void _runGit(String root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root);
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} failed: ${result.stderr.toString().trim()}',
    );
  }
}

void _initGitRepoWithLocalRemote(String root) {
  _runGit(root, ['init', '-b', 'main']);
  _runGit(root, ['config', 'user.email', 'test@genaisys.local']);
  _runGit(root, ['config', 'user.name', 'Genaisys Test']);
  File('$root/.gitignore').writeAsStringSync('.genaisys/\n.remote.git/\n');
  File('$root/README.md').writeAsStringSync('# Repo\n');
  _runGit(root, ['add', '-A']);
  _runGit(root, ['commit', '--no-gpg-sign', '-m', 'chore: init']);

  _runGit(root, ['init', '--bare', '.remote.git']);
  _runGit(root, ['remote', 'add', 'origin', '$root/.remote.git']);
  _runGit(root, ['push', '-u', 'origin', 'main']);
}
