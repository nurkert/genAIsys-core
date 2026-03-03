import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('StateStore writes state without leaving temp or backup files', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_state_store_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final statePath =
        '${temp.path}${Platform.pathSeparator}.genaisys${Platform.pathSeparator}STATE.json';
    final store = StateStore(statePath);

    store.write(store.read().copyWith(activeTask: const ActiveTaskState(title: 'Initial')));
    store.write(store.read().copyWith(activeTask: const ActiveTaskState(title: 'Updated')));

    final state = store.read();
    expect(state.activeTaskTitle, 'Updated');

    final leftovers =
        Directory(
          '${temp.path}${Platform.pathSeparator}.genaisys',
        ).listSync().where((entry) {
          final name = entry.path.split(Platform.pathSeparator).last;
          return name.startsWith('STATE.json.tmp.') ||
              name.startsWith('STATE.json.bak.');
        }).toList();
    expect(leftovers, isEmpty);
  });
}
