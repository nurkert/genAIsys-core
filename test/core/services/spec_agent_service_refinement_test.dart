import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    temp = Directory.systemTemp.createTempSync('genaisys_refinement_test_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
    stateStore = StateStore(layout.statePath);
    stateStore.write(
      stateStore.read().copyWith(
        activeTask: const ActiveTaskState(title: 'My Task', id: 'task-1'),
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
    'maybeRefineSubtasks skips when refinementDone is already true',
    () async {
      setQueue(['Add model', 'Add service', 'Add tests']);
      stateStore.write(
        stateStore.read().copyWith(
          subtaskExecution: stateStore
              .read()
              .subtaskExecution
              .copyWith(refinementDone: true),
        ),
      );

      var agentCalled = false;
      final service = SpecAgentService(
        agentService: _CallTrackingAgentService(
          onRun: (_) {
            agentCalled = true;
            return 'REFINED: NO_CHANGES_NEEDED';
          },
        ),
      );

      await service.maybeRefineSubtasks(temp.path);

      expect(agentCalled, isFalse);
      // Queue unchanged.
      expect(stateStore.read().subtaskQueue.length, 3);
    },
  );

  test(
    'maybeRefineSubtasks skips when queue is empty',
    () async {
      setQueue([]);

      var agentCalled = false;
      final service = SpecAgentService(
        agentService: _CallTrackingAgentService(
          onRun: (_) {
            agentCalled = true;
            return 'REFINED: NO_CHANGES_NEEDED';
          },
        ),
      );

      await service.maybeRefineSubtasks(temp.path);

      expect(agentCalled, isFalse);
      // refinementDone stays false — nothing to refine.
      expect(
        stateStore.read().subtaskExecution.refinementDone,
        isFalse,
      );
    },
  );

  test(
    'maybeRefineSubtasks marks done and keeps queue when agent returns NO_CHANGES_NEEDED',
    () async {
      setQueue(['Add model', 'Add service', 'Add tests']);

      final service = SpecAgentService(
        agentService: _CallTrackingAgentService(
          onRun: (_) => 'REFINED: NO_CHANGES_NEEDED',
        ),
      );

      await service.maybeRefineSubtasks(temp.path);

      final state = stateStore.read();
      expect(state.subtaskExecution.refinementDone, isTrue);
      // Queue must be unchanged.
      expect(state.subtaskQueue, ['Add model', 'Add service', 'Add tests']);
    },
  );

  test(
    'maybeRefineSubtasks updates queue from revised list when agent splits subtasks',
    () async {
      setQueue(['Implement huge feature touching 10 files and many modules']);

      final service = SpecAgentService(
        agentService: _CallTrackingAgentService(
          onRun: (_) =>
              '1. Add model layer for the feature\n'
              '2. Wire service logic to model\n'
              '3. Add view layer and tests',
        ),
      );

      await service.maybeRefineSubtasks(temp.path);

      final state = stateStore.read();
      expect(state.subtaskExecution.refinementDone, isTrue);
      expect(state.subtaskQueue, [
        'Add model layer for the feature',
        'Wire service logic to model',
        'Add view layer and tests',
      ]);
    },
  );

  test(
    'maybeRefineSubtasks marks done and keeps queue when agent response cannot be parsed',
    () async {
      setQueue(['Add model', 'Add service']);

      final service = SpecAgentService(
        agentService: _CallTrackingAgentService(
          onRun: (_) => 'Some unexpected output without numbered list',
        ),
      );

      await service.maybeRefineSubtasks(temp.path);

      final state = stateStore.read();
      // refinementDone set to avoid retry loops.
      expect(state.subtaskExecution.refinementDone, isTrue);
      // Queue is unchanged.
      expect(state.subtaskQueue, ['Add model', 'Add service']);
    },
  );

  test(
    'maybeRefineSubtasks marks done when agent fails (non-zero exit)',
    () async {
      setQueue(['Add model']);

      final service = SpecAgentService(
        agentService: _CallTrackingAgentService(
          exitCode: 1,
          onRun: (_) => '',
        ),
      );

      await service.maybeRefineSubtasks(temp.path);

      // Should mark done to prevent retry loops.
      expect(
        stateStore.read().subtaskExecution.refinementDone,
        isTrue,
      );
    },
  );
}

class _CallTrackingAgentService extends AgentService {
  _CallTrackingAgentService({
    required this.onRun,
    this.exitCode = 0,
  });

  final String Function(AgentRequest) onRun;
  final int exitCode;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    final output = onRun(request);
    return AgentServiceResult(
      response: AgentResponse(exitCode: exitCode, stdout: output, stderr: ''),
      usedFallback: false,
    );
  }
}
