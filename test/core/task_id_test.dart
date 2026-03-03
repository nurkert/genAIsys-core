import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('Task id is stable slug with line index', () {
    final task = Task(
      title: 'Hello World!',
      priority: TaskPriority.p1,
      category: TaskCategory.core,
      completion: TaskCompletion.open,
      section: 'Backlog',
      lineIndex: 7,
    );

    expect(task.id, 'hello-world-7');
  });
}
