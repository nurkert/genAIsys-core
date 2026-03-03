import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/contracts/app_error.dart';
import 'package:genaisys/core/app/use_cases/in_process_genaisys_api.dart';

import '../support/test_workspace.dart';

void main() {
  test('getStatus fails when .genaisys is missing', () async {
    final workspace = TestWorkspace.create(prefix: 'genaisys_missing_');
    addTearDown(workspace.dispose);

    final api = InProcessGenaisysApi();
    final result = await api.getStatus(workspace.root.path);
    expect(result.ok, isFalse);
    expect(result.error?.kind, AppErrorKind.preconditionFailed);
    expect(result.error?.message, contains('.genaisys'));
  });

  test('listTasks fails when TASKS.md is missing', () async {
    final workspace = TestWorkspace.create(prefix: 'genaisys_no_tasks_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure();

    final tasksFile = File(workspace.layout.tasksPath);
    if (tasksFile.existsSync()) {
      tasksFile.deleteSync();
    }

    final api = InProcessGenaisysApi();
    final result = await api.listTasks(workspace.root.path);
    expect(result.ok, isFalse);
    expect(result.error?.kind, AppErrorKind.preconditionFailed);
    expect(result.error?.message, contains('TASKS.md'));
  });
}
