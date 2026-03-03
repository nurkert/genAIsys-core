import 'package:test/test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('TaskFilters blockedOnly returns only blocked tasks', () {
    final tasks = [
      Task(
        title: 'Open',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        blocked: false,
        section: 'Backlog',
        lineIndex: 1,
      ),
      Task(
        title: 'Blocked',
        priority: TaskPriority.p2,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        blocked: true,
        section: 'Backlog',
        lineIndex: 2,
      ),
    ];

    final filtered = const TaskFilters().blockedOnly(tasks);

    expect(filtered.length, 1);
    expect(filtered.first.title, 'Blocked');
  });
}
