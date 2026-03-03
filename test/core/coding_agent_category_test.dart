import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/templates/default_files.dart';

void main() {
  group('CodingAgentService with TaskCategory', () {
    late Directory temp;
    late ProjectLayout layout;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('genaisys_cat_coding_');
      layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
      final stateStore = StateStore(layout.statePath);
      stateStore.write(
        stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'Test Task')),
      );
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('injects reasoning effort override for docs category', () async {
      final agentService = _CapturingAgentService();
      final service = CodingAgentService(agentService: agentService);

      await service.run(
        temp.path,
        prompt: 'Update docs',
        taskCategory: TaskCategory.docs,
      );

      final env = agentService.lastRequest!.environment ?? {};
      final overrides = env['GENAISYS_CODEX_CLI_CONFIG_OVERRIDES'] ?? '';
      expect(overrides, contains('sandbox_mode="danger-full-access"'));
      expect(overrides, contains('reasoning_effort=low'));
    });

    test('injects reasoning effort override for security category', () async {
      final agentService = _CapturingAgentService();
      final service = CodingAgentService(agentService: agentService);

      await service.run(
        temp.path,
        prompt: 'Fix security',
        taskCategory: TaskCategory.security,
      );

      final env = agentService.lastRequest!.environment ?? {};
      final overrides = env['GENAISYS_CODEX_CLI_CONFIG_OVERRIDES'] ?? '';
      expect(overrides, contains('reasoning_effort=high'));
    });

    test('sets category-based timeout on request', () async {
      final agentService = _CapturingAgentService();
      final service = CodingAgentService(agentService: agentService);

      await service.run(
        temp.path,
        prompt: 'Update docs',
        taskCategory: TaskCategory.docs,
      );

      // Default docs timeout is 180 seconds.
      expect(agentService.lastRequest!.timeout, const Duration(seconds: 180));
    });

    test('sets larger timeout for refactor category', () async {
      final agentService = _CapturingAgentService();
      final service = CodingAgentService(agentService: agentService);

      await service.run(
        temp.path,
        prompt: 'Refactor code',
        taskCategory: TaskCategory.refactor,
      );

      // Default refactor timeout is 480 seconds.
      expect(agentService.lastRequest!.timeout, const Duration(seconds: 480));
    });

    test('no timeout override without taskCategory', () async {
      final agentService = _CapturingAgentService();
      final service = CodingAgentService(agentService: agentService);

      await service.run(temp.path, prompt: 'Change code');

      // Without category, timeout should be null (AgentService uses global).
      expect(agentService.lastRequest!.timeout, isNull);
    });

    test(
      'preserves existing codex_cli_config_overrides alongside category',
      () async {
        // Write a config with existing overrides.
        File(layout.configPath).writeAsStringSync('''
providers:
  primary: codex
  codex_cli_config_overrides:
    - model="gpt-5.3-codex"
''');

        final agentService = _CapturingAgentService();
        final service = CodingAgentService(agentService: agentService);

        await service.run(
          temp.path,
          prompt: 'Fix docs',
          taskCategory: TaskCategory.docs,
        );

        final env = agentService.lastRequest!.environment ?? {};
        final overrides = env['GENAISYS_CODEX_CLI_CONFIG_OVERRIDES'] ?? '';
        expect(overrides, contains('model="gpt-5.3-codex"'));
        expect(overrides, contains('sandbox_mode="danger-full-access"'));
        expect(overrides, contains('reasoning_effort=low'));
      },
    );

    test(
      'does not inject default sandbox override when config already defines sandbox_mode',
      () async {
        File(layout.configPath).writeAsStringSync('''
providers:
  primary: codex
  codex_cli_config_overrides:
    - sandbox_mode="read-only"
''');

        final agentService = _CapturingAgentService();
        final service = CodingAgentService(agentService: agentService);

        await service.run(temp.path, prompt: 'Inspect code');

        final env = agentService.lastRequest!.environment ?? {};
        final overrides = env['GENAISYS_CODEX_CLI_CONFIG_OVERRIDES'] ?? '';
        expect(overrides, contains('sandbox_mode="read-only"'));
        expect(overrides, isNot(contains('sandbox_mode="danger-full-access"')));
      },
    );
  });
}

class _CapturingAgentService extends AgentService {
  AgentRequest? lastRequest;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastRequest = request;
    return AgentServiceResult(
      response: AgentResponse(exitCode: 0, stdout: 'ok', stderr: ''),
      usedFallback: false,
    );
  }
}
