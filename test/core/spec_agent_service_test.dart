import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/templates/default_files.dart';

void main() {
  test('SpecAgentService writes agent output to spec file', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_spec_agent_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.tasksPath).writeAsStringSync(DefaultFiles.tasks());

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: const ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('Spec output');
    final service = SpecAgentService(agentService: agentService);

    final result = await service.generate(
      temp.path,
      kind: SpecKind.spec,
      overwrite: true,
    );

    expect(result.wrote, isTrue);
    final content = File(result.path).readAsStringSync();
    expect(content, 'Spec output');
  });

  test('SpecAgentService reorders subtasks by dependencies', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_spec_agent_subtask_deps_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.tasksPath).writeAsStringSync(DefaultFiles.tasks());

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: const ActiveTaskState(title: 'My Task')));

    final service = SpecAgentService(
      agentService: _FakeAgentService('''
# Subtasks

## Subtasks
1. Run integration checks for the service (depends on: 2)
2. Implement service command execution audit pipeline
3. Update user-facing docs for execution flow (depends on: 2)
'''),
    );

    await service.generate(temp.path, kind: SpecKind.subtasks, overwrite: true);

    final state = StateStore(layout.statePath).read();
    expect(
      state.subtaskQueue,
      equals([
        'Implement service command execution audit pipeline',
        'Run integration checks for the service',
        'Update user-facing docs for execution flow',
      ]),
    );
  });

  test(
    'SpecAgentService preserves numeric subtask order when only later items start with action verbs',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_spec_agent_subtask_order_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
      File(layout.tasksPath).writeAsStringSync(DefaultFiles.tasks());

      final stateStore = StateStore(layout.statePath);
      stateStore.write(stateStore.read().copyWith(activeTask: const ActiveTaskState(title: 'My Task')));

      final service = SpecAgentService(
        agentService: _FakeAgentService('''
# Subtasks

## Subtasks
1. Baseline and contract lock: add/adjust unit tests that assert current config behavior.
2. Extract schema module: create schema file and preserve serialization boundaries.
3. Verify and gate: run analyze and full tests.
'''),
      );

      await service.generate(
        temp.path,
        kind: SpecKind.subtasks,
        overwrite: true,
      );

      final state = StateStore(layout.statePath).read();
      expect(
        state.subtaskQueue,
        equals([
          'Baseline and contract lock: add/adjust unit tests that assert current config behavior',
          'Extract schema module: create schema file and preserve serialization boundaries',
          'Verify and gate: run analyze and full tests',
        ]),
      );
    },
  );

  test('SpecAgentService filters low-quality and duplicate subtasks', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_spec_agent_subtask_quality_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.tasksPath).writeAsStringSync(DefaultFiles.tasks());

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: const ActiveTaskState(title: 'My Task')));

    final service = SpecAgentService(
      agentService: _FakeAgentService('''
# Subtasks

## Subtasks
1. TODO
2. Add command audit storage wiring for autopilot events.
3. Write integration test coverage for audit storage wiring.
4. Update run telemetry docs for command audit visibility.
5. Add command audit storage wiring for autopilot events.
'''),
    );

    await service.generate(temp.path, kind: SpecKind.subtasks, overwrite: true);

    final state = StateStore(layout.statePath).read();
    expect(
      state.subtaskQueue,
      equals([
        'Add command audit storage wiring for autopilot events',
        'Write integration test coverage for audit storage wiring',
        'Update run telemetry docs for command audit visibility',
      ]),
    );
  });
}

class _FakeAgentService extends AgentService {
  _FakeAgentService(this.output);

  final String output;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    return AgentServiceResult(
      response: AgentResponse(exitCode: 0, stdout: output, stderr: ''),
      usedFallback: false,
    );
  }
}
