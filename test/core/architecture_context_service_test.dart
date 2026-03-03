import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/architecture_context_service.dart';
import 'package:genaisys/core/templates/default_files.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_arch_ctx_');
    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    Directory(layout.agentContextsDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

    // Initialize a git repo so recent changes can be queried.
    Process.runSync('git', ['init'], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgSign',
      'false',
    ], workingDirectory: temp.path);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  test('assembly includes dart file paths from lib/', () {
    final libDir = Directory('${temp.path}/lib/core');
    libDir.createSync(recursive: true);
    File('${temp.path}/lib/core/service.dart').writeAsStringSync('// svc');
    File('${temp.path}/lib/app.dart').writeAsStringSync('// app');

    final service = ArchitectureContextService();
    final result = service.assemble(temp.path);

    expect(result, contains('lib/core/service.dart'));
    expect(result, contains('lib/app.dart'));
    expect(result, contains('### Project Structure'));
  });

  test('assembly is trimmed to maxChars', () {
    final libDir = Directory('${temp.path}/lib');
    libDir.createSync(recursive: true);
    // Create many files to exceed a small maxChars.
    for (var i = 0; i < 50; i++) {
      File('${temp.path}/lib/file_$i.dart').writeAsStringSync('// f$i');
    }

    final service = ArchitectureContextService();
    final result = service.assemble(temp.path, maxChars: 200);

    expect(result.length, lessThanOrEqualTo(200));
  });

  test('assembly handles missing architecture.md gracefully', () {
    final libDir = Directory('${temp.path}/lib');
    libDir.createSync(recursive: true);
    File('${temp.path}/lib/main.dart').writeAsStringSync('// main');

    final service = ArchitectureContextService();
    final result = service.assemble(temp.path);

    expect(result, contains('### Project Structure'));
    // Should not throw or contain errors.
    expect(result, isNotEmpty);
  });

  test('assembly includes architecture.md content when present', () {
    final libDir = Directory('${temp.path}/lib');
    libDir.createSync(recursive: true);
    File('${temp.path}/lib/main.dart').writeAsStringSync('// main');

    final layout = ProjectLayout(temp.path);
    File(
      '${layout.agentContextsDir}/architecture.md',
    ).writeAsStringSync('Use repository pattern for data access.');

    final service = ArchitectureContextService();
    final result = service.assemble(temp.path);

    expect(result, contains('### Architecture Rules'));
    expect(result, contains('repository pattern'));
  });

  test('assembly includes RULES.md content when present', () {
    final libDir = Directory('${temp.path}/lib');
    libDir.createSync(recursive: true);
    File('${temp.path}/lib/main.dart').writeAsStringSync('// main');

    final layout = ProjectLayout(temp.path);
    File(layout.rulesPath).writeAsStringSync('No dynamic types allowed.');

    final service = ArchitectureContextService();
    final result = service.assemble(temp.path);

    expect(result, contains('No dynamic types'));
  });

  test('assembly includes recent git commits', () {
    final libDir = Directory('${temp.path}/lib');
    libDir.createSync(recursive: true);
    File('${temp.path}/lib/main.dart').writeAsStringSync('// main');

    // Create a commit so git log has output.
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commitResult = Process.runSync('git', [
      'commit',
      '--no-gpg-sign',
      '-m',
      'initial commit',
    ], workingDirectory: temp.path);

    // Skip test if commit fails (e.g. no git identity configured).
    if (commitResult.exitCode != 0) {
      markTestSkipped('git commit failed: ${commitResult.stderr}');
      return;
    }

    final service = ArchitectureContextService();
    final result = service.assemble(temp.path);

    expect(result, contains('### Recent Changes'));
    expect(result, contains('initial commit'));
  });

  test('empty repo produces valid output without throwing', () {
    // No lib/, no rules, no commits → should still return something (may be empty).
    final service = ArchitectureContextService();
    final result = service.assemble(temp.path);

    // Should not throw. May be empty if nothing is available.
    expect(result, isA<String>());
  });
}
