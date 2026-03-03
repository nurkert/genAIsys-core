import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/models/health_snapshot.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/health_score_service.dart';
import 'package:genaisys/core/services/prompt_effectiveness_service.dart';
import 'package:genaisys/core/services/readiness_gate_service.dart';
import 'package:genaisys/core/services/retrospective_service.dart';
import 'package:genaisys/core/services/observability/run_log_insight_service.dart';
import 'package:genaisys/core/services/trend_analysis_service.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_health_');
    layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    Directory(layout.auditDir).createSync(recursive: true);
    Directory(layout.evalsDir).createSync(recursive: true);
    // Create an empty TASKS.md.
    File(layout.tasksPath).writeAsStringSync('# Backlog\n');
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('HealthScoreService', () {
    late HealthScoreService service;

    setUp(() {
      service = HealthScoreService();
    });

    test('returns neutral scores with no data', () {
      final report = service.score();
      expect(report.overallScore, greaterThan(50));
      expect(report.grade, HealthGrade.healthy);
      expect(report.components, hasLength(4));
    });

    test('computes pipeline score from step success rate', () {
      final insights = RunLogInsights(
        totalEvents: 10,
        successfulSteps: 9,
        failedSteps: 1,
        idleSteps: 0,
        reviewApprovals: 0,
        reviewRejections: 0,
        tasksCompleted: 0,
        tasksBlocked: 0,
        providerQuotaHits: 0,
        providerBlocks: 0,
        deadLetterCount: 0,
        autoHealCount: 0,
        errorKindCounts: {},
        errorClassCounts: {},
        providerFailureCounts: {},
      );

      final report = service.score(insights: insights);
      final pipeline = report.components.firstWhere(
        (c) => c.name == 'pipeline',
      );
      // 9/10 = 90% success rate → score ~90.
      expect(pipeline.score, closeTo(90, 1));
    });

    test('penalizes high idle ratio in pipeline', () {
      final insights = RunLogInsights(
        totalEvents: 10,
        successfulSteps: 2,
        failedSteps: 0,
        idleSteps: 8,
        reviewApprovals: 0,
        reviewRejections: 0,
        tasksCompleted: 0,
        tasksBlocked: 0,
        providerQuotaHits: 0,
        providerBlocks: 0,
        deadLetterCount: 0,
        autoHealCount: 0,
        errorKindCounts: {},
        errorClassCounts: {},
        providerFailureCounts: {},
      );

      final report = service.score(insights: insights);
      final pipeline = report.components.firstWhere(
        (c) => c.name == 'pipeline',
      );
      // Success rate = 100% (2/2 non-idle), but idle ratio = 80% → penalty.
      expect(pipeline.score, lessThan(90));
    });

    test('computes review score from approval rate', () {
      final insights = RunLogInsights(
        totalEvents: 10,
        successfulSteps: 0,
        failedSteps: 0,
        idleSteps: 0,
        reviewApprovals: 8,
        reviewRejections: 2,
        tasksCompleted: 0,
        tasksBlocked: 0,
        providerQuotaHits: 0,
        providerBlocks: 0,
        deadLetterCount: 0,
        autoHealCount: 0,
        errorKindCounts: {},
        errorClassCounts: {},
        providerFailureCounts: {},
      );

      final report = service.score(insights: insights);
      final review = report.components.firstWhere((c) => c.name == 'review');
      // 8/10 = 80% → score ~80.
      expect(review.score, closeTo(80, 5));
    });

    test('blends prompt effectiveness into review score', () {
      final insights = RunLogInsights(
        totalEvents: 10,
        successfulSteps: 0,
        failedSteps: 0,
        idleSteps: 0,
        reviewApprovals: 5,
        reviewRejections: 5,
        tasksCompleted: 0,
        tasksBlocked: 0,
        providerQuotaHits: 0,
        providerBlocks: 0,
        deadLetterCount: 0,
        autoHealCount: 0,
        errorKindCounts: {},
        errorClassCounts: {},
        providerFailureCounts: {},
      );

      final promptReport = PromptEffectivenessReport(
        personaMetrics: {},
        overallApprovalRate: 0.9,
        overallCycles: 10,
      );

      final report = service.score(
        insights: insights,
        promptEffectiveness: promptReport,
      );
      final review = report.components.firstWhere((c) => c.name == 'review');
      // Blend: 50%*0.6 + 90%*0.4 = 30+36 = 66.
      expect(review.score, closeTo(66, 2));
    });

    test('deducts for provider quota hits and blocks', () {
      final insights = RunLogInsights(
        totalEvents: 10,
        successfulSteps: 0,
        failedSteps: 0,
        idleSteps: 0,
        reviewApprovals: 0,
        reviewRejections: 0,
        tasksCompleted: 0,
        tasksBlocked: 0,
        providerQuotaHits: 6,
        providerBlocks: 2,
        deadLetterCount: 0,
        autoHealCount: 0,
        errorKindCounts: {},
        errorClassCounts: {},
        providerFailureCounts: {},
      );

      final report = service.score(insights: insights);
      final provider = report.components.firstWhere(
        (c) => c.name == 'provider',
      );
      // 100 - (6*5) - (2*15) = 100 - 30 - 30 = 40.
      expect(provider.score, closeTo(40, 1));
    });

    test('computes task completion from retrospective', () {
      final retrospective = RetrospectiveSummary(
        totalTasks: 10,
        completedTasks: 7,
        blockedTasks: 3,
        errorTasks: 0,
        averageRetries: 0.5,
        topBlockingStages: [],
        topErrorKinds: [],
      );

      final report = service.score(retrospective: retrospective);
      final taskComp = report.components.firstWhere(
        (c) => c.name == 'task_completion',
      );
      // 70% completion → score ~70.
      expect(taskComp.score, closeTo(70, 5));
    });

    test('penalizes dead letters in task completion', () {
      final retrospective = RetrospectiveSummary(
        totalTasks: 10,
        completedTasks: 8,
        blockedTasks: 2,
        errorTasks: 0,
        averageRetries: 0.5,
        topBlockingStages: [],
        topErrorKinds: [],
      );

      final insights = RunLogInsights(
        totalEvents: 10,
        successfulSteps: 0,
        failedSteps: 0,
        idleSteps: 0,
        reviewApprovals: 0,
        reviewRejections: 0,
        tasksCompleted: 8,
        tasksBlocked: 2,
        providerQuotaHits: 0,
        providerBlocks: 0,
        deadLetterCount: 3,
        autoHealCount: 0,
        errorKindCounts: {},
        errorClassCounts: {},
        providerFailureCounts: {},
      );

      final report = service.score(
        retrospective: retrospective,
        insights: insights,
      );
      final taskComp = report.components.firstWhere(
        (c) => c.name == 'task_completion',
      );
      // 80% completion (80) - 3 dead letters * 10 (30) = 50.
      expect(taskComp.score, closeTo(50, 5));
    });

    test('grades critical when overall below 40', () {
      final retrospective = RetrospectiveSummary(
        totalTasks: 10,
        completedTasks: 1,
        blockedTasks: 9,
        errorTasks: 0,
        averageRetries: 3.0,
        topBlockingStages: [],
        topErrorKinds: [],
      );

      final insights = RunLogInsights(
        totalEvents: 20,
        successfulSteps: 2,
        failedSteps: 8,
        idleSteps: 10,
        reviewApprovals: 1,
        reviewRejections: 9,
        tasksCompleted: 1,
        tasksBlocked: 9,
        providerQuotaHits: 10,
        providerBlocks: 3,
        deadLetterCount: 5,
        autoHealCount: 0,
        errorKindCounts: {},
        errorClassCounts: {},
        providerFailureCounts: {},
      );

      final report = service.score(
        retrospective: retrospective,
        insights: insights,
      );
      expect(report.grade, HealthGrade.critical);
      expect(report.overallScore, lessThan(40));
    });

    test('infrastructure failure lowers pipeline score', () {
      final snapshot = HealthSnapshot(
        agent: HealthCheck(ok: false, message: 'Agent not found'),
        allowlist: HealthCheck(ok: true, message: 'OK'),
        git: HealthCheck(ok: true, message: 'OK'),
        review: HealthCheck(ok: true, message: 'OK'),
      );

      final report = service.score(snapshot: snapshot);
      final pipeline = report.components.firstWhere(
        (c) => c.name == 'pipeline',
      );
      expect(pipeline.score, 25.0);
    });

    test('toJson produces valid structure', () {
      final report = service.score();
      final json = report.toJson();
      expect(json['overall_score'], isA<double>());
      expect(json['grade'], isA<String>());
      expect(json['components'], isA<List>());
      expect(json['timestamp'], isA<String>());
    });
  });

  group('ReadinessGateService', () {
    late ReadinessGateService service;

    setUp(() {
      service = ReadinessGateService();
    });

    test('passes when all criteria are met', () {
      final healthReport = HealthReport(
        overallScore: 80.0,
        grade: HealthGrade.healthy,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final verdict = service.evaluate(temp.path, healthReport: healthReport);
      expect(verdict.promotable, isTrue);
      expect(verdict.blockingReasons, isEmpty);
      expect(verdict.criteria.length, greaterThanOrEqualTo(3));
    });

    test('blocks on low health score', () {
      final healthReport = HealthReport(
        overallScore: 30.0,
        grade: HealthGrade.critical,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final verdict = service.evaluate(temp.path, healthReport: healthReport);
      expect(verdict.promotable, isFalse);
      expect(
        verdict.blockingReasons.any((r) => r.contains('Health score')),
        isTrue,
      );
    });

    test('blocks on open P1 stabilization tasks', () {
      // Write a P1 task to TASKS.md.
      File(
        layout.tasksPath,
      ).writeAsStringSync('# Backlog\n- [ ] [P1] [CORE] Fix critical bug\n');

      final healthReport = HealthReport(
        overallScore: 80.0,
        grade: HealthGrade.healthy,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final verdict = service.evaluate(temp.path, healthReport: healthReport);
      expect(verdict.promotable, isFalse);
      expect(verdict.blockingReasons.any((r) => r.contains('P1')), isTrue);
    });

    test('blocks on critical health grade', () {
      final healthReport = HealthReport(
        overallScore: 65.0,
        grade: HealthGrade.critical,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final verdict = service.evaluate(temp.path, healthReport: healthReport);
      expect(verdict.promotable, isFalse);
      expect(
        verdict.blockingReasons.any((r) => r.contains('critical')),
        isTrue,
      );
    });

    test('reads eval summary and blocks on low pass rate', () {
      // Write an eval summary with low pass rate.
      File(
        layout.evalSummaryPath,
      ).writeAsStringSync(jsonEncode({'success_rate': 50.0}));

      final healthReport = HealthReport(
        overallScore: 80.0,
        grade: HealthGrade.healthy,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final verdict = service.evaluate(temp.path, healthReport: healthReport);
      expect(verdict.promotable, isFalse);
      expect(verdict.blockingReasons.any((r) => r.contains('Eval')), isTrue);
    });

    test('passes with good eval summary', () {
      File(
        layout.evalSummaryPath,
      ).writeAsStringSync(jsonEncode({'success_rate': 90.0}));

      final healthReport = HealthReport(
        overallScore: 80.0,
        grade: HealthGrade.healthy,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final verdict = service.evaluate(temp.path, healthReport: healthReport);
      expect(verdict.promotable, isTrue);
    });

    test('persists readiness event to run log', () {
      final healthReport = HealthReport(
        overallScore: 80.0,
        grade: HealthGrade.healthy,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      service.evaluate(temp.path, healthReport: healthReport);

      final lines = File(layout.runLogPath).readAsLinesSync();
      final hasEvent = lines.any(
        (l) => l.contains('readiness_gate_evaluation'),
      );
      expect(hasEvent, isTrue);
    });

    test('custom thresholds are respected', () {
      final strict = ReadinessGateService(
        minHealthScore: 90.0,
        minEvalPassRate: 95.0,
      );

      final healthReport = HealthReport(
        overallScore: 85.0,
        grade: HealthGrade.healthy,
        components: [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final verdict = strict.evaluate(temp.path, healthReport: healthReport);
      expect(verdict.promotable, isFalse);
    });
  });

  group('TrendAnalysisService', () {
    late TrendAnalysisService service;

    setUp(() {
      service = TrendAnalysisService();
    });

    HealthReport makeReport(double score) {
      return HealthReport(
        overallScore: score,
        grade: score >= 70
            ? HealthGrade.healthy
            : score >= 40
            ? HealthGrade.degraded
            : HealthGrade.critical,
        components: [
          ComponentScore(
            name: 'pipeline',
            score: score,
            weight: 0.30,
            details: '',
          ),
          ComponentScore(
            name: 'review',
            score: score,
            weight: 0.25,
            details: '',
          ),
          ComponentScore(
            name: 'provider',
            score: score,
            weight: 0.15,
            details: '',
          ),
          ComponentScore(
            name: 'task_completion',
            score: score,
            weight: 0.30,
            details: '',
          ),
        ],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
    }

    test('returns stable with no history', () {
      final current = makeReport(80.0);
      final trend = service.analyze(temp.path, current);
      expect(trend.overallDirection, TrendDirection.stable);
      expect(trend.snapshotCount, 0);
      expect(trend.regressions, isEmpty);
      expect(trend.improvements, isEmpty);
    });

    test('records snapshot and persists to file', () {
      final report = makeReport(75.0);
      service.recordSnapshot(temp.path, report);

      final file = File(layout.trendSnapshotsPath);
      expect(file.existsSync(), isTrue);

      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<List>());
      expect(decoded, hasLength(1));
      expect((decoded as List).first['overall_score'], closeTo(75, 1));
    });

    test('detects improving trend', () {
      // Record low baseline snapshots.
      for (var i = 0; i < 5; i++) {
        service.recordSnapshot(temp.path, makeReport(50.0));
      }

      // Current is much higher.
      final current = makeReport(80.0);
      final trend = service.analyze(temp.path, current);
      expect(trend.overallDirection, TrendDirection.improving);
      expect(trend.overallDelta, closeTo(30, 1));
      expect(trend.improvements, isNotEmpty);
    });

    test('detects declining trend', () {
      // Record high baseline snapshots.
      for (var i = 0; i < 5; i++) {
        service.recordSnapshot(temp.path, makeReport(90.0));
      }

      // Current is much lower.
      final current = makeReport(50.0);
      final trend = service.analyze(temp.path, current);
      expect(trend.overallDirection, TrendDirection.declining);
      expect(trend.overallDelta, closeTo(-40, 1));
      expect(trend.regressions, isNotEmpty);
    });

    test('detects stable trend within threshold', () {
      for (var i = 0; i < 5; i++) {
        service.recordSnapshot(temp.path, makeReport(75.0));
      }

      final current = makeReport(77.0);
      final trend = service.analyze(temp.path, current);
      expect(trend.overallDirection, TrendDirection.stable);
      expect(trend.regressions, isEmpty);
      expect(trend.improvements, isEmpty);
    });

    test('caps snapshots at maxSnapshots', () {
      for (var i = 0; i < 60; i++) {
        service.recordSnapshot(temp.path, makeReport(75.0));
      }

      final file = File(layout.trendSnapshotsPath);
      final decoded = jsonDecode(file.readAsStringSync());
      expect((decoded as List).length, TrendAnalysisService.maxSnapshots);
    });

    test('persists trend_analysis event to run log', () {
      service.recordSnapshot(temp.path, makeReport(75.0));
      service.analyze(temp.path, makeReport(80.0));

      final lines = File(layout.runLogPath).readAsLinesSync();
      final hasEvent = lines.any((l) => l.contains('trend_analysis'));
      expect(hasEvent, isTrue);
    });

    test('handles corrupted snapshot file gracefully', () {
      File(layout.trendSnapshotsPath).writeAsStringSync('not json');
      final current = makeReport(80.0);
      final trend = service.analyze(temp.path, current);
      expect(trend.overallDirection, TrendDirection.stable);
      expect(trend.snapshotCount, 0);
    });

    test('HealthScoreSnapshot roundtrip', () {
      final snapshot = HealthScoreSnapshot(
        timestamp: '2026-01-01T00:00:00Z',
        overallScore: 82.5,
        grade: 'healthy',
        components: {'pipeline': 90.0, 'review': 75.0},
      );

      final json = snapshot.toJson();
      final restored = HealthScoreSnapshot.fromJson(
        Map<String, dynamic>.from(json),
      );
      expect(restored.overallScore, closeTo(82.5, 0.1));
      expect(restored.grade, 'healthy');
      expect(restored.components['pipeline'], closeTo(90, 1));
      expect(restored.components['review'], closeTo(75, 1));
    });
  });
}
