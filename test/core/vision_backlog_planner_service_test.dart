import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/vision_backlog_planner_service.dart';

void main() {
  test('VisionBacklogPlannerService seeds backlog from vision bullets', () {
    final root = _setupProject();
    final layout = ProjectLayout(root);
    File(layout.visionPath).writeAsStringSync('''
# Vision

## Goals
- Add engine-native orchestrator loop
- Enforce safety policies in task cycle
- Improve reliability for long running sessions
''');

    final result = VisionBacklogPlannerService().syncBacklogFromVision(
      root,
      minOpenTasks: 4,
      maxAdd: 2,
    );

    expect(result.openBefore, 1);
    expect(result.added, 2);
    expect(result.openAfter, 3);
    final tasksContent = File(layout.tasksPath).readAsStringSync();
    expect(tasksContent, contains('Add engine-native orchestrator loop'));
    expect(tasksContent, contains('Enforce safety policies in task cycle'));
    expect(tasksContent, contains('| AC:'));
  });

  test('VisionBacklogPlannerService does not add duplicates', () {
    final root = _setupProject();
    final layout = ProjectLayout(root);
    File(layout.visionPath).writeAsStringSync('''
# Vision

## Goals
- Bootstrap Genaisys core engine
- Bootstrap Genaisys core engine
''');

    final result = VisionBacklogPlannerService().syncBacklogFromVision(
      root,
      minOpenTasks: 3,
      maxAdd: 3,
    );

    expect(result.added, 0);
    final lines = File(layout.tasksPath).readAsLinesSync();
    final matches = lines
        .where((line) => line.contains('Bootstrap Genaisys core engine'))
        .length;
    expect(matches, 1);
  });
}

String _setupProject() {
  final temp = Directory.systemTemp.createTempSync('genaisys_planner_');
  ProjectInitializer(temp.path).ensureStructure(overwrite: true);
  return temp.path;
}
