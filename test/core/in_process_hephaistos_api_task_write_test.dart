import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/project_layout.dart';

void _writeTasks(ProjectLayout layout, String content) {
  Directory(layout.genaisysDir).createSync(recursive: true);
  File(layout.tasksPath).writeAsStringSync(content);
}

void main() {
  test('createTask returns created task DTO', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_api_create_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    _writeTasks(layout, '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final api = InProcessGenaisysApi();
    final result = await api.createTask(
      temp.path,
      title: 'Gamma',
      priority: AppTaskPriority.p3,
      category: AppTaskCategory.docs,
      section: 'Backlog',
    );

    expect(result.ok, isTrue);
    expect(result.data, isNotNull);
    expect(result.data!.created, isTrue);
    expect(result.data!.task.title, 'Gamma');
    expect(result.data!.task.section, 'Backlog');
    expect(result.data!.task.priority, 'p3');
    expect(result.data!.task.category, 'docs');
  });

  test('createTask duplicate title maps to conflict', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_api_dup_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    _writeTasks(layout, '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final api = InProcessGenaisysApi();
    final result = await api.createTask(
      temp.path,
      title: 'Alpha',
      priority: AppTaskPriority.p2,
      category: AppTaskCategory.ui,
    );

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.conflict);
  });

  test('updateTaskPriority requires id or title', () async {
    final api = InProcessGenaisysApi();
    final result = await api.updateTaskPriority(
      '/tmp/project',
      priority: AppTaskPriority.p1,
    );

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.invalidInput);
  });

  test('updateTaskPriority maps not found to AppErrorKind.notFound', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_api_prio_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    _writeTasks(layout, '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final api = InProcessGenaisysApi();
    final result = await api.updateTaskPriority(
      temp.path,
      title: 'Missing',
      priority: AppTaskPriority.p2,
    );

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.notFound);
  });

  test('updateTaskPriority updates priority', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_api_prio_ok_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    _writeTasks(layout, '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final api = InProcessGenaisysApi();
    final result = await api.updateTaskPriority(
      temp.path,
      title: 'Alpha',
      priority: AppTaskPriority.p2,
    );

    expect(result.ok, isTrue);
    expect(result.data, isNotNull);
    expect(result.data!.updated, isTrue);
    expect(result.data!.task.priority, 'p2');
  });

  test('moveTaskSection requires id or title', () async {
    final api = InProcessGenaisysApi();
    final result = await api.moveTaskSection('/tmp/project', section: 'Doing');

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.invalidInput);
  });

  test('moveTaskSection requires non-empty section', () async {
    final api = InProcessGenaisysApi();
    final result = await api.moveTaskSection(
      '/tmp/project',
      title: 'Alpha',
      section: '  ',
    );

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.invalidInput);
  });

  test('moveTaskSection maps not found to AppErrorKind.notFound', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_api_move_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    _writeTasks(layout, '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final api = InProcessGenaisysApi();
    final result = await api.moveTaskSection(
      temp.path,
      title: 'Missing',
      section: 'Doing',
    );

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.notFound);
  });

  test('moveTaskSection moves task and returns dto', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_api_move_ok_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    _writeTasks(layout, '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''');

    final api = InProcessGenaisysApi();
    final result = await api.moveTaskSection(
      temp.path,
      title: 'Alpha',
      section: 'Doing',
    );

    expect(result.ok, isTrue);
    expect(result.data, isNotNull);
    expect(result.data!.moved, isTrue);
    expect(result.data!.fromSection, 'Backlog');
    expect(result.data!.toSection, 'Doing');
  });
}
