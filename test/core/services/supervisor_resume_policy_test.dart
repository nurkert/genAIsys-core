import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/supervisor_resume_policy.dart';

const _now = '2026-01-15T00:00:00.000Z';

class _FakeDoneService extends DoneService {
  _FakeDoneService({required this.onMarkDone});

  final Future<String> Function(String projectRoot) onMarkDone;

  @override
  Future<String> markDone(String projectRoot, {bool force = false}) =>
      onMarkDone(projectRoot);
}

void main() {
  group('SupervisorResumePolicy', () {
    group('peekResumeAction', () {
      test('returns approved_delivery when review is approved and task active', () {
        final policy = SupervisorResumePolicy();
        final state = ProjectState(
          lastUpdated: _now,
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Do something',
            reviewStatus: 'approved',
          ),
        );

        expect(policy.peekResumeAction(state), 'approved_delivery');
      });

      test('returns continue_safe_step when no active task', () {
        final policy = SupervisorResumePolicy();
        final state = ProjectState(
          lastUpdated: _now,
          activeTask: const ActiveTaskState(reviewStatus: 'approved'),
        );

        expect(policy.peekResumeAction(state), 'continue_safe_step');
      });

      test('returns continue_safe_step when review not approved', () {
        final policy = SupervisorResumePolicy();
        final state = ProjectState(
          lastUpdated: _now,
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Do something',
            reviewStatus: 'rejected',
          ),
        );

        expect(policy.peekResumeAction(state), 'continue_safe_step');
      });

      test('returns continue_safe_step when review is null', () {
        final policy = SupervisorResumePolicy();
        final state = ProjectState(
          lastUpdated: _now,
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Do something',
          ),
        );

        expect(policy.peekResumeAction(state), 'continue_safe_step');
      });
    });

    group('apply', () {
      test('calls markDone when approved delivery exists', () async {
        final temp = Directory.systemTemp.createTempSync('resume_apply_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        var doneCalled = false;
        final policy = SupervisorResumePolicy(
          doneService: _FakeDoneService(
            onMarkDone: (_) async {
              doneCalled = true;
              return 'Task Alpha';
            },
          ),
        );

        final state = ProjectState(
          lastUpdated: _now,
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Task Alpha',
            reviewStatus: 'approved',
          ),
        );

        final result = await policy.apply(
          temp.path,
          state: state,
          sessionId: 'session-1',
        );

        expect(result, 'approved_delivery');
        expect(doneCalled, isTrue);

        final runLog = File(ProjectLayout(temp.path).runLogPath)
            .readAsStringSync();
        expect(runLog, contains('"resume_action":"approved_delivery"'));
      });

      test('returns continue_safe_step when no approved delivery', () async {
        final temp = Directory.systemTemp.createTempSync('resume_noop_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final policy = SupervisorResumePolicy();
        final state = ProjectState(lastUpdated: _now);

        final result = await policy.apply(
          temp.path,
          state: state,
          sessionId: 'session-1',
        );

        expect(result, 'continue_safe_step');
      });

      test('throws StateError when markDone fails', () async {
        final temp = Directory.systemTemp.createTempSync('resume_fail_');
        addTearDown(() => temp.deleteSync(recursive: true));
        ProjectInitializer(temp.path).ensureStructure(overwrite: true);

        final policy = SupervisorResumePolicy(
          doneService: _FakeDoneService(
            onMarkDone: (_) => throw StateError('Task not found'),
          ),
        );

        final state = ProjectState(
          lastUpdated: _now,
          activeTask: const ActiveTaskState(
            id: 'task-1',
            title: 'Task Alpha',
            reviewStatus: 'approved',
          ),
        );

        await expectLater(
          policy.apply(temp.path, state: state, sessionId: 'session-1'),
          throwsA(isA<StateError>()),
        );

        final runLog = File(ProjectLayout(temp.path).runLogPath)
            .readAsStringSync();
        expect(runLog, contains('autopilot_supervisor_resume_failed'));
      });
    });
  });
}
