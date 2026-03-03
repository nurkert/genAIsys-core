import 'package:test/test.dart';

import 'package:genaisys/core/agents/provider_process_runner.dart';

void main() {
  test('ProviderProcessFailure keeps machine-readable classification keys', () {
    const failure = ProviderProcessFailure(
      errorClass: 'provider',
      errorKind: 'agent_unavailable',
      message: 'Agent executable not found.',
      details: <String, Object?>{
        'attempt': 'primary',
        'error_class': 'overridden',
      },
    );

    final data = failure.toMachineMap();

    expect(data['error_class'], 'provider');
    expect(data['error_kind'], 'agent_unavailable');
    expect(data['message'], 'Agent executable not found.');
    expect(data['attempt'], 'primary');
  });

  test(
    'ProviderProcessAdapter exposes command assembly and output parsing',
    () {
      final adapter = _FakeProviderAdapter();
      final request = ProviderProcessRequest(prompt: 'Ping');
      final command = adapter.commandAssembler.assemble(request);
      final execution = ProviderProcessExecution(
        command: command,
        exitCode: 0,
        stdout: 'APPROVE',
        stderr: '',
        startedAt: DateTime.utc(2026, 2, 11),
        duration: const Duration(milliseconds: 12),
      );

      final response = adapter.outputParser.parse(
        execution,
        request: request,
        command: command,
      );

      expect(command.commandLine, 'fake-agent --run');
      expect(response.ok, isTrue);
      expect(response.execution.stdout, 'APPROVE');
    },
  );

  test('ProviderProcessAdapter lifecycle hooks default to no-op', () async {
    final adapter = _FakeProviderAdapter();
    final request = ProviderProcessRequest(prompt: 'Ping');
    final command = adapter.commandAssembler.assemble(request);
    final startedAt = DateTime.utc(2026, 2, 11);
    final context = ProviderProcessLifecycleContext(
      request: request,
      command: command,
      startedAt: startedAt,
    );
    final result = ProviderProcessLifecycleResult(
      request: request,
      command: command,
      startedAt: startedAt,
      response: ProviderProcessResponse(
        execution: ProviderProcessExecution(
          command: command,
          exitCode: 0,
          stdout: '',
          stderr: '',
          startedAt: startedAt,
          duration: const Duration(milliseconds: 1),
        ),
      ),
    );

    await adapter.lifecycleHooks.onBeforeStart(context);
    await adapter.lifecycleHooks.onAfterComplete(result);
    await adapter.lifecycleHooks.onFailure(result);
  });
}

class _FakeProviderAdapter extends ProviderProcessAdapter {
  _FakeProviderAdapter()
    : _commandAssembler = _FakeCommandAssembler(),
      _outputParser = _FakeOutputParser();

  final ProviderProcessCommandAssembler _commandAssembler;
  final ProviderProcessOutputParser _outputParser;

  @override
  ProviderProcessCommandAssembler get commandAssembler => _commandAssembler;

  @override
  ProviderProcessOutputParser get outputParser => _outputParser;
}

class _FakeCommandAssembler implements ProviderProcessCommandAssembler {
  @override
  ProviderProcessCommand assemble(ProviderProcessRequest request) {
    return const ProviderProcessCommand(
      executable: 'fake-agent',
      arguments: <String>['--run'],
      runInShell: false,
    );
  }
}

class _FakeOutputParser implements ProviderProcessOutputParser {
  @override
  ProviderProcessResponse parse(
    ProviderProcessExecution execution, {
    required ProviderProcessRequest request,
    required ProviderProcessCommand command,
  }) {
    return ProviderProcessResponse(execution: execution);
  }
}
