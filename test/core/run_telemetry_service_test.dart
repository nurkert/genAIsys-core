import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/observability/run_telemetry_service.dart';

void main() {
  test('RunTelemetryService classifies no diff errors', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'task_cycle_no_diff',
      message: 'No diff produced by coding agent',
      data: const {'error_kind': 'no_diff'},
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'review');
    expect(snapshot.errorKind, 'no_diff');
    expect(snapshot.errorMessage, 'No diff produced by coding agent');
  });

  test('RunTelemetryService preserves event and correlation identifiers', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'orchestrator_run_step',
      message: 'Step completed',
      eventId: 'evt-123',
      correlationId: 'step_id:step-9|task_id:task-alpha',
      correlation: const {
        'task_id': 'task-alpha',
        'subtask_id': 'subtask-a',
        'step_id': 'step-9',
      },
      data: const {
        'task_id': 'task-alpha',
        'subtask_id': 'subtask-a',
        'step_id': 'step-9',
      },
    );

    final snapshot = RunTelemetryService().load(root);
    final event = snapshot.recentEvents.single;

    expect(event.eventId, 'evt-123');
    expect(event.correlationId, 'step_id:step-9|task_id:task-alpha');
    expect(event.correlation?['step_id'], 'step-9');
    expect(event.correlation?['task_id'], 'task-alpha');
  });

  test('RunTelemetryService classifies review rejects', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'review_reject',
      message: 'Review decision recorded',
      data: const {'note': 'Needs refinement before merge.'},
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'review');
    expect(snapshot.errorKind, 'review_rejected');
    expect(snapshot.errorMessage, 'Needs refinement before merge.');
  });

  test('RunTelemetryService classifies policy violations', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'orchestrator_run_error',
      message: 'Autopilot run step failed',
      data: const {
        'error': 'Policy violation: safe_write blocked ".git/HEAD".',
      },
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'policy');
    expect(snapshot.errorKind, 'policy_violation');
    expect(snapshot.errorMessage, contains('safe_write blocked'));
  });

  test('RunTelemetryService classifies analyze failures from quality gate', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'review_reject',
      message: 'Review decision recorded',
      data: const {
        'note':
            'Quality gate failed before review.\n'
            'Policy violation: quality_gate command failed (exit 1): '
            '"dart analyze".',
      },
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'quality_gate');
    expect(snapshot.errorKind, 'analyze_failed');
    expect(snapshot.errorMessage, contains('dart analyze'));
  });

  test('RunTelemetryService classifies test failures from quality gate', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'review_reject',
      message: 'Review decision recorded',
      data: const {
        'note':
            'Quality gate failed before review.\n'
            'Policy violation: quality_gate command failed (exit 1): '
            '"flutter test".',
      },
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'quality_gate');
    expect(snapshot.errorKind, 'test_failed');
    expect(snapshot.errorMessage, contains('flutter test'));
  });

  test(
    'RunTelemetryService does not misclassify review rejects that mention quality gate config',
    () {
      final root = _createProjectRoot();
      _appendEvent(
        root,
        event: 'review_reject',
        message: 'Review decision recorded',
        data: const {
          'note':
              'Findings:\n'
              '- Policy health is missing (quality gate config, allowlists).\n'
              '- Evidence gap: add `dart analyze` and `flutter test` output.\n',
        },
      );

      final snapshot = RunTelemetryService().load(root);

      expect(snapshot.errorClass, 'review');
      expect(snapshot.errorKind, 'review_rejected');
      expect(snapshot.errorMessage, contains('Policy health'));
    },
  );

  test('RunTelemetryService classifies provider quota pauses', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'orchestrator_run_provider_pause',
      message: 'Autopilot paused due to provider quota exhaustion',
      data: const {
        'error': 'Provider pool exhausted by quota limits.',
        'error_kind': 'provider_quota',
      },
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'provider');
    expect(snapshot.errorKind, 'provider_quota');
    expect(snapshot.errorMessage, contains('quota'));
  });

  test('RunTelemetryService falls back to unknown for unmapped errors', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'orchestrator_run_error',
      message: 'Autopilot run step failed',
      data: const {'error': 'Unexpected edge-case condition.'},
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'unknown');
    expect(snapshot.errorKind, 'unknown');
    expect(snapshot.errorMessage, contains('Unexpected edge-case'));
  });

  test('RunTelemetryService classifies merge conflict manual intervention', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'merge_conflict_manual',
      message: 'Manual intervention required',
      data: const {
        'error_class': 'delivery',
        'error_kind': 'merge_conflict_manual_required',
        'error': 'Manual intervention required: merge conflict.',
      },
    );

    final snapshot = RunTelemetryService().load(root);

    expect(snapshot.errorClass, 'delivery');
    expect(snapshot.errorKind, 'merge_conflict_manual_required');
    expect(snapshot.errorMessage, contains('merge conflict'));
  });

  test(
    'RunTelemetryService builds failure trend summary with dominant error kind',
    () {
      final root = _createProjectRoot();
      final now = DateTime.now().toUtc();
      _appendEvent(
        root,
        event: 'review_reject',
        message: 'Rejected by review',
        data: const {'note': 'Needs changes'},
        timestamp: now.subtract(const Duration(minutes: 5)),
      );
      _appendEvent(
        root,
        event: 'review_reject',
        message: 'Rejected by review',
        data: const {'note': 'Still failing'},
        timestamp: now.subtract(const Duration(minutes: 4)),
      );
      _appendEvent(
        root,
        event: 'task_cycle_no_diff',
        message: 'No diff produced by coding agent',
        data: const {'error_kind': 'no_diff'},
        timestamp: now.subtract(const Duration(minutes: 20)),
      );

      final snapshot = RunTelemetryService().load(root);
      final trend = snapshot.healthSummary.failureTrend;

      expect(trend.direction, 'rising');
      expect(trend.recentFailures, 2);
      expect(trend.previousFailures, 1);
      expect(trend.windowSeconds, 900);
      expect(trend.sampleSize, greaterThanOrEqualTo(3));
      expect(trend.dominantErrorKind, 'review_rejected');
    },
  );

  test('RunTelemetryService builds retry distribution summary', () {
    final root = _createProjectRoot();
    _appendEvent(
      root,
      event: 'orchestrator_run_step',
      message: 'Step completed',
      data: const {'retry_count': 0},
    );
    _appendEvent(
      root,
      event: 'orchestrator_run_step',
      message: 'Step completed',
      data: const {'retry_count': 1},
    );
    _appendEvent(
      root,
      event: 'orchestrator_run_step',
      message: 'Step completed',
      data: const {'retry_count': 2},
    );
    _appendEvent(
      root,
      event: 'orchestrator_run_step',
      message: 'Step completed',
      data: const {'retry_count': 4},
    );

    final snapshot = RunTelemetryService().load(root);
    final retries = snapshot.healthSummary.retryDistribution;

    expect(retries.samples, 4);
    expect(retries.retry0, 1);
    expect(retries.retry1, 1);
    expect(retries.retry2Plus, 2);
    expect(retries.maxRetry, 4);
  });

  test('RunTelemetryService exposes cooldown visibility from run logs', () {
    final root = _createProjectRoot();
    final now = DateTime.now().toUtc();
    _appendEvent(
      root,
      event: 'preflight_failed',
      message: 'Autopilot preflight blocked step execution',
      data: const {
        'error_class': 'delivery',
        'error_kind': 'git_dirty',
        'backoff_seconds': 90,
      },
      timestamp: now.subtract(const Duration(seconds: 10)),
    );

    final snapshot = RunTelemetryService().load(root);
    final cooldown = snapshot.healthSummary.cooldown;

    expect(cooldown.active, isTrue);
    expect(cooldown.totalSeconds, 90);
    expect(cooldown.remainingSeconds, greaterThan(0));
    expect(cooldown.remainingSeconds, lessThanOrEqualTo(90));
    expect(cooldown.sourceEvent, 'preflight_failed');
    expect(cooldown.reason, 'git_dirty');
    expect(cooldown.until, isNotNull);
  });

  test('RunTelemetryService marks expired cooldown as inactive', () {
    final root = _createProjectRoot();
    final now = DateTime.now().toUtc();
    _appendEvent(
      root,
      event: 'orchestrator_run_progress_failure',
      message: 'Autopilot step ended without progress',
      data: const {
        'error_class': 'review',
        'error_kind': 'review_rejected',
        'cooldown_seconds': 30,
      },
      timestamp: now.subtract(const Duration(minutes: 2)),
    );

    final snapshot = RunTelemetryService().load(root);
    final cooldown = snapshot.healthSummary.cooldown;

    expect(cooldown.active, isFalse);
    expect(cooldown.totalSeconds, 30);
    expect(cooldown.remainingSeconds, 0);
    expect(cooldown.sourceEvent, 'orchestrator_run_progress_failure');
    expect(cooldown.reason, 'review_rejected');
    expect(cooldown.until, isNotNull);
  });
}

String _createProjectRoot() {
  final temp = Directory.systemTemp.createTempSync('genaisys_telemetry_');
  addTearDown(() {
    temp.deleteSync(recursive: true);
  });
  ProjectInitializer(temp.path).ensureStructure(overwrite: true);
  return temp.path;
}

void _appendEvent(
  String root, {
  required String event,
  required String message,
  String? eventId,
  String? correlationId,
  Map<String, Object?>? correlation,
  Map<String, Object?>? data,
  DateTime? timestamp,
}) {
  final layout = ProjectLayout(root);
  final payload = <String, Object?>{
    'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
    'event': event,
    'message': message,
    'event_id': ?eventId,
    'correlation_id': ?correlationId,
    'correlation': ?correlation,
    'data': ?data,
  };
  File(
    layout.runLogPath,
  ).writeAsStringSync('${jsonEncode(payload)}\n', mode: FileMode.append);
}
