import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/health_snapshot.dart';
import 'package:genaisys/core/models/run_log_event.dart';
import 'package:genaisys/core/models/workflow_stage.dart';
import 'package:genaisys/core/services/observability/health_check_service.dart';
import 'package:genaisys/core/services/observability/run_telemetry_service.dart';
import 'package:genaisys/core/services/observability/status_service.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../../support/builders.dart';
import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_status_svc_');
    workspace.ensureStructure();
  });

  tearDown(() => workspace.dispose());

  test('status with active task shows correct counts and fields', () {
    // Write tasks: 2 open, 1 done.
    workspace.writeTasks('''
## Backlog
- [ ] [P1] [CORE] Open task A
- [ ] [P2] [QA] Open task B
- [x] [P1] [CORE] Done task C
''');

    // Set active task.
    final state = ProjectStateBuilder()
        .withActiveTask('open-task-a-2', 'Open task A')
        .withWorkflowStage(WorkflowStage.execution)
        .withCycleCount(3)
        .build();
    StateStore(workspace.layout.statePath).write(state);

    final service = StatusService(
      healthService: _FakeHealthCheckService(),
      telemetryService: _FakeRunTelemetryService(),
    );
    final snapshot = service.getStatus(workspace.root.path);

    expect(snapshot.tasksTotal, 3);
    expect(snapshot.tasksOpen, 2);
    expect(snapshot.tasksDone, 1);
    expect(snapshot.tasksBlocked, 0);
    expect(snapshot.activeTaskTitle, 'Open task A');
    expect(snapshot.activeTaskLabel, 'Open task A');
    expect(snapshot.workflowStage, WorkflowStage.execution);
    expect(snapshot.cycleCount, 3);
  });

  test('status with no active task returns idle labels', () {
    final state = ProjectStateBuilder().withNoActiveTask().build();
    StateStore(workspace.layout.statePath).write(state);

    final service = StatusService(
      healthService: _FakeHealthCheckService(),
      telemetryService: _FakeRunTelemetryService(),
    );
    final snapshot = service.getStatus(workspace.root.path);

    expect(snapshot.activeTaskTitle, isNull);
    expect(snapshot.activeTaskLabel, '(none)');
    expect(snapshot.activeTaskIdLabel, '(none)');
    expect(snapshot.workflowStage, WorkflowStage.idle);
  });

  test('status reflects edge states (rejected, failures, errors)', () {
    final state = ProjectStateBuilder()
        .withActiveTask('task-1', 'My Task')
        .withReview('rejected')
        .withConsecutiveFailures(3)
        .withLastError(
          error: 'safe_write violation',
          errorClass: 'policy',
          errorKind: 'safe_write',
        )
        .build();
    StateStore(workspace.layout.statePath).write(state);

    final service = StatusService(
      healthService: _FakeHealthCheckService(),
      telemetryService: _FakeRunTelemetryService(),
    );
    final snapshot = service.getStatus(workspace.root.path);

    expect(snapshot.reviewStatus, 'rejected');
    expect(snapshot.reviewStatusLabel, 'rejected');
    expect(snapshot.lastError, 'safe_write violation');
    expect(snapshot.lastErrorClass, 'policy');
    expect(snapshot.lastErrorKind, 'safe_write');
  });

  test('status throws on missing .genaisys directory', () {
    final bare = Directory.systemTemp.createTempSync('genaisys_bare_');
    addTearDown(() => bare.deleteSync(recursive: true));

    final service = StatusService(
      healthService: _FakeHealthCheckService(),
      telemetryService: _FakeRunTelemetryService(),
    );

    expect(
      () => service.getStatus(bare.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No .genaisys directory found'),
        ),
      ),
    );
  });
}

// ---------------------------------------------------------------------------
// Inline fakes
// ---------------------------------------------------------------------------

class _FakeHealthCheckService extends HealthCheckService {
  @override
  HealthSnapshot check(String projectRoot, {Map<String, String>? environment}) {
    return HealthSnapshot(
      agent: HealthCheck(ok: true, message: 'Agent available'),
      allowlist: HealthCheck(ok: true, message: 'Allowlist valid'),
      git: HealthCheck(ok: true, message: 'Git clean'),
      review: HealthCheck(ok: true, message: 'Review clear'),
    );
  }
}

class _FakeRunTelemetryService extends RunTelemetryService {
  @override
  RunTelemetrySnapshot load(String projectRoot, {int recentLimit = 5}) {
    return RunTelemetrySnapshot(recentEvents: const <RunLogEvent>[]);
  }
}
