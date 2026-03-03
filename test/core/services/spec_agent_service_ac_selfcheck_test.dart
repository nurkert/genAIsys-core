import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

// ignore_for_file: unused_import

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_ac_selfcheck_');
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    layout = ProjectLayout(temp.path);
    StateStore(layout.statePath).write(
      StateStore(layout.statePath).read().copyWith(
        activeTask: const ActiveTaskState(title: 'Add feature', id: 'task-1'),
      ),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('returns passed=true when agent responds PASS', () async {
    final service = SpecAgentService(
      agentService: _FakeAgentService(response: 'PASS'),
    );

    final result = await service.checkImplementationAgainstAc(
      temp.path,
      requirement: 'Add a new endpoint',
      diffSummary: '+++ b/lib/api.dart\n+class Endpoint {}',
    );

    expect(result.passed, isTrue);
    expect(result.skipped, isFalse);
    expect(result.reason, isNull);
  });

  test('returns passed=false with reason when agent responds FAIL', () async {
    final service = SpecAgentService(
      agentService: _FakeAgentService(
        response: 'FAIL\nTests for the new endpoint are missing.',
      ),
    );

    final result = await service.checkImplementationAgainstAc(
      temp.path,
      requirement: 'Add a new endpoint with tests',
      diffSummary: '+++ b/lib/api.dart\n+class Endpoint {}',
    );

    expect(result.passed, isFalse);
    expect(result.skipped, isFalse);
    expect(result.reason, contains('Tests'));
  });

  test('returns skipped=true when agent call fails (non-zero exit)', () async {
    final service = SpecAgentService(
      agentService: _FakeAgentService(response: 'error', exitCode: 1),
    );

    final result = await service.checkImplementationAgainstAc(
      temp.path,
      requirement: 'Add a new endpoint',
      diffSummary: '+++ b/lib/api.dart',
    );

    expect(result.skipped, isTrue);
    expect(result.passed, isTrue); // skipped counts as non-blocking
  });

  test('PASS verdict is case-insensitive at first-line check', () async {
    final service = SpecAgentService(
      agentService: _FakeAgentService(response: 'pass\nsome extra'),
    );

    final result = await service.checkImplementationAgainstAc(
      temp.path,
      requirement: 'Req',
      diffSummary: 'diff',
    );

    expect(result.passed, isTrue);
  });
}

class _FakeAgentService extends AgentService {
  _FakeAgentService({required this.response, this.exitCode = 0});

  final String response;
  final int exitCode;

  @override
  Future<AgentServiceResult> run(String projectRoot, AgentRequest request) async {
    return AgentServiceResult(
      response: AgentResponse(
        exitCode: exitCode,
        stdout: response,
        stderr: '',
      ),
      usedFallback: false,
    );
  }
}
