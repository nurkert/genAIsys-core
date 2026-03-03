import 'package:test/test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('TaskFilters sectionOnly matches section title case-insensitively', () {
    final tasks = [
      Task(
        title: 'A',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Backlog',
        lineIndex: 1,
      ),
      Task(
        title: 'B',
        priority: TaskPriority.p1,
        category: TaskCategory.core,
        completion: TaskCompletion.open,
        section: 'Review',
        lineIndex: 2,
      ),
    ];

    final filtered = const TaskFilters().sectionOnly(tasks, 'backlog');

    expect(filtered.length, 1);
    expect(filtered.first.title, 'A');
  });
}
