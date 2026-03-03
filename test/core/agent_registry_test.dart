import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_registry.dart';
import 'package:genaisys/core/agents/agent_runner.dart';

void main() {
  test('AgentRegistry resolves all five built-in runners by name', () {
    final registry = AgentRegistry(
      codex: _FakeRunner(),
      gemini: _FakeRunner(),
      claudeCode: _FakeRunner(),
      vibe: _FakeRunner(),
      amp: _FakeRunner(),
    );

    expect(registry.resolve('codex'), isNotNull);
    expect(registry.resolve('gemini'), isNotNull);
    expect(registry.resolve('claude-code'), isNotNull);
    expect(registry.resolve('vibe'), isNotNull);
    expect(registry.resolve('amp'), isNotNull);
  });

  test('AgentRegistry resolves default when provider is empty', () {
    final registry = AgentRegistry(codex: _FakeRunner());

    final runner = registry.resolveOrDefault(null);

    expect(runner, isNotNull);
  });

  test('AgentRegistry resolves custom providers', () {
    final customRunner = _FakeRunner();
    final registry = AgentRegistry(
      codex: _FakeRunner(),
      custom: {'custom-agent': customRunner},
    );

    final runner = registry.resolve('custom-agent');

    expect(identical(runner, customRunner), isTrue);
  });

  test('AgentRegistry resolves vibe and amp with default constructors', () {
    final registry = AgentRegistry();

    expect(registry.resolve('vibe'), isNotNull);
    expect(registry.resolve('amp'), isNotNull);
  });

  test('Partial registry only registers explicitly provided slots', () {
    final fake = _FakeRunner();
    final registry = AgentRegistry(codex: fake);

    expect(identical(registry.resolve('codex'), fake), isTrue);
    expect(registry.resolve('gemini'), isNull);
    expect(registry.resolve('claude-code'), isNull);
    expect(registry.resolve('vibe'), isNull);
    expect(registry.resolve('amp'), isNull);
  });

  test('Default (no-arg) registry registers all five runners', () {
    final registry = AgentRegistry();

    expect(registry.resolve('codex'), isNotNull);
    expect(registry.resolve('gemini'), isNotNull);
    expect(registry.resolve('claude-code'), isNotNull);
    expect(registry.resolve('vibe'), isNotNull);
    expect(registry.resolve('amp'), isNotNull);
  });
}

class _FakeRunner implements AgentRunner {
  @override
  Future<AgentResponse> run(AgentRequest request) async {
    return const AgentResponse(exitCode: 0, stdout: '', stderr: '');
  }
}
