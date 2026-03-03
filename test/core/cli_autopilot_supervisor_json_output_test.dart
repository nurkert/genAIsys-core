import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/services/autopilot/autopilot_supervisor_service.dart';

class _FakeSupervisorService extends AutopilotSupervisorService {
  String? lastRoot;
  String? lastProfile;
  String? lastPrompt;
  String? lastReason;
  int? lastMaxRestarts;

  @override
  Future<AutopilotSupervisorStartResult> start(
    String projectRoot, {
    String profile = 'overnight',
    String? prompt,
    String startReason = 'manual_start',
    int maxRestarts = AutopilotSupervisorService.defaultMaxRestarts,
    int restartBackoffBaseSeconds =
        AutopilotSupervisorService.defaultRestartBackoffBaseSeconds,
    int restartBackoffMaxSeconds =
        AutopilotSupervisorService.defaultRestartBackoffMaxSeconds,
    int lowSignalLimit = AutopilotSupervisorService.defaultLowSignalLimit,
    int throughputWindowMinutes =
        AutopilotSupervisorService.defaultThroughputWindowMinutes,
    int throughputMaxSteps =
        AutopilotSupervisorService.defaultThroughputMaxSteps,
    int throughputMaxRejects =
        AutopilotSupervisorService.defaultThroughputMaxRejects,
    int throughputMaxHighRetries =
        AutopilotSupervisorService.defaultThroughputMaxHighRetries,
  }) async {
    lastRoot = projectRoot;
    lastProfile = profile;
    lastPrompt = prompt;
    lastReason = startReason;
    lastMaxRestarts = maxRestarts;
    return const AutopilotSupervisorStartResult(
      started: true,
      sessionId: 'session-1',
      profile: 'pilot',
      pid: 7001,
      resumeAction: 'continue_safe_step',
    );
  }

  @override
  AutopilotSupervisorStatus getStatus(String projectRoot) {
    return const AutopilotSupervisorStatus(
      running: true,
      workerPid: 3333,
      sessionId: 'session-3',
      profile: 'overnight',
      startReason: 'manual_start',
      restartCount: 1,
      cooldownUntil: null,
      lastHaltReason: null,
      lastResumeAction: 'continue_safe_step',
      lastExitCode: 0,
      lowSignalStreak: 0,
      throughputWindowStartedAt: '2026-02-11T00:00:00Z',
      throughputSteps: 12,
      throughputRejects: 1,
      throughputHighRetries: 0,
      startedAt: '2026-02-11T00:00:00Z',
      autopilotRunning: false,
      autopilotPid: null,
      autopilotLastLoopAt: '2026-02-11T00:01:00Z',
      autopilotConsecutiveFailures: 0,
      autopilotLastError: null,
    );
  }

  @override
  Future<AutopilotSupervisorStopResult> stop(
    String projectRoot, {
    String reason = 'manual_stop',
  }) async {
    lastRoot = projectRoot;
    lastReason = reason;
    return const AutopilotSupervisorStopResult(
      stopped: true,
      wasRunning: false,
      reason: 'manual_stop',
    );
  }

  @override
  Future<AutopilotSupervisorStartResult> restart(
    String projectRoot, {
    String profile = 'overnight',
    String? prompt,
    String startReason = 'manual_restart',
    int maxRestarts = AutopilotSupervisorService.defaultMaxRestarts,
    int restartBackoffBaseSeconds =
        AutopilotSupervisorService.defaultRestartBackoffBaseSeconds,
    int restartBackoffMaxSeconds =
        AutopilotSupervisorService.defaultRestartBackoffMaxSeconds,
    int lowSignalLimit = AutopilotSupervisorService.defaultLowSignalLimit,
    int throughputWindowMinutes =
        AutopilotSupervisorService.defaultThroughputWindowMinutes,
    int throughputMaxSteps =
        AutopilotSupervisorService.defaultThroughputMaxSteps,
    int throughputMaxRejects =
        AutopilotSupervisorService.defaultThroughputMaxRejects,
    int throughputMaxHighRetries =
        AutopilotSupervisorService.defaultThroughputMaxHighRetries,
  }) async {
    lastRoot = projectRoot;
    lastProfile = profile;
    lastPrompt = prompt;
    lastReason = startReason;
    lastMaxRestarts = maxRestarts;
    return const AutopilotSupervisorStartResult(
      started: true,
      sessionId: 'session-r',
      profile: 'overnight',
      pid: 7002,
      resumeAction: 'continue_safe_step',
    );
  }
}

void main() {
  test('CLI autopilot supervisor start --json returns payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_supervisor_start_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');
    final stdoutSink = stdoutFile.openWrite();
    final stderrSink = stderrFile.openWrite();

    final service = _FakeSupervisorService();
    final runner = CliRunner(
      autopilotSupervisorStart: AutopilotSupervisorStartUseCase(
        service: service,
      ),
      autopilotSupervisorStatus: AutopilotSupervisorStatusUseCase(
        service: service,
      ),
      autopilotSupervisorStop: AutopilotSupervisorStopUseCase(service: service),
      autopilotSupervisorRestart: AutopilotSupervisorRestartUseCase(
        service: service,
      ),
      stdout: stdoutSink,
      stderr: stderrSink,
    );

    exitCode = 0;
    try {
      await runner.run([
        'supervisor',
        'start',
        temp.path,
        '--profile',
        'pilot',
        '--reason',
        'Manual Start',
        '--max-restarts',
        '5',
        '--json',
      ]);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }

    expect(exitCode, 0);
    expect(stderrFile.readAsStringSync(), isEmpty);
    expect(service.lastRoot, Directory(temp.path).absolute.path);
    expect(service.lastProfile, 'pilot');
    expect(service.lastReason, 'Manual Start');
    expect(service.lastMaxRestarts, 5);

    final payload =
        jsonDecode(stdoutFile.readAsStringSync().trim())
            as Map<String, dynamic>;
    expect(payload['autopilot_supervisor_started'], isTrue);
    expect(payload['profile'], 'pilot');
    expect(payload['supervisor_pid'], 7001);
  });

  test('CLI autopilot supervisor status --json returns payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_supervisor_status_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');
    final stdoutSink = stdoutFile.openWrite();
    final stderrSink = stderrFile.openWrite();

    final service = _FakeSupervisorService();
    final runner = CliRunner(
      autopilotSupervisorStart: AutopilotSupervisorStartUseCase(
        service: service,
      ),
      autopilotSupervisorStatus: AutopilotSupervisorStatusUseCase(
        service: service,
      ),
      autopilotSupervisorStop: AutopilotSupervisorStopUseCase(service: service),
      autopilotSupervisorRestart: AutopilotSupervisorRestartUseCase(
        service: service,
      ),
      stdout: stdoutSink,
      stderr: stderrSink,
    );

    exitCode = 0;
    try {
      await runner.run([
        'supervisor',
        'status',
        temp.path,
        '--json',
      ]);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }

    expect(exitCode, 0);
    expect(stderrFile.readAsStringSync(), isEmpty);
    final payload =
        jsonDecode(stdoutFile.readAsStringSync().trim())
            as Map<String, dynamic>;
    expect(payload['autopilot_supervisor_running'], isTrue);
    expect(payload['throughput'], isA<Map<String, dynamic>>());
    final autopilot = payload['autopilot'] as Map<String, dynamic>;
    expect(autopilot['running'], isFalse);
  });

  test('CLI autopilot supervisor stop --json returns payload', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_supervisor_stop_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');
    final stdoutSink = stdoutFile.openWrite();
    final stderrSink = stderrFile.openWrite();

    final service = _FakeSupervisorService();
    final runner = CliRunner(
      autopilotSupervisorStart: AutopilotSupervisorStartUseCase(
        service: service,
      ),
      autopilotSupervisorStatus: AutopilotSupervisorStatusUseCase(
        service: service,
      ),
      autopilotSupervisorStop: AutopilotSupervisorStopUseCase(service: service),
      autopilotSupervisorRestart: AutopilotSupervisorRestartUseCase(
        service: service,
      ),
      stdout: stdoutSink,
      stderr: stderrSink,
    );

    exitCode = 0;
    try {
      await runner.run([
        'supervisor',
        'stop',
        temp.path,
        '--reason',
        'operator_request',
        '--json',
      ]);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }

    expect(exitCode, 0);
    expect(stderrFile.readAsStringSync(), isEmpty);
    expect(service.lastReason, 'operator_request');

    final payload =
        jsonDecode(stdoutFile.readAsStringSync().trim())
            as Map<String, dynamic>;
    expect(payload['autopilot_supervisor_stopped'], isTrue);
    expect(payload['was_running'], isFalse);
    expect(payload['reason'], 'manual_stop');
  });
}
