import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/ids/task_slugger.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/review_bundle_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test(
    'ReviewBundleService decorates spec with subtask review mode when currentSubtask is set',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_bundle_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      const title = 'Task title';
      const subtask = 'Do the thing in `lib/core/foo.dart`.';
      StateStore(layout.statePath).write(
        StateStore(
          layout.statePath,
        ).read().copyWith(
          activeTask: ActiveTaskState(title: title),
          subtaskExecution: SubtaskExecutionState(current: subtask),
        ),
      );

      Directory(layout.taskSpecsDir).createSync(recursive: true);
      final specPath = '${layout.taskSpecsDir}/${TaskSlugger.slug(title)}.md';
      File(specPath).writeAsStringSync('''
# Task Spec
Title: $title
''');

      final service = ReviewBundleService(
        gitService: GitServiceImpl(processRunner: _noopGit),
      );
      final bundle = service.build(temp.path, testSummary: 'ok');

      expect(bundle.spec, isNotNull);
      expect(bundle.spec, contains('Subtask Review Mode (Required)'));
      expect(bundle.spec, contains(subtask));
      expect(bundle.spec, contains('# Task Spec'));
    },
  );

  test(
    'ReviewBundleService returns raw spec when no currentSubtask is set',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_bundle_raw_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      const title = 'Task title';
      StateStore(layout.statePath).write(
        StateStore(layout.statePath).read().copyWith(
          activeTask: ActiveTaskState(title: title),
        ),
      );

      Directory(layout.taskSpecsDir).createSync(recursive: true);
      final specPath = '${layout.taskSpecsDir}/${TaskSlugger.slug(title)}.md';
      File(specPath).writeAsStringSync('SPECMARK');

      final service = ReviewBundleService(
        gitService: GitServiceImpl(processRunner: _noopGit),
      );
      final bundle = service.build(temp.path, testSummary: 'ok');

      expect(bundle.spec, 'SPECMARK');
    },
  );
}

ProcessResult _noopGit(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell = false,
  Map<String, String>? environment,
}) {
  return ProcessResult(0, 0, '', '');
}
