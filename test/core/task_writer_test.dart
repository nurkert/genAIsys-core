import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('TaskWriter marks task done and blocked', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_writer_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final tasksPath = '${temp.path}${Platform.pathSeparator}TASKS.md';
    File(tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final tasks = TaskStore(tasksPath).readTasks();
    final task = tasks.first;

    final writer = TaskWriter(tasksPath);
    final done = writer.markDone(task);
    expect(done, isTrue);

    final updatedDone = File(tasksPath).readAsStringSync();
    expect(updatedDone, contains('- [x] [P1] [CORE] Alpha'));

    final blocked = writer.markBlocked(task, reason: 'Needs input');
    expect(blocked, isTrue);

    final updatedBlocked = File(tasksPath).readAsStringSync();
    expect(updatedBlocked, contains('[BLOCKED]'));
    expect(updatedBlocked, contains('Reason: Needs input'));

    final leftovers = temp.listSync().where((entry) {
      final name = entry.path.split(Platform.pathSeparator).last;
      return name.startsWith('TASKS.md.tmp.') ||
          name.startsWith('TASKS.md.bak.');
    }).toList();
    expect(leftovers, isEmpty);
  });
}
