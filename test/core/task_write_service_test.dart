import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/services/task_management/task_write_service.dart';

import '../support/fixtures.dart';
import '../support/test_workspace.dart';

void main() {
  test('TaskWriteService creates task in target section', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_task_write_');
    addTearDown(workspace.dispose);
    workspace.writeTasks(tasksFixtureTwoSections);

    final service = TaskWriteService();
    final result = service.createTask(
      workspace.root.path,
      title: 'Gamma',
      priority: TaskPriority.p3,
      category: TaskCategory.docs,
      section: 'Backlog',
    );

    final contents = File(workspace.layout.tasksPath).readAsStringSync();
    final backlogIndex = contents.indexOf('## Backlog');
    final gammaIndex = contents.indexOf('Gamma');
    final doingIndex = contents.indexOf('## Doing');

    expect(result.task.title, 'Gamma');
    expect(result.task.section, 'Backlog');
    expect(contents, contains('- [ ] [P3] [DOCS] Gamma'));
    expect(backlogIndex, lessThan(gammaIndex));
    expect(gammaIndex, lessThan(doingIndex));
    _expectNoAtomicTaskLeftovers(workspace.layout.genaisysDir);
  });

  test('TaskWriteService rejects duplicate titles', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_task_dup_');
    addTearDown(workspace.dispose);
    workspace.writeTasks(tasksFixtureBasic);

    final service = TaskWriteService();
    expect(
      () => service.createTask(
        workspace.root.path,
        title: 'Alpha',
        priority: TaskPriority.p2,
        category: TaskCategory.ui,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('TaskWriteService moves task to new section', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_task_move_');
    addTearDown(workspace.dispose);
    workspace.writeTasks(tasksFixtureTwoSections);

    final service = TaskWriteService();
    final result = service.moveSection(
      workspace.root.path,
      title: 'Alpha',
      section: 'Doing',
    );

    final contents = File(workspace.layout.tasksPath).readAsStringSync();
    final backlogIndex = contents.indexOf('## Backlog');
    final doingIndex = contents.indexOf('## Doing');
    final alphaIndex = contents.indexOf('Alpha');

    expect(result.fromSection, 'Backlog');
    expect(result.task.section, 'Doing');
    expect(alphaIndex, greaterThan(doingIndex));
    expect(alphaIndex, greaterThan(backlogIndex));
    _expectNoAtomicTaskLeftovers(workspace.layout.genaisysDir);
  });

  test('TaskWriteService updates task priority', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_task_prio_');
    addTearDown(workspace.dispose);
    workspace.writeTasks(tasksFixtureBasic);

    final service = TaskWriteService();
    final result = service.updatePriority(
      workspace.root.path,
      title: 'Alpha',
      priority: TaskPriority.p3,
    );

    final contents = File(workspace.layout.tasksPath).readAsStringSync();
    expect(result.task.priority, TaskPriority.p3);
    expect(contents, contains('[P3] [CORE] Alpha'));
    _expectNoAtomicTaskLeftovers(workspace.layout.genaisysDir);
  });
}

void _expectNoAtomicTaskLeftovers(String genaisysDir) {
  final leftovers = Directory(genaisysDir).listSync().where((entry) {
    final name = entry.path.split(Platform.pathSeparator).last;
    return name.startsWith('TASKS.md.tmp.') || name.startsWith('TASKS.md.bak.');
  }).toList();
  expect(leftovers, isEmpty);
}
