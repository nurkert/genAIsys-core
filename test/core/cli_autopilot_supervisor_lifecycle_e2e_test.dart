import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/autopilot_preflight_service.dart';
import 'package:genaisys/core/services/autopilot/autopilot_supervisor_service.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/cli/cli_runner.dart';

class _NoopRunService implements OrchestratorRunService {
  @override
  void Function()? heartbeatWriterForTest;

  @override
  void requestStop(String projectRoot) {}

  @override
  AutopilotStatus getStatus(String projectRoot) {
    return AutopilotStatus(
      isRunning: false,
      pid: null,
      startedAt: null,
      lastLoopAt: null,
      consecutiveFailures: 0,
      lastError: null,
      subtaskQueue: const [],
      currentSubtask: null,
      lastStepSummary: null,
    );
  }

  @override
  Future<OrchestratorRunResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    Duration? stepSleep,
    Duration? idleSleep,
    int? maxSteps,
    bool stopWhenIdle = false,
    int? maxConsecutiveFailures,
    int? maxTaskRetries,
    bool unattendedMode = false,
    bool overrideSafety = false,
  }) async {
    throw UnimplementedError(
      'run should not be called in this CLI lifecycle test',
    );
  }

  @override
  Future<void> stop(String projectRoot) async {}

  @override
  int? pidOrNull() => null;
}

class _AlwaysPassPreflightService extends AutopilotPreflightService {
  @override
  AutopilotPreflightResult check(
    String projectRoot, {
    Map<String, String>? environment,
    bool requirePushReadiness = false,
    Duration? preflightTimeoutOverride,
  }) {
    return const AutopilotPreflightResult.ok();
  }
}

void main() {
  test(
    'CLI autopilot supervisor lifecycle parity covers start/status/restart/stop/crash-recover',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_supervisor_cli_e2e_',
      );
      final trackedPids = <int>{};

      addTearDown(() {
        for (final pid in trackedPids) {
          try {
            Process.killPid(pid, ProcessSignal.sigkill);
          } catch (_) {}
        }
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
        exitCode = 0;
      });

      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final service = AutopilotSupervisorService(
        runService: _NoopRunService(),
        preflightService: _AlwaysPassPreflightService(),
        spawnWorker:
            (
              projectRoot, {
              required sessionId,
              required profile,
              required prompt,
              required startReason,
              required maxRestarts,
              required restartBackoffBaseSeconds,
              required restartBackoffMaxSeconds,
              required lowSignalLimit,
              required throughputWindowMinutes,
              required throughputMaxSteps,
              required throughputMaxRejects,
              required throughputMaxHighRetries,
            }) async {
              final process = await Process.start('sh', ['-c', 'sleep 300']);
              trackedPids.add(process.pid);
              return process.pid;
            },
      );

      final start = await _runSupervisorJson(service, [
        'supervisor',
        'start',
        temp.path,
        '--profile',
        'pilot',
        '--json',
      ]);
      expect(start['autopilot_supervisor_started'], isTrue);
      expect(start['profile'], 'pilot');
      final firstPid = start['supervisor_pid'] as int;

      final statusAfterStart = await _runSupervisorJson(service, [
        'supervisor',
        'status',
        temp.path,
        '--json',
      ]);
      expect(statusAfterStart['autopilot_supervisor_running'], isTrue);
      expect(statusAfterStart['supervisor_pid'], firstPid);

      final restart = await _runSupervisorJson(service, [
        'supervisor',
        'restart',
        temp.path,
        '--profile',
        'overnight',
        '--json',
      ]);
      expect(restart['autopilot_supervisor_started'], isTrue);
      expect(restart['profile'], 'overnight');
      final restartedPid = restart['supervisor_pid'] as int;
      expect(restartedPid, isNot(firstPid));

      final stop = await _runSupervisorJson(service, [
        'supervisor',
        'stop',
        temp.path,
        '--reason',
        'operator_request',
        '--json',
      ]);
      expect(stop['autopilot_supervisor_stopped'], isTrue);
      expect(stop['reason'], 'operator_request');

      final statusAfterStop = await _runSupervisorJson(service, [
        'supervisor',
        'status',
        temp.path,
        '--json',
      ]);
      expect(statusAfterStop['autopilot_supervisor_running'], isFalse);

      final crashStart = await _runSupervisorJson(service, [
        'supervisor',
        'start',
        temp.path,
        '--profile',
        'pilot',
        '--json',
      ]);
      final crashPid = crashStart['supervisor_pid'] as int;
      Process.killPid(crashPid, ProcessSignal.sigkill);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final crashRecoveredStatus = await _runSupervisorJson(service, [
        'supervisor',
        'status',
        temp.path,
        '--json',
      ]);
      expect(crashRecoveredStatus['autopilot_supervisor_running'], isFalse);
      expect(
        crashRecoveredStatus['last_halt_reason'],
        'stale_supervisor_recovered',
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(
        runLog,
        contains('"event":"autopilot_supervisor_stale_recovered"'),
      );
    },
  );
}

Future<Map<String, dynamic>> _runSupervisorJson(
  AutopilotSupervisorService service,
  List<String> command,
) async {
  final nowMicros = DateTime.now().microsecondsSinceEpoch;
  final outFile = File(
    '${Directory.systemTemp.path}/genaisys_supervisor_cli_out_$nowMicros.jsonl',
  );
  final errFile = File(
    '${Directory.systemTemp.path}/genaisys_supervisor_cli_err_$nowMicros.log',
  );
  final outSink = outFile.openWrite();
  final errSink = errFile.openWrite();

  final runner = CliRunner(
    autopilotSupervisorStart: AutopilotSupervisorStartUseCase(service: service),
    autopilotSupervisorStatus: AutopilotSupervisorStatusUseCase(
      service: service,
    ),
    autopilotSupervisorStop: AutopilotSupervisorStopUseCase(service: service),
    autopilotSupervisorRestart: AutopilotSupervisorRestartUseCase(
      service: service,
    ),
    stdout: outSink,
    stderr: errSink,
  );

  exitCode = 0;
  try {
    await runner.run(command);
    await outSink.flush();
    await errSink.flush();
  } finally {
    await outSink.close();
    await errSink.close();
    await outSink.done;
    await errSink.done;
  }

  final stderrText = errFile.existsSync() ? errFile.readAsStringSync() : '';
  expect(exitCode, 0, reason: stderrText);
  expect(stderrText.trim(), isEmpty);

  final stdoutText = outFile.readAsStringSync().trim();
  expect(
    stdoutText,
    isNotEmpty,
    reason: 'missing JSON output for: ${command.join(' ')}',
  );
  final payload = jsonDecode(stdoutText) as Map<String, dynamic>;
  if (outFile.existsSync()) {
    outFile.deleteSync();
  }
  if (errFile.existsSync()) {
    errFile.deleteSync();
  }
  return payload;
}
