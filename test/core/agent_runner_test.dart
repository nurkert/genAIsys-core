import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';

void main() {
  test('AgentResponse ok reflects exit code', () {
    const okResponse = AgentResponse(exitCode: 0, stdout: '', stderr: '');
    const failResponse = AgentResponse(exitCode: 1, stdout: '', stderr: '');

    expect(okResponse.ok, isTrue);
    expect(failResponse.ok, isFalse);
  });

  test('AgentCommandEvent exposes command line', () {
    const event = AgentCommandEvent(
      executable: 'dart',
      arguments: ['analyze', '.'],
      runInShell: false,
      startedAt: '2026-02-06T00:00:00Z',
      durationMs: 12,
      timedOut: false,
    );

    expect(event.commandLine, 'dart analyze .');
  });
}
