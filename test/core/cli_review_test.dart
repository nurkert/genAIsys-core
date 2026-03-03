import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI review approve sets review status', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_review_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'Alpha')));

    await runner.run(['review', 'approve', temp.path]);

    final updated = stateStore.read();
    expect(updated.reviewStatus, 'approved');
  });

  test('CLI review reject sets review status', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_reject_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'Alpha')));

    await runner.run(['review', 'reject', temp.path]);

    final updated = stateStore.read();
    expect(updated.reviewStatus, 'rejected');
  });
}
