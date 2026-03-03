import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_registry.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/agent_selector.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';

import '../support/test_workspace.dart';

void main() {
  test(
    'AgentService emits start + heartbeat events while runner is active',
    () async {
      final workspace = TestWorkspace.create(prefix: 'genaisys_agent_log_');
      addTearDown(workspace.dispose);
      workspace.ensureStructure(overwrite: true);
      final fakeExecutable = File('${workspace.root.path}/fake-agent.sh');
      fakeExecutable.writeAsStringSync('#!/usr/bin/env bash\nexit 0\n');
      Process.runSync('chmod', ['+x', fakeExecutable.path]);

      final runner = _BlockingFakeRunner(executable: fakeExecutable.path);

      File(workspace.layout.configPath).writeAsStringSync('''
providers:
  pool:
    - "fake@default"
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "${fakeExecutable.path}"
''');

      final selector = AgentSelector(
        registry: AgentRegistry(custom: <String, AgentRunner>{'fake': runner}),
      );
      final service = AgentService(
        selector: selector,
        commandHeartbeatInterval: const Duration(milliseconds: 10),
        commandHeartbeatMaxCount: 2,
      );

      final runFuture = service.run(
        workspace.root.path,
        AgentRequest(
          prompt: 'do something',
          workingDirectory: workspace.root.path,
        ),
      );
      await _waitForRunLogEvent(
        workspace.layout.runLogPath,
        event: 'agent_command_heartbeat',
        timeout: const Duration(seconds: 2),
      );

      runner.release();

      final result = await runFuture.timeout(const Duration(seconds: 2));
      expect(result.response.ok, isTrue);

      final logText = File(
        ProjectLayout(workspace.root.path).runLogPath,
      ).readAsStringSync();
      expect(logText, contains('"event":"agent_command_start"'));
      expect(logText, contains('"event":"agent_command_heartbeat"'));
    },
  );
}

class _BlockingFakeRunner implements AgentRunner {
  _BlockingFakeRunner({required this.executable});

  final Completer<void> _release = Completer<void>();

  // Keep preflight/allowlist deterministic across environments (CI/local).
  final String executable;
  final List<String> args = const <String>[];

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    await _release.future;
    return AgentResponse(
      exitCode: 0,
      stdout: 'ok',
      stderr: '',
      commandEvent: AgentCommandEvent(
        executable: executable,
        arguments: args,
        runInShell: false,
        startedAt: DateTime.now().toUtc().toIso8601String(),
        durationMs: 0,
        timedOut: false,
        workingDirectory: request.workingDirectory,
      ),
    );
  }
}

Future<void> _waitForRunLogEvent(
  String path, {
  required String event,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().toUtc().add(timeout);
  final marker = '"event":"$event"';
  while (DateTime.now().toUtc().isBefore(deadline)) {
    final file = File(path);
    if (file.existsSync()) {
      final text = file.readAsStringSync();
      if (text.contains(marker)) {
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException('Timed out waiting for run log event: $event');
}
