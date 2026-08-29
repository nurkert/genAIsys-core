import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('TaskSorter orders by priority then line index', () {
    final tasks = [
      Task(
        title: 'P2',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 5,
      ),
      Task(
        title: 'P1',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 10,
      ),
      Task(
        title: 'P1 earlier',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 2,
      ),
    ];

    final sorted = TaskSorter().byPriorityThenLine(tasks);

    expect(sorted.first.title, 'P1 earlier');
    expect(sorted[1].title, 'P1');
    expect(sorted[2].title, 'P2');
  });
}
