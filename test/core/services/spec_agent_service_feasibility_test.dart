import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;
  late StateStore stateStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_feasibility_test_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
    stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: const ActiveTaskState(
          title: 'Add feature — AC: must pass linting and tests',
          id: 'task-1',
        ),
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  void setQueue(List<String> queue) {
    stateStore.write(
      stateStore.read().copyWith(
        subtaskExecution: SubtaskExecutionState(queue: queue),
      ),
    );
  }

  test(
    'checkFeasibility returns skipped when feasibilityCheckDone is already true',
    () async {
      setQueue(['Add model', 'Add tests']);
      stateStore.write(
        stateStore.read().copyWith(
          subtaskExecution: stateStore
              .read()
              .subtaskExecution
              .copyWith(feasibilityCheckDone: true),
        ),
      );

      var agentCalled = false;
      final service = SpecAgentService(
        agentService: _RecordingAgentService(
          responses: ['FEASIBLE'],
          onCall: () => agentCalled = true,
        ),
      );

      final result = await service.checkFeasibility(temp.path);

      expect(result.skipped, isTrue);
      expect(result.feasible, isTrue);
      expect(agentCalled, isFalse);
    },
  );

  test(
    'checkFeasibility returns feasible: true and marks done when agent says FEASIBLE',
    () async {
      setQueue(['Add model', 'Add service', 'Add tests']);

      final service = SpecAgentService(
        agentService: _RecordingAgentService(
          responses: ['FEASIBLE\nAll subtasks look good.'],
        ),
      );

      final result = await service.checkFeasibility(temp.path);

      expect(result.feasible, isTrue);
      expect(result.skipped, isFalse);
      expect(result.regenerated, isFalse);

      final state = stateStore.read();
      expect(state.subtaskExecution.feasibilityCheckDone, isTrue);
    },
  );

  test(
    'checkFeasibility returns feasible: false, regenerated: true on NOT_FEASIBLE',
    () async {
      setQueue(['Partially add model']);

      // Two agent calls: feasibility check + subtask regeneration.
      final service = SpecAgentService(
        agentService: _RecordingAgentService(
          responses: [
            // First call: feasibility verdict.
            'NOT_FEASIBLE\nMissing test coverage subtask.',
            // Second call: subtask regeneration (generate() with overwrite).
            '## Subtasks\n'
                '1. Add model layer for the feature\n'
                '2. Add service wiring for the model\n'
                '3. Add test coverage for the service',
          ],
        ),
      );

      final result = await service.checkFeasibility(temp.path);

      expect(result.feasible, isFalse);
      expect(result.regenerated, isTrue);
      expect(result.explanation, contains('Missing test coverage'));

      final state = stateStore.read();
      expect(state.subtaskExecution.feasibilityCheckDone, isTrue);
    },
  );

  test(
    'checkFeasibility marks done and returns skipped when agent fails',
    () async {
      setQueue(['Add model']);

      final service = SpecAgentService(
        agentService: _RecordingAgentService(
          exitCode: 1,
          responses: [''],
        ),
      );

      final result = await service.checkFeasibility(temp.path);

      expect(result.skipped, isTrue);
      expect(stateStore.read().subtaskExecution.feasibilityCheckDone, isTrue);
    },
  );

  test(
    'checkFeasibility returns skipped when queue is empty',
    () async {
      // Queue is empty — no subtasks to check.
      setQueue([]);

      var agentCalled = false;
      final service = SpecAgentService(
        agentService: _RecordingAgentService(
          responses: ['FEASIBLE'],
          onCall: () => agentCalled = true,
        ),
      );

      final result = await service.checkFeasibility(temp.path);

      expect(result.skipped, isTrue);
      expect(result.feasible, isTrue);
      expect(agentCalled, isFalse);
    },
  );

  test(
    'checkFeasibility does not call agent a second time after NOT_FEASIBLE + regeneration',
    () async {
      setQueue(['Partially add model']);

      var callCount = 0;
      final service = SpecAgentService(
        agentService: _RecordingAgentService(
          responses: [
            'NOT_FEASIBLE\nMissing subtask.',
            '## Subtasks\n1. Add model\n2. Add service\n3. Add tests',
          ],
          onCall: () => callCount++,
        ),
      );

      // First call triggers feasibility check + regeneration (2 agent calls).
      await service.checkFeasibility(temp.path);
      final callsAfterFirst = callCount;

      // Second call must be skipped (feasibilityCheckDone = true).
      await service.checkFeasibility(temp.path);

      expect(callCount, equals(callsAfterFirst)); // No additional agent calls.
      expect(stateStore.read().subtaskExecution.feasibilityCheckDone, isTrue);
    },
  );
}

/// Agent service that returns responses in sequence.
class _RecordingAgentService extends AgentService {
  _RecordingAgentService({
    required this.responses,
    this.exitCode = 0,
    this.onCall,
  });

  final List<String> responses;
  final int exitCode;
  final void Function()? onCall;
  int _index = 0;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    onCall?.call();
    final output =
        _index < responses.length ? responses[_index] : responses.last;
    _index++;
    return AgentServiceResult(
      response: AgentResponse(exitCode: exitCode, stdout: output, stderr: ''),
      usedFallback: false,
    );
  }
}
