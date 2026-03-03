import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_registry.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/agent_selector.dart';
import 'package:genaisys/core/agents/codex_runner.dart';
import 'package:genaisys/core/agents/gemini_runner.dart';
import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/autopilot/unattended_provider_blocklist_service.dart';

void main() {
  test('AgentService uses fallback when primary fails', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_service_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "primary-cli"
    - "fallback-cli"
''');

    final registry = AgentRegistry(
      codex: _FakeRunner(
        exitCode: 1,
        label: 'primary',
        executable: 'primary-cli',
      ),
      gemini: _FakeRunner(
        exitCode: 0,
        label: 'fallback',
        executable: 'fallback-cli',
      ),
    );
    final selector = AgentSelector(registry: registry);
    final service = AgentService(selector: selector);

    final result = await service.run(temp.path, AgentRequest(prompt: 'Test'));

    expect(result.usedFallback, isTrue);
    expect(result.response.stdout, 'fallback');

    final runEvents = _readJsonLines(layout.runLogPath);
    final commandEvents = runEvents
        .where((entry) => entry['event'] == 'agent_command')
        .toList(growable: false);
    expect(commandEvents.length, 2);
    expect(commandEvents.first['data'], isA<Map>());
    expect(
      (commandEvents.first['data'] as Map)['command_executable'],
      'primary-cli',
    );
    expect(
      (commandEvents.last['data'] as Map)['command_executable'],
      'fallback-cli',
    );

    final auditFile = File(
      '${layout.auditDir}${Platform.pathSeparator}agent_commands.jsonl',
    );
    expect(auditFile.existsSync(), isTrue);
    final auditEntries = _readJsonLines(auditFile.path);
    expect(auditEntries.length, 2);
    expect(auditEntries.first['command_executable'], 'primary-cli');
    expect(auditEntries.last['command_executable'], 'fallback-cli');
  });

  test('AgentService fails closed when runner omits command event', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_service_missing_event_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
''');

    final registry = AgentRegistry(
      codex: _FakeRunner(
        exitCode: 0,
        label: 'primary',
        executable: 'primary-cli',
        includeCommandEvent: false,
      ),
      gemini: _FakeRunner(exitCode: 0, label: 'fallback'),
    );
    final selector = AgentSelector(registry: registry);
    final service = AgentService(selector: selector);

    await expectLater(
      service.run(temp.path, AgentRequest(prompt: 'Test')),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'message',
          contains('agent_command event missing from runner response'),
        ),
      ),
    );

    final runEvents = _readJsonLines(layout.runLogPath);
    final commandEvents = runEvents
        .where((entry) => entry['event'] == 'agent_command')
        .toList(growable: false);
    expect(commandEvents, isEmpty);
    final violations = runEvents
        .where((entry) => entry['event'] == 'agent_command_policy_violation')
        .toList(growable: false);
    expect(violations.length, 1);
    final data = Map<String, Object?>.from(violations.single['data'] as Map);
    expect(data['error_kind'], 'missing_event');
  });

  test(
    'AgentService fails closed when shell allowlist blocks command',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_allowlist_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "git status"
''');

      final registry = AgentRegistry(
        codex: _FakeRunner(
          exitCode: 0,
          label: 'primary',
          executable: 'blocked-cli',
        ),
        gemini: _FakeRunner(exitCode: 0, label: 'fallback'),
      );
      final selector = AgentSelector(registry: registry);
      final service = AgentService(selector: selector);

      await expectLater(
        service.run(temp.path, AgentRequest(prompt: 'Test')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message.toString(),
            'message',
            contains(
              'shell_allowlist blocked agent command "blocked-cli exec -"',
            ),
          ),
        ),
      );

      final runEvents = _readJsonLines(layout.runLogPath);
      final commandEvents = runEvents
          .where((entry) => entry['event'] == 'agent_command')
          .toList(growable: false);
      expect(commandEvents, isEmpty);
      final violations = runEvents
          .where((entry) => entry['event'] == 'agent_command_policy_violation')
          .toList(growable: false);
      expect(violations.length, 1);
      final data = Map<String, Object?>.from(violations.single['data'] as Map);
      expect(data['error_kind'], 'shell_allowlist');
    },
  );

  test(
    'AgentService blocks non-compliant provider and skips it in unattended mode',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_unattended_block_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      Directory(layout.locksDir).createSync(recursive: true);
      File(
        layout.autopilotLockPath,
      ).writeAsStringSync('pid=999\nstarted_at=2026-02-06T00:00:00Z\n');
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "fallback-cli"
''');

      final registry = AgentRegistry(
        codex: _FakeRunner(
          exitCode: 0,
          label: 'primary',
          executable: 'primary-cli',
          includeCommandEvent: false,
        ),
        gemini: _FakeRunner(
          exitCode: 0,
          label: 'fallback',
          executable: 'fallback-cli',
        ),
      );
      final selector = AgentSelector(registry: registry);
      final service = AgentService(selector: selector);
      final blocklist = UnattendedProviderBlocklistService();

      await expectLater(
        service.run(temp.path, AgentRequest(prompt: 'Test')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message.toString(),
            'message',
            contains('agent_command event missing from runner response'),
          ),
        ),
      );
      expect(blocklist.isBlocked(temp.path, 'codex'), isTrue);

      final second = await service.run(temp.path, AgentRequest(prompt: 'Test'));
      expect(second.response.ok, isTrue);
      expect(second.response.stdout, 'fallback');
      expect(second.usedFallback, isFalse);

      final runEvents = _readJsonLines(layout.runLogPath);
      expect(
        runEvents.any(
          (entry) => entry['event'] == 'unattended_provider_blocked',
        ),
        isTrue,
      );
      expect(
        runEvents.any(
          (entry) => entry['event'] == 'unattended_provider_skipped',
        ),
        isTrue,
      );
    },
  );

  test(
    'AgentService fails when all unattended providers are blocked',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_unattended_exhausted_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      Directory(layout.locksDir).createSync(recursive: true);
      File(
        layout.autopilotLockPath,
      ).writeAsStringSync('pid=999\nstarted_at=2026-02-06T00:00:00Z\n');
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
''');

      final blocklist = UnattendedProviderBlocklistService();
      blocklist.blockProvider(
        temp.path,
        provider: 'codex',
        reason: 'missing_event',
        errorKind: 'missing_event',
      );
      blocklist.blockProvider(
        temp.path,
        provider: 'gemini',
        reason: 'missing_event',
        errorKind: 'missing_event',
      );

      final registry = AgentRegistry(
        codex: _FakeRunner(
          exitCode: 0,
          label: 'primary',
          executable: 'codex-cli',
        ),
        gemini: _FakeRunner(
          exitCode: 0,
          label: 'fallback',
          executable: 'gemini-cli',
        ),
      );
      final selector = AgentSelector(registry: registry);
      final service = AgentService(selector: selector);

      await expectLater(
        service.run(temp.path, AgentRequest(prompt: 'Test')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message.toString(),
            'message',
            contains('unattended provider selection has no eligible provider'),
          ),
        ),
      );

      final runEvents = _readJsonLines(layout.runLogPath);
      expect(
        runEvents.any(
          (entry) => entry['event'] == 'unattended_provider_exhausted',
        ),
        isTrue,
      );
    },
  );

  test(
    'AgentService recovers blocked provider when preflight passes in unattended mode',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_recover_blocked_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      Directory(layout.locksDir).createSync(recursive: true);
      File(
        layout.autopilotLockPath,
      ).writeAsStringSync('pid=999\nstarted_at=2026-02-06T00:00:00Z\n');
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "primary-cli"
''');

      final binDir = Directory('${temp.path}${Platform.pathSeparator}bin');
      binDir.createSync(recursive: true);
      final executable = File(
        '${binDir.path}${Platform.pathSeparator}primary-cli',
      );
      executable.writeAsStringSync('#!/bin/sh\nexit 0\n');
      Process.runSync('chmod', ['+x', executable.path]);

      final blocklist = UnattendedProviderBlocklistService();
      final blocked = blocklist.blockProvider(
        temp.path,
        provider: 'codex',
        reason: 'stale unavailable',
        errorKind: 'agent_unavailable',
      );
      expect(blocked, isTrue);
      expect(blocklist.isBlocked(temp.path, 'codex'), isTrue);

      final service = AgentService(
        selector: AgentSelector(
          registry: AgentRegistry(
            codex: _FakeRunner(
              exitCode: 0,
              label: 'primary',
              executable: 'primary-cli',
            ),
          ),
        ),
      );
      final envPath =
          '${binDir.path}${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}';
      final result = await service.run(
        temp.path,
        AgentRequest(prompt: 'Test', environment: {'PATH': envPath}),
      );

      expect(result.response.ok, isTrue);
      expect(result.usedFallback, isFalse);
      expect(blocklist.isBlocked(temp.path, 'codex'), isFalse);

      final runEvents = _readJsonLines(layout.runLogPath);
      expect(
        runEvents.any(
          (entry) =>
              entry['event'] == 'unattended_provider_unblocked' &&
              ((entry['data'] as Map)['provider'] == 'codex'),
        ),
        isTrue,
      );
    },
  );

  test('AgentService rotates provider pool on quota error', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_service_quota_rotate_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  pool:
    - "codex@main"
    - "gemini@backup"
  quota_cooldown_seconds: 120
  quota_pause_seconds: 30
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "primary-cli"
    - "fallback-cli"
''');

    final primary = _FakeRunner(
      exitCode: 1,
      label: 'quota',
      executable: 'primary-cli',
      stderr: 'rate limit exceeded',
    );
    final fallback = _FakeRunner(
      exitCode: 0,
      label: 'fallback',
      executable: 'fallback-cli',
    );
    final service = AgentService(
      selector: AgentSelector(
        registry: AgentRegistry(codex: primary, gemini: fallback),
      ),
    );

    final result = await service.run(temp.path, AgentRequest(prompt: 'Test'));

    expect(result.response.ok, isTrue);
    expect(result.response.stdout, 'fallback');
    expect(result.usedFallback, isTrue);
    expect(primary.callCount, 1);
    expect(fallback.callCount, 1);

    final stateFile = File(layout.providerPoolStatePath);
    expect(stateFile.existsSync(), isTrue);
    final state = jsonDecode(stateFile.readAsStringSync()) as Map;
    final entries = Map<String, Object?>.from(state['entries'] as Map);
    expect(entries.containsKey('codex@main'), isTrue);

    final runEvents = _readJsonLines(layout.runLogPath);
    expect(
      runEvents.any((entry) => entry['event'] == 'provider_pool_quota_hit'),
      isTrue,
    );
    expect(
      runEvents.any((entry) => entry['event'] == 'provider_pool_rotated'),
      isTrue,
    );
  });

  test(
    'AgentService throws QuotaPauseError when pool is quota exhausted',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_quota_pause_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
providers:
  pool:
    - "codex@main"
    - "gemini@backup"
  quota_cooldown_seconds: 300
  quota_pause_seconds: 45
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "primary-cli"
    - "fallback-cli"
''');

      final service = AgentService(
        selector: AgentSelector(
          registry: AgentRegistry(
            codex: _FakeRunner(
              exitCode: 1,
              label: 'quota-codex',
              executable: 'primary-cli',
              stderr: 'HTTP 429 Too Many Requests',
            ),
            gemini: _FakeRunner(
              exitCode: 1,
              label: 'quota-gemini',
              executable: 'fallback-cli',
              stderr: 'resource exhausted',
            ),
          ),
        ),
      );

      await expectLater(
        service.run(temp.path, AgentRequest(prompt: 'Test')),
        throwsA(
          isA<QuotaPauseError>().having(
            (error) => error.pauseFor.inSeconds,
            'pauseFor',
            greaterThan(0),
          ),
        ),
      );

      final runEvents = _readJsonLines(layout.runLogPath);
      expect(
        runEvents.any((entry) => entry['event'] == 'provider_pool_exhausted'),
        isTrue,
      );
    },
  );

  test('AgentService skips cooling-down pool entry on next run', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_service_quota_skip_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  pool:
    - "codex@main"
    - "gemini@backup"
  quota_cooldown_seconds: 600
  quota_pause_seconds: 45
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "primary-cli"
    - "fallback-cli"
''');

    final primary = _FakeRunner(
      exitCode: 1,
      label: 'quota',
      executable: 'primary-cli',
      stderr: 'rate limit reached',
    );
    final fallback = _FakeRunner(
      exitCode: 0,
      label: 'ok',
      executable: 'fallback-cli',
    );
    final service = AgentService(
      selector: AgentSelector(
        registry: AgentRegistry(codex: primary, gemini: fallback),
      ),
    );

    await service.run(temp.path, AgentRequest(prompt: 'First'));
    await service.run(temp.path, AgentRequest(prompt: 'Second'));

    expect(primary.callCount, 1);
    expect(fallback.callCount, 2);

    final runEvents = _readJsonLines(layout.runLogPath);
    expect(
      runEvents.any((entry) => entry['event'] == 'provider_pool_quota_skip'),
      isTrue,
    );
  });

  test(
    'AgentService blocks unavailable fallback provider in unattended mode',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_unattended_unavailable_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      Directory(layout.locksDir).createSync(recursive: true);
      File(
        layout.autopilotLockPath,
      ).writeAsStringSync('pid=999\nstarted_at=2026-02-06T00:00:00Z\n');
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "codex"
    - "missing-fallback-cli"
''');

      final binDir = Directory('${temp.path}${Platform.pathSeparator}bin');
      binDir.createSync(recursive: true);
      final codex = File('${binDir.path}${Platform.pathSeparator}codex');
      codex.writeAsStringSync(
        '#!/bin/sh\n'
        'cat >/dev/null\n'
        'printf "primary failed\\n" 1>&2\n'
        'exit 1\n',
      );
      Process.runSync('chmod', ['+x', codex.path]);

      final envPath =
          '${binDir.path}${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}';
      final service = AgentService(
        selector: AgentSelector(
          registry: AgentRegistry(
            codex: CodexRunner(),
            gemini: GeminiRunner(executable: 'missing-fallback-cli'),
          ),
        ),
      );
      final blocklist = UnattendedProviderBlocklistService();

      // First run: primary fails → fallback (gemini) attempted → unavailable
      // (exit 127).  Failure counter increments to 1 — below the threshold of 3.
      final first = await service.run(
        temp.path,
        AgentRequest(prompt: 'Test', environment: {'PATH': envPath}),
      );
      expect(first.response.exitCode, 127);
      expect(first.usedFallback, isTrue);
      expect(blocklist.isBlocked(temp.path, 'gemini'), isFalse);

      // Second run: primary fails again → fallback attempted again (not blocked
      // yet) → unavailable again.  Counter reaches 2 — still below threshold.
      final second = await service.run(
        temp.path,
        AgentRequest(prompt: 'Test again', environment: {'PATH': envPath}),
      );
      expect(second.response.exitCode, 127);
      expect(second.usedFallback, isTrue);
      expect(blocklist.isBlocked(temp.path, 'gemini'), isFalse);

      // Third run: counter reaches 3 → gemini now blocked.
      final third = await service.run(
        temp.path,
        AgentRequest(prompt: 'Test third', environment: {'PATH': envPath}),
      );
      expect(third.response.exitCode, 127);
      expect(third.usedFallback, isTrue);
      expect(blocklist.isBlocked(temp.path, 'gemini'), isTrue);

      // Fourth run: gemini is blocked so fallback is skipped — only primary runs.
      final fourth = await service.run(
        temp.path,
        AgentRequest(prompt: 'Test fourth', environment: {'PATH': envPath}),
      );
      expect(fourth.response.exitCode, 1);
      expect(fourth.usedFallback, isFalse);

      final runEvents = _readJsonLines(layout.runLogPath);
      expect(
        runEvents.any(
          (entry) =>
              entry['event'] == 'unattended_provider_blocked' &&
              ((entry['data'] as Map)['provider'] == 'gemini') &&
              ((entry['data'] as Map)['error_kind'] == 'agent_unavailable'),
        ),
        isTrue,
      );
      expect(
        runEvents.any(
          (entry) =>
              entry['event'] == 'unattended_provider_skipped' &&
              ((entry['data'] as Map)['provider'] == 'gemini'),
        ),
        isTrue,
      );
    },
  );

  test(
    'AgentService does not block timed-out provider as unavailable in unattended mode',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_unattended_timeout_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      Directory(layout.locksDir).createSync(recursive: true);
      File(
        layout.autopilotLockPath,
      ).writeAsStringSync('pid=999\nstarted_at=2026-02-06T00:00:00Z\n');
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
policies:
  shell_allowlist_profile: custom
  shell_allowlist:
    - "codex-cli"
    - "gemini-cli"
''');

      final primary = _FakeRunner(
        exitCode: 124,
        label: '',
        executable: 'codex-cli',
        stderr: 'operation not permitted',
        timedOut: true,
      );
      final fallback = _FakeRunner(
        exitCode: 0,
        label: 'fallback',
        executable: 'gemini-cli',
      );

      final service = AgentService(
        selector: AgentSelector(
          registry: AgentRegistry(codex: primary, gemini: fallback),
        ),
      );
      final blocklist = UnattendedProviderBlocklistService();

      final first = await service.run(temp.path, AgentRequest(prompt: 'Test'));
      expect(first.response.ok, isTrue);
      expect(first.response.stdout, 'fallback');
      expect(first.usedFallback, isTrue);
      expect(primary.callCount, 1);
      expect(fallback.callCount, 1);
      expect(blocklist.isBlocked(temp.path, 'codex'), isFalse);

      final second = await service.run(
        temp.path,
        AgentRequest(prompt: 'Second run'),
      );
      expect(second.response.ok, isTrue);
      expect(second.usedFallback, isTrue);
      expect(primary.callCount, 2);
      expect(fallback.callCount, 2);
      expect(blocklist.isBlocked(temp.path, 'codex'), isFalse);

      final runEvents = _readJsonLines(layout.runLogPath);
      expect(
        runEvents.any(
          (entry) =>
              entry['event'] == 'unattended_provider_blocked' &&
              ((entry['data'] as Map)['provider'] == 'codex') &&
              ((entry['data'] as Map)['error_kind'] == 'agent_unavailable'),
        ),
        isFalse,
      );
    },
  );

  test(
    'AgentService throws StateError when no providers are configured in pool',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_agent_service_no_provider_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      Directory(layout.locksDir).createSync(recursive: true);
      File(
        layout.autopilotLockPath,
      ).writeAsStringSync('pid=999\nstarted_at=2026-02-06T00:00:00Z\n');
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
''');

      // Block all providers so that the candidates list is empty.
      final blocklist = UnattendedProviderBlocklistService();
      blocklist.blockProvider(
        temp.path,
        provider: 'codex',
        reason: 'test_block',
        errorKind: 'missing_event',
      );
      blocklist.blockProvider(
        temp.path,
        provider: 'gemini',
        reason: 'test_block',
        errorKind: 'missing_event',
      );

      final registry = AgentRegistry(
        codex: _FakeRunner(
          exitCode: 0,
          label: 'primary',
          executable: 'codex-cli',
        ),
        gemini: _FakeRunner(
          exitCode: 0,
          label: 'fallback',
          executable: 'gemini-cli',
        ),
      );
      final selector = AgentSelector(registry: registry);
      final service = AgentService(selector: selector);

      await expectLater(
        service.run(temp.path, AgentRequest(prompt: 'Test')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message.toString(),
            'message',
            contains('no eligible provider'),
          ),
        ),
      );
    },
  );

  test(
    'classifyOperationError classifies TimeoutException as TransientError',
    () {
      final error = TimeoutException(
        'Agent timed out',
        const Duration(seconds: 30),
      );
      final classified = classifyOperationError(error, StackTrace.current);
      expect(classified, isA<TransientError>());
      expect(classified.message, contains('TimeoutException'));
    },
  );
}

class _FakeRunner implements AgentRunner {
  _FakeRunner({
    required this.exitCode,
    required this.label,
    this.executable = 'fake-cli',
    this.includeCommandEvent = true,
    this.stderr = '',
    this.timedOut = false,
  });

  final int exitCode;
  final String label;
  final String executable;
  final bool includeCommandEvent;
  final String stderr;
  final bool timedOut;
  int callCount = 0;

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    callCount += 1;
    return AgentResponse(
      exitCode: exitCode,
      stdout: label,
      stderr: stderr,
      commandEvent: includeCommandEvent
          ? AgentCommandEvent(
              executable: executable,
              arguments: const ['exec', '-'],
              runInShell: false,
              startedAt: '2026-02-06T00:00:00Z',
              durationMs: 12,
              timedOut: timedOut,
              workingDirectory: request.workingDirectory,
            )
          : null,
    );
  }
}

List<Map<String, Object?>> _readJsonLines(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const [];
  }
  final output = <Map<String, Object?>>[];
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is Map) {
      output.add(Map<String, Object?>.from(decoded));
    }
  }
  return output;
}
