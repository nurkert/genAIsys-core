import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI deactivate keeps review when requested', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_deactivate_keep_review_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: ActiveTaskState(
          title: 'Alpha',
          reviewStatus: 'approved',
          reviewUpdatedAt: '2026-02-03T00:00:00Z',
        ),
      ),
    );

    await runner.run(['deactivate', '--keep-review', temp.path]);

    final updated = stateStore.read();
    expect(updated.activeTaskTitle, isNull);
    expect(updated.reviewStatus, 'approved');
    expect(updated.reviewUpdatedAt, '2026-02-03T00:00:00Z');
  });
}
