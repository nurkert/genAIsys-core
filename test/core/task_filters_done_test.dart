import 'package:test/test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('TaskFilters doneOnly returns only done tasks', () {
    final tasks = [
      Task(
        title: 'Open',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      ),
      Task(
        title: 'Done',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.done,
        section: 'Backlog',
        lineIndex: 2,
      ),
    ];

    final filtered = const TaskFilters().doneOnly(tasks);

    expect(filtered.length, 1);
    expect(filtered.first.title, 'Done');
  });
}
