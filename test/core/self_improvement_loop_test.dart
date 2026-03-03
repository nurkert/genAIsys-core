import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/insight_driven_task_service.dart';
import 'package:genaisys/core/services/prompt_effectiveness_service.dart';
import 'package:genaisys/core/services/retrospective_service.dart';
import 'package:genaisys/core/services/observability/run_log_insight_service.dart';
import 'package:genaisys/core/storage/run_log_store.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_selfimprove_');
    layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    Directory(layout.auditDir).createSync(recursive: true);
    // Create an empty TASKS.md for task creation.
    File(layout.tasksPath).writeAsStringSync('# Backlog\n');
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('RetrospectiveService', () {
    late RetrospectiveService service;

    setUp(() {
      service = RetrospectiveService();
    });

    test('returns empty list when no run log exists', () {
      final result = service.collect(temp.path);
      expect(result, isEmpty);
    });

    test('collects task_done events', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(
        event: 'task_done',
        message: 'Marked task as done',
        data: {'task': 'Implement feature A'},
      );

      final result = service.collect(temp.path);
      expect(result, hasLength(1));
      expect(result.first.task, 'Implement feature A');
      expect(result.first.outcome, 'done');
      expect(result.first.retryCount, 0);
    });

    test('collects task_dead_letter events', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(
        event: 'task_dead_letter',
        message: 'Quarantined',
        data: {
          'task': 'Fix bug B',
          'task_id': 'bug-b-1',
          'blocking_stage': 'review_reject',
          'retry_count': 3,
          'last_error_kind': 'review_rejected',
        },
      );

      final result = service.collect(temp.path);
      expect(result, hasLength(1));
      expect(result.first.outcome, 'blocked');
      expect(result.first.retryCount, 3);
      expect(result.first.blockingStage, 'review_reject');
      expect(result.first.errorKind, 'review_rejected');
    });

    test('skips auto-cycle task_blocked to avoid duplicating dead-letters', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(
        event: 'task_blocked',
        message: 'Blocked',
        data: {
          'task': 'Fix bug B',
          'reason': 'Auto-cycle: review rejected 3 time(s)',
        },
      );

      final result = service.collect(temp.path);
      expect(result, isEmpty);
    });

    test('collects manual task_blocked events', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(
        event: 'task_blocked',
        message: 'Blocked',
        data: {'task': 'Manual block', 'reason': 'User blocked'},
      );

      final result = service.collect(temp.path);
      expect(result, hasLength(1));
      expect(result.first.outcome, 'blocked');
    });

    test('summarize computes aggregate statistics', () {
      final retrospectives = [
        const TaskRetrospective(task: 'A', outcome: 'done', retryCount: 0),
        const TaskRetrospective(task: 'B', outcome: 'done', retryCount: 1),
        const TaskRetrospective(
          task: 'C',
          outcome: 'blocked',
          retryCount: 3,
          blockingStage: 'review_reject',
          errorKind: 'review_rejected',
        ),
        const TaskRetrospective(
          task: 'D',
          outcome: 'blocked',
          retryCount: 2,
          blockingStage: 'no_diff',
        ),
      ];

      final summary = service.summarize(retrospectives);
      expect(summary.totalTasks, 4);
      expect(summary.completedTasks, 2);
      expect(summary.blockedTasks, 2);
      expect(summary.completionRate, 0.5);
      expect(summary.blockRate, 0.5);
      expect(summary.averageRetries, 1.5);
      expect(summary.topBlockingStages, hasLength(2));
      expect(
        summary.topBlockingStages.first.key,
        isIn(['review_reject', 'no_diff']),
      );
    });

    test('analyze persists retrospective_analysis event to run log', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(event: 'task_done', message: 'Done', data: {'task': 'X'});

      service.analyze(temp.path);

      final lines = File(layout.runLogPath).readAsLinesSync();
      final hasEvent = lines.any((l) => l.contains('retrospective_analysis'));
      expect(hasEvent, isTrue);
    });
  });

  group('RunLogInsightService', () {
    late RunLogInsightService service;

    setUp(() {
      service = RunLogInsightService();
    });

    test('returns empty insights when no run log exists', () {
      final result = service.analyze(temp.path);
      expect(result.totalEvents, 0);
      expect(result.stepSuccessRate, 0.0);
    });

    test('counts orchestrator steps and failures', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(event: 'orchestrator_run_step', message: 'Step', data: {});
      store.append(event: 'orchestrator_run_step', message: 'Step', data: {});
      store.append(
        event: 'orchestrator_run_step',
        message: 'Idle',
        data: {'idle': true},
      );
      store.append(
        event: 'orchestrator_run_error',
        message: 'Error',
        data: {'error_kind': 'timeout', 'error_class': 'pipeline'},
      );

      final result = service.analyze(temp.path);
      expect(result.successfulSteps, 2);
      expect(result.idleSteps, 1);
      expect(result.failedSteps, 1);
      expect(result.stepSuccessRate, closeTo(0.67, 0.01));
      expect(result.errorKindCounts['timeout'], 1);
      expect(result.errorClassCounts['pipeline'], 1);
    });

    test('counts review decisions', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(event: 'review_approve', message: 'Approved', data: {});
      store.append(event: 'review_approve', message: 'Approved', data: {});
      store.append(event: 'review_reject', message: 'Rejected', data: {});

      final result = service.analyze(temp.path);
      expect(result.reviewApprovals, 2);
      expect(result.reviewRejections, 1);
      expect(result.reviewApprovalRate, closeTo(0.67, 0.01));
    });

    test('counts task outcomes and dead letters', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(event: 'task_done', message: 'Done', data: {});
      store.append(event: 'task_done', message: 'Done', data: {});
      store.append(event: 'task_blocked', message: 'Blocked', data: {});
      store.append(
        event: 'task_dead_letter',
        message: 'Quarantined',
        data: {'error_kind': 'dead_letter'},
      );

      final result = service.analyze(temp.path);
      expect(result.tasksCompleted, 2);
      expect(result.tasksBlocked, 1);
      expect(result.deadLetterCount, 1);
    });

    test('counts provider quota hits and blocks', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(
        event: 'provider_pool_quota_hit',
        message: 'Quota',
        data: {'provider': 'codex'},
      );
      store.append(
        event: 'provider_pool_quota_hit',
        message: 'Quota',
        data: {'provider': 'codex'},
      );
      store.append(
        event: 'unattended_provider_blocked',
        message: 'Blocked',
        data: {},
      );

      final result = service.analyze(temp.path);
      expect(result.providerQuotaHits, 2);
      expect(result.providerBlocks, 1);
      expect(result.providerFailureCounts['codex'], 2);
    });
  });

  group('PromptEffectivenessService', () {
    late PromptEffectivenessService service;

    setUp(() {
      service = PromptEffectivenessService();
    });

    test('returns empty report when no run log exists', () {
      final report = service.analyze(temp.path);
      expect(report.overallCycles, 0);
      expect(report.personaMetrics, isEmpty);
    });

    test('tracks per-persona approval rates', () {
      final store = RunLogStore(layout.runLogPath);

      // General persona: 2 approvals, 1 rejection.
      store.append(
        event: 'task_cycle_start',
        message: 'Start',
        data: {'review_persona': 'general'},
      );
      store.append(
        event: 'task_cycle_end',
        message: 'End',
        data: {'review_decision': 'approve', 'task_blocked': false},
      );
      store.append(
        event: 'task_cycle_start',
        message: 'Start',
        data: {'review_persona': 'general'},
      );
      store.append(
        event: 'task_cycle_end',
        message: 'End',
        data: {'review_decision': 'approve', 'task_blocked': false},
      );
      store.append(
        event: 'task_cycle_start',
        message: 'Start',
        data: {'review_persona': 'general'},
      );
      store.append(
        event: 'task_cycle_end',
        message: 'End',
        data: {'review_decision': 'reject', 'task_blocked': false},
      );

      // Security persona: 1 approval.
      store.append(
        event: 'task_cycle_start',
        message: 'Start',
        data: {'review_persona': 'security'},
      );
      store.append(
        event: 'task_cycle_end',
        message: 'End',
        data: {'review_decision': 'approve', 'task_blocked': false},
      );

      final report = service.analyze(temp.path);
      expect(report.overallCycles, 4);
      expect(report.overallApprovalRate, 0.75);

      final general = report.personaMetrics['general']!;
      expect(general.approvals, 2);
      expect(general.rejections, 1);
      expect(general.totalCycles, 3);
      expect(general.approvalRate, closeTo(0.67, 0.01));

      final security = report.personaMetrics['security']!;
      expect(security.approvals, 1);
      expect(security.totalCycles, 1);
      expect(security.approvalRate, 1.0);
    });

    test('counts no-diff cycles', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(
        event: 'task_cycle_start',
        message: 'Start',
        data: {'review_persona': 'general'},
      );
      store.append(
        event: 'task_cycle_end',
        message: 'End',
        data: {'review_decision': '', 'task_blocked': false},
      );

      final report = service.analyze(temp.path);
      final general = report.personaMetrics['general']!;
      expect(general.noDiffs, 1);
      expect(general.approvals, 0);
    });

    test('analyzeAndLog persists event to run log', () {
      final store = RunLogStore(layout.runLogPath);
      store.append(
        event: 'task_cycle_start',
        message: 'Start',
        data: {'review_persona': 'general'},
      );
      store.append(
        event: 'task_cycle_end',
        message: 'End',
        data: {'review_decision': 'approve'},
      );

      service.analyzeAndLog(temp.path);

      final lines = File(layout.runLogPath).readAsLinesSync();
      final hasEvent = lines.any(
        (l) => l.contains('prompt_effectiveness_analysis'),
      );
      expect(hasEvent, isTrue);
    });
  });

  group('InsightDrivenTaskService', () {
    late InsightDrivenTaskService service;

    setUp(() {
      service = InsightDrivenTaskService();
    });

    test('generates no tasks when metrics are below thresholds', () {
      // Empty run log → no insights → no tasks.
      final result = service.generate(temp.path);
      expect(result.created, 0);
      expect(result.reasons, isEmpty);
    });

    test('generates task for high block rate', () {
      final store = RunLogStore(layout.runLogPath);
      // 4 tasks: 1 done, 3 blocked → 75% block rate.
      store.append(event: 'task_done', message: 'Done', data: {'task': 'A'});
      store.append(
        event: 'task_dead_letter',
        message: 'Q',
        data: {
          'task': 'B',
          'blocking_stage': 'review_reject',
          'retry_count': 3,
        },
      );
      store.append(
        event: 'task_dead_letter',
        message: 'Q',
        data: {'task': 'C', 'blocking_stage': 'no_diff', 'retry_count': 2},
      );
      store.append(
        event: 'task_dead_letter',
        message: 'Q',
        data: {
          'task': 'D',
          'blocking_stage': 'review_reject',
          'retry_count': 3,
        },
      );

      final result = service.generate(temp.path);
      expect(result.created, greaterThan(0));
      expect(result.reasons.any((r) => r.contains('Block rate')), isTrue);
    });

    test('generates task for low review approval rate', () {
      final store = RunLogStore(layout.runLogPath);
      // 6 reviews: 2 approvals, 4 rejections → 33% approval.
      for (var i = 0; i < 2; i++) {
        store.append(event: 'review_approve', message: 'OK', data: {});
      }
      for (var i = 0; i < 4; i++) {
        store.append(event: 'review_reject', message: 'No', data: {});
      }

      final result = service.generate(temp.path);
      expect(result.created, greaterThan(0));
      expect(result.reasons.any((r) => r.contains('approval rate')), isTrue);
    });

    test('generates task for frequent quota hits', () {
      final store = RunLogStore(layout.runLogPath);
      for (var i = 0; i < 5; i++) {
        store.append(
          event: 'provider_pool_quota_hit',
          message: 'Quota',
          data: {'provider': 'codex'},
        );
      }

      final result = service.generate(temp.path);
      expect(result.created, greaterThan(0));
      expect(result.reasons.any((r) => r.contains('quota')), isTrue);
    });

    test('does not duplicate tasks already in backlog', () {
      final store = RunLogStore(layout.runLogPath);
      for (var i = 0; i < 5; i++) {
        store.append(
          event: 'provider_pool_quota_hit',
          message: 'Quota',
          data: {'provider': 'codex'},
        );
      }

      // First generation creates tasks.
      final first = service.generate(temp.path);
      expect(first.created, greaterThan(0));

      // Second generation should find them already in TASKS.md.
      final second = service.generate(temp.path);
      expect(second.created, 0);
    });

    test('persists insight_driven_tasks event to run log', () {
      service.generate(temp.path);

      final lines = File(layout.runLogPath).readAsLinesSync();
      final hasEvent = lines.any((l) => l.contains('insight_driven_tasks'));
      expect(hasEvent, isTrue);
    });
  });
}
