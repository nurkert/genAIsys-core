import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/orchestrator_run_service.dart';
import 'package:genaisys/core/services/architecture_planning_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/vision_evaluation_service.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/project_initializer.dart';

/// Tests lock contention: when one autopilot run holds the lock, a second
/// attempt must detect the lock and refuse to proceed.
void main() {
  group('Lock contention', () {
    late Directory temp;
    late String projectRoot;
    late ProjectLayout layout;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('heph_lock_contention_');
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

    test('second run detects held lock and throws StateError', () {
      // Manually acquire a lock file with the current PID to simulate
      // a running autopilot.
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);
      final raf = lockFile.openSync(mode: FileMode.write);
      try {
        raf.lockSync(FileLock.exclusive);
      } on FileSystemException {
        raf.closeSync();
        fail('Could not acquire exclusive lock for test setup');
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final currentPid = pid;
      raf.writeStringSync(
        'version=1\n'
        'started_at=$now\n'
        'last_heartbeat=$now\n'
        'pid=$currentPid\n'
        'project_root=$projectRoot\n',
      );
      raf.flushSync();

      // Attempting to start a second run should fail with a StateError
      // because the lock file exists and its PID is alive.
      final runService = OrchestratorRunService(
        stepService: OrchestratorStepService(
          architecturePlanningService: _NoopArchitecturePlanningService(),
          visionEvaluationService: _NoopVisionEvaluationService(),
        ),
        sleep: (_) async {},
      );

      expect(
        () async => runService.run(
          projectRoot,
          codingPrompt: 'test',
          maxSteps: 1,
          stopWhenIdle: true,
          stepSleep: Duration.zero,
          idleSleep: Duration.zero,
        ),
        throwsA(isA<StateError>()),
        reason:
            'A second autopilot run must throw StateError when a lock is held',
      );

      // Clean up the held lock.
      try {
        raf.unlockSync();
      } catch (_) {}
      try {
        raf.closeSync();
      } catch (_) {}
      try {
        if (lockFile.existsSync()) {
          lockFile.deleteSync();
        }
      } catch (_) {}
    });

    test('lock file with alive PID is NOT recovered', () {
      final lockDir = Directory(layout.locksDir);
      lockDir.createSync(recursive: true);
      final lockFile = File(layout.autopilotLockPath);

      // Write a lock with the current process PID (which is alive).
      final now = DateTime.now().toUtc().toIso8601String();
      final currentPid = pid;
      lockFile.writeAsStringSync(
        'version=1\n'
        'started_at=$now\n'
        'last_heartbeat=$now\n'
        'pid=$currentPid\n',
      );

      // Status check should show the lock is active.
      final runService = OrchestratorRunService(sleep: (_) async {});
      final status = runService.getStatus(projectRoot);

      // The lock should still exist after status check (not recovered).
      expect(
        lockFile.existsSync(),
        isTrue,
        reason: 'Lock with alive PID should not be recovered',
      );
      expect(status.pid, currentPid);
    });
  });
}

class _NoopArchitecturePlanningService extends ArchitecturePlanningService {
  @override
  Future<ArchitecturePlanningResult?> planArchitecture(
    String projectRoot,
  ) async {
    return null;
  }
}

class _NoopVisionEvaluationService extends VisionEvaluationService {
  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    return null;
  }
}
