import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/review_bundle.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agent_context_service.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/autopilot_run_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_review_fresh_');
    workspace.ensureStructure(overwrite: true);
  });

  tearDown(() => workspace.dispose());

  ReviewBundle makeBundle() {
    return const ReviewBundle(
      diffSummary: 'lib/core/foo.dart | 5 +++--',
      diffPatch: '+++ b/lib/core/foo.dart\n+// new line',
      testSummary: 'All 10 tests passed.',
      taskTitle: 'Fix foo service',
      spec: 'Update foo to handle null.',
    );
  }

  test(
    'reviewFreshContext=true omits prior cycle context from prompt',
    () async {
      // Default config has reviewFreshContext=true.
      final capturedAgent = _CapturingAgentService();
      final service = ReviewAgentService(
        agentService: capturedAgent,
        contextService: AgentContextService(),
      );

      // Set state with prior failure context.
      final layout = ProjectLayout(workspace.root.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          autopilotRun: const AutopilotRunState(
            lastError: 'Previous test failure in foo_test.dart',
          ),
          activeTask: const ActiveTaskState(
            forensicGuidance: 'Try smaller scope.',
          ),
        ),
      );

      await service.reviewBundle(workspace.root.path, bundle: makeBundle());

      final prompt = capturedAgent.lastPrompt!;
      expect(prompt, isNot(contains('Prior cycle context')));
      expect(prompt, isNot(contains('Previous test failure')));
      expect(prompt, isNot(contains('Try smaller scope')));
    },
  );

  test(
    'reviewFreshContext=false includes prior cycle context in prompt',
    () async {
      // Write config with fresh_context: false.
      workspace.writeConfig('''
review:
  fresh_context: false
''');
      final capturedAgent = _CapturingAgentService();
      final service = ReviewAgentService(
        agentService: capturedAgent,
        contextService: AgentContextService(),
      );

      final layout = ProjectLayout(workspace.root.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          autopilotRun: const AutopilotRunState(
            lastError: 'Previous test failure in foo_test.dart',
          ),
          activeTask: const ActiveTaskState(
            forensicGuidance: 'Try smaller scope.',
          ),
        ),
      );

      await service.reviewBundle(workspace.root.path, bundle: makeBundle());

      final prompt = capturedAgent.lastPrompt!;
      expect(prompt, contains('Prior cycle context'));
      expect(prompt, contains('Previous test failure in foo_test.dart'));
      expect(prompt, contains('Try smaller scope'));
    },
  );

  test(
    'reviewFreshContext=false with no prior context omits section',
    () async {
      workspace.writeConfig('''
review:
  fresh_context: false
''');
      final capturedAgent = _CapturingAgentService();
      final service = ReviewAgentService(
        agentService: capturedAgent,
        contextService: AgentContextService(),
      );

      await service.reviewBundle(workspace.root.path, bundle: makeBundle());

      final prompt = capturedAgent.lastPrompt!;
      expect(prompt, isNot(contains('Prior cycle context')));
    },
  );
}

/// A fake [AgentService] that captures the last prompt sent to the agent
/// and returns a canned APPROVE response.
class _CapturingAgentService extends AgentService {
  String? lastPrompt;
  String? lastSystemPrompt;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastPrompt = request.prompt;
    lastSystemPrompt = request.systemPrompt;
    return AgentServiceResult(
      response: AgentResponse(
        exitCode: 0,
        stdout:
            'APPROVE\nChanges look correct. '
            'lib/core/foo.dart updated properly.',
        stderr: '',
      ),
      usedFallback: false,
    );
  }
}
