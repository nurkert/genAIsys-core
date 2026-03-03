import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/project_initializer.dart';

/// Tests stale lock recovery: when a lock file has a dead PID, the autopilot
/// should recover it with `pid_not_alive` reason logged, and proceed normally.
void main() {
  group('Stale lock recovery', () {
    late Directory temp;
    late String projectRoot;
    late ProjectLayout layout;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('heph_stale_lock_');
      projectRoot = temp.path;
      layout = ProjectLayout(projectRoot);

      // Initialize project structure.
      ProjectInitializer(projectRoot).ensureStructure(overwrite: true);

      // Write a valid STATE.json.
      StateStore(layout.statePath).write(
        ProjectState(lastUpdated: DateTime.now().toUtc().toIso8601String()),
      );
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('lock with dead PID is recovered with pid_not_alive reason', () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      // Use a PID that is guaranteed to be dead.
      // PID 999999 is extremely unlikely to be in use.
      const deadPid = 999999;
      final now = DateTime.now().toUtc().toIso8601String();
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=$now\n'
        'last_heartbeat=$now\n'
        'pid=$deadPid\n',
      );

      expect(lockFile.existsSync(), isTrue);

      // Status check should trigger lock recovery.
      final runService = OrchestratorRunService(sleep: (_) async {});
      final status = runService.getStatus(projectRoot);

      // Lock should have been recovered (deleted).
      expect(
        lockFile.existsSync(),
        isFalse,
        reason: 'Lock with dead PID should be recovered (deleted)',
      );

      // Status should show not running.
      expect(status.isRunning, isFalse);

      // Run log should contain recovery event with metadata.
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(
        runLog,
        contains('orchestrator_run_lock_recovered'),
        reason: 'Run log must record lock recovery event',
      );
      expect(
        runLog,
        contains('pid_not_alive'),
        reason: 'Recovery reason must be pid_not_alive',
      );
      expect(
        runLog,
        contains('$deadPid'),
        reason: 'Lock metadata should include the dead PID',
      );
    });

    test('lock with dead PID allows subsequent autopilot status check', () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      const deadPid = 999998;
      final now = DateTime.now().toUtc().toIso8601String();
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=$now\n'
        'last_heartbeat=$now\n'
        'pid=$deadPid\n',
      );

      final runService = OrchestratorRunService(sleep: (_) async {});

      // First call recovers the lock.
      runService.getStatus(projectRoot);
      expect(lockFile.existsSync(), isFalse);

      // Second call should succeed without issues.
      final status = runService.getStatus(projectRoot);
      expect(status.isRunning, isFalse);
    });

    test('recovery event contains lock metadata', () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      const deadPid = 999997;
      final startedAt = '2026-01-15T10:30:00.000Z';
      final heartbeat = '2026-01-15T10:35:00.000Z';
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=$startedAt\n'
        'last_heartbeat=$heartbeat\n'
        'pid=$deadPid\n',
      );

      final runService = OrchestratorRunService(sleep: (_) async {});
      runService.getStatus(projectRoot);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('lock_recovered'));
      expect(runLog, contains('pid_not_alive'));
      expect(runLog, contains('$deadPid'));
      expect(runLog, contains('locking'));
    });

    test('lock without PID but expired TTL is recovered as ttl_expired', () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      // Write a lock with a very old heartbeat and no PID.
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=2020-01-01T00:00:00.000Z\n'
        'last_heartbeat=2020-01-01T00:00:00.000Z\n',
      );

      final runService = OrchestratorRunService(sleep: (_) async {});
      runService.getStatus(projectRoot);

      // Lock should have been recovered.
      expect(lockFile.existsSync(), isFalse);

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('lock_recovered'));
      expect(runLog, contains('ttl_expired'));
    });
  });

  group('TOCTOU PID-reuse protection (Fix 8)', () {
    late Directory temp;
    late String projectRoot;
    late ProjectLayout layout;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('heph_toctou_');
      projectRoot = temp.path;
      layout = ProjectLayout(projectRoot);
      ProjectInitializer(projectRoot).ensureStructure(overwrite: true);
      StateStore(layout.statePath).write(
        ProjectState(lastUpdated: DateTime.now().toUtc().toIso8601String()),
      );
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test(
        'lock with our PID and matching started_at is not recovered (our own lock)',
        () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      // The current test process PID.
      final ourPid = pid;
      // Use a specific timestamp as our process's started_at.
      final ourStartedAt = DateTime.utc(2026, 2, 27, 10, 0, 0);
      final ourStartedAtStr = ourStartedAt.toIso8601String();

      // Write a lock that matches OUR pid AND our started_at timestamp.
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=$ourStartedAtStr\n'
        'last_heartbeat=$ourStartedAtStr\n'
        'pid=$ourPid\n',
      );

      // Inject the matching started_at so service treats this as our own lock.
      final runService = OrchestratorRunService(
        sleep: (_) async {},
        thisProcessStartedAt: ourStartedAt,
      );
      runService.getStatus(projectRoot);

      // Lock must NOT be recovered — it's our own active lock.
      expect(
        lockFile.existsSync(),
        isTrue,
        reason: 'Our own lock (matching started_at) must not be recovered',
      );
    });

    test(
        'lock with our PID but different started_at is recovered as pid_reused',
        () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      final ourPid = pid;
      // The lock was written by an older process with the same PID.
      final oldStartedAt = DateTime.utc(2025, 1, 1, 0, 0, 0);
      final oldStartedAtStr = oldStartedAt.toIso8601String();
      // Our current service started much later.
      final ourStartedAt = DateTime.utc(2026, 2, 27, 12, 0, 0);

      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=$oldStartedAtStr\n'
        'last_heartbeat=$oldStartedAtStr\n'
        'pid=$ourPid\n',
      );

      final runService = OrchestratorRunService(
        sleep: (_) async {},
        thisProcessStartedAt: ourStartedAt,
      );
      runService.getStatus(projectRoot);

      // Lock must be recovered — PID was recycled.
      expect(
        lockFile.existsSync(),
        isFalse,
        reason: 'Recycled-PID lock must be recovered',
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('lock_recovered'));
      expect(runLog, contains('pid_reused'));
    });

    test('lock with dead PID is recovered regardless of started_at', () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      const deadPid = 999994;
      final now = DateTime.now().toUtc().toIso8601String();
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=$now\n'
        'last_heartbeat=$now\n'
        'pid=$deadPid\n',
      );

      final runService = OrchestratorRunService(sleep: (_) async {});
      runService.getStatus(projectRoot);

      expect(lockFile.existsSync(), isFalse);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('pid_not_alive'));
    });
  });
}
