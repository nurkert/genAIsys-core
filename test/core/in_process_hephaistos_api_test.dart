import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';

class _ThrowingDoneService extends DoneService {
  _ThrowingDoneService(this.error);

  final Object error;

  @override
  Future<String> markDone(String projectRoot, {bool force = false}) async {
    throw error;
  }
}

class _ThrowingTaskCycleService extends TaskCycleService {
  _ThrowingTaskCycleService(this.error);

  final Object error;

  @override
  Future<TaskCycleResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    bool isSubtask = false,
    String? subtaskDescription,
    int? maxReviewRetries,
  }) async {
    throw error;
  }
}

void main() {
  test('maps StateError with "not found" to AppErrorKind.notFound', () async {
    final api = InProcessGenaisysApi(
      doneService: _ThrowingDoneService(StateError('Task not found')),
    );

    final result = await api.markTaskDone('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.notFound);
    expect(result.error!.code, 'not_found');
  });

  test(
    'maps StateError with policy message to AppErrorKind.policyViolation',
    () async {
      final api = InProcessGenaisysApi(
        doneService: _ThrowingDoneService(
          StateError('Policy violation: safe_write prevented change'),
        ),
      );

      final result = await api.markTaskDone('/tmp/project');

      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.kind, AppErrorKind.policyViolation);
      expect(result.error!.code, 'policy_violation');
    },
  );

  test(
    'maps ArgumentError from service to AppErrorKind.invalidInput',
    () async {
      final api = InProcessGenaisysApi(
        taskCycleService: _ThrowingTaskCycleService(
          ArgumentError('Invalid task cycle input'),
        ),
      );

      final result = await api.runTaskCycle(
        '/tmp/project',
        prompt: 'Implement one step',
      );

      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.kind, AppErrorKind.invalidInput);
      expect(result.error!.code, 'invalid_input');
    },
  );

  test('empty prompt returns invalid input without calling services', () async {
    final api = InProcessGenaisysApi();

    final result = await api.runTaskCycle('/tmp/project', prompt: '   ');

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.invalidInput);
  });

  test(
    'maps StateError with conflict message to AppErrorKind.conflict',
    () async {
      final api = InProcessGenaisysApi(
        doneService: _ThrowingDoneService(
          StateError('Task title already exists'),
        ),
      );

      final result = await api.markTaskDone('/tmp/project');

      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.kind, AppErrorKind.conflict);
      expect(result.error!.code, 'conflict');
    },
  );

  test('maps FileSystemException to AppErrorKind.ioFailure', () async {
    final api = InProcessGenaisysApi(
      doneService: _ThrowingDoneService(FileSystemException('Disk error')),
    );

    final result = await api.markTaskDone('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.kind, AppErrorKind.ioFailure);
    expect(result.error!.code, 'io_failure');
  });
}
