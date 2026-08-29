import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/supervisor_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/supervisor_health_reporter.dart';

void main() {
  group('SupervisorHealthReporter', () {
    group('writeHeartbeat', () {
      test('writes timestamp to heartbeat file', () {
        final temp = Directory.systemTemp.createTempSync('heartbeat_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final reporter = SupervisorHealthReporter();
        final now = DateTime.utc(2026, 1, 15, 12, 30);
        reporter.writeHeartbeat(temp.path, now: now);

        final content = File(ProjectLayout(temp.path).heartbeatPath)
            .readAsStringSync();
        expect(content, contains('2026-01-15'));
      });

      test('does not throw on missing directory', () {
        final reporter = SupervisorHealthReporter();
        // Should not throw even for a nonexistent path.
        reporter.writeHeartbeat('/tmp/nonexistent-${DateTime.now().millisecondsSinceEpoch}', now: DateTime.now());
      });
    });

    group('writeExitSummary', () {
      test('writes structured exit summary JSON', () {
        final temp = Directory.systemTemp.createTempSync('exit_summary_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final reporter = SupervisorHealthReporter();
        final startedAt = DateTime.utc(2026, 1, 15, 10, 0);
        final now = DateTime.utc(2026, 1, 15, 12, 0);

        reporter.writeExitSummary(
          temp.path,
          sessionId: 'session-123',
          haltReason: 'progress_watchdog',
          exitCode: 0,
          restartCount: 2,
          segmentsCompleted: 15,
          lowSignalStreak: 3,
          startedAt: startedAt,
          now: now,
          supervisorState: const SupervisorState(
            throughputWindowStartedAt: '2026-01-15T10:30:00.000Z',
            throughputSteps: 50,
            throughputRejects: 5,
            throughputHighRetries: 2,
          ),
        );

        final path = ProjectLayout(temp.path).exitSummaryPath;
        expect(File(path).existsSync(), isTrue);
        final data = jsonDecode(File(path).readAsStringSync()) as Map;
        expect(data['session_id'], 'session-123');
        expect(data['halt_reason'], 'progress_watchdog');
        expect(data['segments_completed'], 15);
        expect(data['uptime_seconds'], 7200);
        expect(data['throughput_snapshot']['steps'], 50);
      });
    });

    group('exportHealthSummary', () {
      test('delegates to health summary exporter without throwing', () {
        final temp = Directory.systemTemp.createTempSync('health_export_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final reporter = SupervisorHealthReporter();
        // Should not throw.
        reporter.exportHealthSummary(
          temp.path,
          sessionId: 'session-1',
          profile: 'pilot',
          pid: 1234,
          startedAt: DateTime.utc(2026, 1, 15),
          totalSteps: 10,
          consecutiveFailures: 0,
          lastHaltReason: null,
          status: 'running',
        );

        final path = ProjectLayout(temp.path).healthSummaryPath;
        expect(File(path).existsSync(), isTrue);
        final data = jsonDecode(File(path).readAsStringSync()) as Map;
        expect(data['status'], 'running');
        expect(data['session_id'], 'session-1');
      });
    });
  });
}
