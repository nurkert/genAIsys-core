import 'package:test/test.dart';

import 'package:genaisys/core/services/meta_task_service.dart';
import 'package:genaisys/core/storage/task_store.dart';

import '../support/test_workspace.dart';

void main() {
  test('MetaTaskService creates meta tasks when missing', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_meta_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure();

    final service = MetaTaskService();
    final result = service.ensureMetaTasks(workspace.root.path);

    expect(result.created, 3);
    final tasks = TaskStore(workspace.layout.tasksPath).readTasks();
    expect(
      tasks.any(
        (task) => task.title.startsWith('Refine core agent system prompt'),
      ),
      isTrue,
    );
  });
}
