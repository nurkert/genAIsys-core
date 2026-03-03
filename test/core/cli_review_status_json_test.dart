import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('CLI review status supports json output', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_status_json_',
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
        activeTask: stateStore.read().activeTask.copyWith(
          reviewStatus: 'approved',
          reviewUpdatedAt: '2026-02-03T00:00:00Z',
        ),
      ),
    );

    exitCode = 0;
    await runner.run(['review', 'status', '--json', temp.path]);

    expect(exitCode, 0);
  });
}
