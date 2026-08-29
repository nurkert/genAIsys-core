import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/security/redaction_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/templates/default_files.dart';

void main() {
  test('CodingAgentService writes output to attempts file', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('CODE OUTPUT');
    final service = CodingAgentService(agentService: agentService);

    final result = await service.run(temp.path, prompt: 'Implement change');

    expect(File(result.path).existsSync(), isTrue);
    expect(File(result.path).readAsStringSync(), 'CODE OUTPUT');
  });

  test(
    'CodingAgentService prompt clarifies git delivery and requires a concrete diff',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_coding_agent_prompt_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

      final stateStore = StateStore(layout.statePath);
      stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

      final agentService = _FakeAgentService('CODE OUTPUT');
      final service = CodingAgentService(agentService: agentService);

      await service.run(temp.path, prompt: 'Implement change');

      final prompt = agentService.lastPrompt ?? '';
      expect(prompt, contains('Genaisys handles delivery'));
      expect(prompt, contains('Always produce a concrete change (git diff)'));
      expect(prompt, contains('BLOCK reason'));
    },
  );

  test('CodingAgentService redacts sensitive stderr in attempt file', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_redact_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService(
      'ok',
      stderr:
          'Authorization: Bearer sk-secret-value-123456789\nOPENAI_API_KEY=sk-secret-value-123456789',
    );
    final service = CodingAgentService(
      agentService: agentService,
      redactionService: RedactionService(
        environment: {'OPENAI_API_KEY': 'sk-secret-value-123456789'},
      ),
    );

    final result = await service.run(temp.path, prompt: 'Implement change');
    final attempt = File(result.path).readAsStringSync();
    final runLog = File(layout.runLogPath).readAsStringSync();

    expect(attempt, isNot(contains('sk-secret-value-123456789')));
    expect(attempt, contains('[REDACTED:OPENAI_API_KEY]'));
    expect(runLog, contains('"redactions_applied":true'));
  });

  test('CodingAgentService sets CLAUDE_CODE_CLI_CONFIG_OVERRIDES with '
      '--dangerously-skip-permissions auto-injected', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_claude_overrides_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "claude-code"
  claude_code_cli_config_overrides:
    - "--model=claude-sonnet-4-5-20250929"
''');

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('OK');
    final service = CodingAgentService(agentService: agentService);

    await service.run(temp.path, prompt: 'Implement change');

    final env = agentService.lastEnvironment ?? {};
    final claudeOverrides =
        env['GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES'] ?? '';
    expect(claudeOverrides, contains('--model=claude-sonnet-4-5-20250929'));
    expect(claudeOverrides, contains('--dangerously-skip-permissions'));
  });

  test('CodingAgentService does not duplicate --dangerously-skip-permissions '
      'when already configured', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_claude_dedup_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "claude-code"
  claude_code_cli_config_overrides:
    - "--dangerously-skip-permissions"
    - "--model=claude-sonnet-4-5-20250929"
''');

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('OK');
    final service = CodingAgentService(agentService: agentService);

    await service.run(temp.path, prompt: 'Implement change');

    final env = agentService.lastEnvironment ?? {};
    final claudeOverrides =
        env['GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES'] ?? '';
    final count = '--dangerously-skip-permissions'
        .allMatches(claudeOverrides)
        .length;
    expect(count, 1, reason: 'flag must not be duplicated');
  });

  test('CodingAgentService injects --dangerously-skip-permissions even when '
      'no claude overrides are configured', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_claude_default_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    // Config with no claude_code_cli_config_overrides at all.
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "claude-code"
''');

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('OK');
    final service = CodingAgentService(agentService: agentService);

    await service.run(temp.path, prompt: 'Implement change');

    final env = agentService.lastEnvironment ?? {};
    final claudeOverrides =
        env['GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES'] ?? '';
    expect(
      claudeOverrides,
      contains('--dangerously-skip-permissions'),
      reason: 'must be auto-injected even with empty config',
    );
  });

  test('CodingAgentResult.partialOutputAvailable is false for successful runs',
      () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_partial_ok_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('CODE OUTPUT');
    final service = CodingAgentService(agentService: agentService);

    final result = await service.run(temp.path, prompt: 'Implement change');

    expect(result.partialOutputAvailable, isFalse);
  });

  test(
    'CodingAgentService timeout with non-empty stdout reports '
    'partial_output_available in run log and exception message',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_coding_agent_timeout_partial_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

      final stateStore = StateStore(layout.statePath);
      stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

      final agentService = _FakeAgentService(
        'partial output here',
        exitCode: 124,
      );
      final service = CodingAgentService(agentService: agentService);

      await expectLater(
        () => service.run(temp.path, prompt: 'Implement change'),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            contains('partial_output_available=true'),
          ),
        ),
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"partial_output_available":true'));
    },
  );

  test(
    'CodingAgentService timeout with empty stdout reports '
    'partial_output_available=false in run log',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_coding_agent_timeout_empty_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

      final stateStore = StateStore(layout.statePath);
      stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

      final agentService = _FakeAgentService('', exitCode: 124);
      final service = CodingAgentService(agentService: agentService);

      await expectLater(
        () => service.run(temp.path, prompt: 'Implement change'),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            contains('partial_output_available=false'),
          ),
        ),
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('"partial_output_available":false'));
    },
  );

  test('CodingAgentService passes gemini config overrides without injecting -y '
      '(runner already uses --approval-mode yolo)', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_gemini_overrides_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "gemini"
  gemini_cli_config_overrides:
    - "--model=gemini-2.5-pro"
''');

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('OK');
    final service = CodingAgentService(agentService: agentService);

    await service.run(temp.path, prompt: 'Implement change');

    final env = agentService.lastEnvironment ?? {};
    final geminiOverrides =
        env['GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES'] ?? '';
    expect(geminiOverrides, contains('--model=gemini-2.5-pro'));
    // -y must NOT be injected because GeminiRunner already passes
    // --approval-mode yolo and newer Gemini CLI rejects both together.
    expect(geminiOverrides, isNot(contains('-y')));
  });

  test('CodingAgentService preserves explicit -y from user config overrides',
      () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_gemini_dedup_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "gemini"
  gemini_cli_config_overrides:
    - "-y"
    - "--model=gemini-2.5-pro"
''');

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('OK');
    final service = CodingAgentService(agentService: agentService);

    await service.run(temp.path, prompt: 'Implement change');

    final env = agentService.lastEnvironment ?? {};
    final geminiOverrides =
        env['GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES'] ?? '';
    // User-supplied -y is preserved but not duplicated.
    final count = '-y'.allMatches(geminiOverrides).length;
    expect(count, 1, reason: '-y flag must not be duplicated');
  });

  test('CodingAgentService does not inject -y when no gemini overrides are '
      'configured (runner handles approval mode)', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_coding_agent_gemini_default_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "gemini"
''');

    final stateStore = StateStore(layout.statePath);
    stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

    final agentService = _FakeAgentService('OK');
    final service = CodingAgentService(agentService: agentService);

    await service.run(temp.path, prompt: 'Implement change');

    final env = agentService.lastEnvironment ?? {};
    final geminiOverrides =
        env['GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES'] ?? '';
    // No -y injected: GeminiRunner default args already include
    // --approval-mode yolo for unattended execution.
    expect(
      geminiOverrides,
      isNot(contains('-y')),
      reason: 'runner handles approval mode, no -y injection needed',
    );
  });

  test(
    'CodingAgentService non-timeout failure does not include '
    'partial_output_available in run log',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_coding_agent_fail_no_partial_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.statePath).writeAsStringSync(DefaultFiles.stateJson());

      final stateStore = StateStore(layout.statePath);
      stateStore.write(stateStore.read().copyWith(activeTask: ActiveTaskState(title: 'My Task')));

      final agentService = _FakeAgentService(
        '',
        exitCode: 1,
        stderr: 'some error',
      );
      final service = CodingAgentService(agentService: agentService);

      await expectLater(
        () => service.run(temp.path, prompt: 'Implement change'),
        throwsA(isA<StateError>()),
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, isNot(contains('partial_output_available')));
    },
  );
}

class _FakeAgentService extends AgentService {
  _FakeAgentService(this.output, {this.exitCode = 0, this.stderr = ''});

  final String output;
  final int exitCode;
  final String stderr;
  String? lastPrompt;
  Map<String, String>? lastEnvironment;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastPrompt = request.prompt;
    lastEnvironment = request.environment;
    return AgentServiceResult(
      response: AgentResponse(
        exitCode: exitCode,
        stdout: output,
        stderr: stderr,
      ),
      usedFallback: false,
    );
  }
}
