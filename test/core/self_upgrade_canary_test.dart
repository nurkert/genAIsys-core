import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/canary_validation_service.dart';
import 'package:genaisys/core/services/health_score_service.dart';
import 'package:genaisys/core/services/readiness_gate_service.dart';
import 'package:genaisys/core/services/release_candidate_builder_service.dart';
import 'package:genaisys/core/services/runtime_switch_service.dart';
import 'package:genaisys/core/services/trend_analysis_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // E1: ReleaseCandidateBuilderService
  // ---------------------------------------------------------------------------
  group('ReleaseCandidateBuilderService', () {
    late Directory tempDir;
    late String projectRoot;
    late ProjectLayout layout;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('genaisys_rc_test_');
      projectRoot = tempDir.path;
      layout = ProjectLayout(projectRoot);

      // Create required directories.
      for (final dir in layout.requiredDirs) {
        Directory(dir).createSync(recursive: true);
      }

      // Write minimal pubspec.yaml.
      File(
        _join(projectRoot, 'pubspec.yaml'),
      ).writeAsStringSync('name: test\nversion: 1.0.0\n');

      // Write empty state.
      File(layout.statePath).writeAsStringSync('{}');

      // Write empty run log.
      File(layout.runLogPath).writeAsStringSync('');

      // Write tasks (no open P1 stabilization tasks).
      File(layout.tasksPath).writeAsStringSync('# Tasks\n');

      // Initialize git repo with an initial commit.
      Process.runSync('git', ['init'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'config',
        'user.email',
        'test@test.com',
      ], workingDirectory: projectRoot);
      Process.runSync('git', [
        'config',
        'user.name',
        'Test',
      ], workingDirectory: projectRoot);
      Process.runSync('git', ['add', '.'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'commit',
        '--no-gpg-sign',
        '-m',
        'initial',
        '--allow-empty',
      ], workingDirectory: projectRoot);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('build reads version from pubspec.yaml', () {
      final service = ReleaseCandidateBuilderService();
      final manifest = service.build(projectRoot);
      expect(manifest.version, equals('1.0.0'));
    });

    test('build resolves git HEAD SHA', () {
      final service = ReleaseCandidateBuilderService();
      final manifest = service.build(projectRoot);
      expect(manifest.gitCommitSha, isNotEmpty);
      expect(manifest.gitCommitSha.length, equals(40));
    });

    test('build computes checksums for existing files', () {
      final service = ReleaseCandidateBuilderService();
      final manifest = service.build(projectRoot);
      expect(manifest.checksums, contains('pubspec.yaml'));
      expect(manifest.checksums, contains('STATE.json'));
      // pubspec.lock may not exist in temp dir; pubspec.yaml and STATE.json should.
      expect(manifest.checksums['pubspec.yaml'], isNotEmpty);
    });

    test('build persists manifest to candidates dir', () {
      final service = ReleaseCandidateBuilderService();
      service.build(projectRoot);
      final manifestFile = File(
        _join(layout.releaseCandidatesDir, '1.0.0.json'),
      );
      expect(manifestFile.existsSync(), isTrue);
      final decoded =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['version'], equals('1.0.0'));
    });

    test('build emits release_candidate_built event', () {
      final service = ReleaseCandidateBuilderService();
      service.build(projectRoot);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('release_candidate_built'));
    });

    test('promote succeeds when readiness passes', () {
      // Build first to create the candidate.
      final service = ReleaseCandidateBuilderService(
        readinessGateService: ReadinessGateService(
          minHealthScore: 50.0,
          minEvalPassRate: 0.0,
        ),
      );
      service.build(projectRoot);

      final healthReport = HealthReport(
        overallScore: 80.0,
        grade: HealthGrade.healthy,
        components: const [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final result = service.promote(
        projectRoot,
        version: '1.0.0',
        healthReport: healthReport,
      );

      expect(result.promoted, isTrue);
      expect(result.reason, equals('promoted'));

      // Verify stable file was created.
      final stableFile = File(_join(layout.releaseStableDir, '1.0.0.json'));
      expect(stableFile.existsSync(), isTrue);
    });

    test('promote blocks when readiness fails', () {
      final service = ReleaseCandidateBuilderService(
        readinessGateService: ReadinessGateService(minHealthScore: 90.0),
      );
      service.build(projectRoot);

      final healthReport = HealthReport(
        overallScore: 20.0,
        grade: HealthGrade.critical,
        components: const [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      final result = service.promote(
        projectRoot,
        version: '1.0.0',
        healthReport: healthReport,
      );

      expect(result.promoted, isFalse);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('release_candidate_promotion_blocked'));
    });

    test('loadManifest returns null for missing version', () {
      final service = ReleaseCandidateBuilderService();
      final manifest = service.loadManifest(projectRoot, version: '99.99.99');
      expect(manifest, isNull);
    });

    test('loadManifest round-trips from build', () {
      final service = ReleaseCandidateBuilderService();
      final built = service.build(projectRoot);
      final loaded = service.loadManifest(projectRoot, version: '1.0.0');
      expect(loaded, isNotNull);
      expect(loaded!.version, equals(built.version));
      expect(loaded.gitCommitSha, equals(built.gitCommitSha));
      expect(loaded.buildTimestamp, equals(built.buildTimestamp));
    });

    test('listCandidates returns built versions', () {
      final service = ReleaseCandidateBuilderService();
      service.build(projectRoot);

      // Also build a second version by changing pubspec.
      File(
        _join(projectRoot, 'pubspec.yaml'),
      ).writeAsStringSync('name: test\nversion: 2.0.0\n');
      Process.runSync('git', ['add', '.'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'commit',
        '--no-gpg-sign',
        '-m',
        'bump',
      ], workingDirectory: projectRoot);
      service.build(projectRoot);

      final candidates = service.listCandidates(projectRoot);
      expect(candidates, contains('1.0.0'));
      expect(candidates, contains('2.0.0'));
      expect(candidates.length, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // E2: RuntimeSwitchService
  // ---------------------------------------------------------------------------
  group('RuntimeSwitchService', () {
    late Directory tempDir;
    late String projectRoot;
    late ProjectLayout layout;
    late ReleaseCandidateBuilderService rcService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('genaisys_rts_test_');
      projectRoot = tempDir.path;
      layout = ProjectLayout(projectRoot);

      // Create required directories.
      for (final dir in layout.requiredDirs) {
        Directory(dir).createSync(recursive: true);
      }

      // Write minimal pubspec.yaml.
      File(
        _join(projectRoot, 'pubspec.yaml'),
      ).writeAsStringSync('name: test\nversion: 1.0.0\n');

      // Write empty state.
      File(layout.statePath).writeAsStringSync('{}');

      // Write empty run log.
      File(layout.runLogPath).writeAsStringSync('');

      // Write tasks.
      File(layout.tasksPath).writeAsStringSync('# Tasks\n');

      // Initialize git.
      Process.runSync('git', ['init'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'config',
        'user.email',
        'test@test.com',
      ], workingDirectory: projectRoot);
      Process.runSync('git', [
        'config',
        'user.name',
        'Test',
      ], workingDirectory: projectRoot);
      Process.runSync('git', ['add', '.'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'commit',
        '--no-gpg-sign',
        '-m',
        'initial',
        '--allow-empty',
      ], workingDirectory: projectRoot);

      // Build a candidate manifest.
      rcService = ReleaseCandidateBuilderService();
      rcService.build(projectRoot);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('switchTo transitions state from idle to canary', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );
      final result = service.switchTo(projectRoot, version: '1.0.0');
      expect(result.switched, isTrue);

      final status = service.getStatus(projectRoot);
      expect(status.state, equals(RuntimeSwitchState.canary));
    });

    test('switchTo stores previous version', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );

      // First switch from nothing.
      service.switchTo(projectRoot, version: '1.0.0');
      var status = service.getStatus(projectRoot);
      expect(status.currentVersion, equals('1.0.0'));
      expect(status.previousVersion, isNull);

      // Build a second version and switch.
      File(
        _join(projectRoot, 'pubspec.yaml'),
      ).writeAsStringSync('name: test\nversion: 2.0.0\n');
      Process.runSync('git', ['add', '.'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'commit',
        '--no-gpg-sign',
        '-m',
        'bump',
      ], workingDirectory: projectRoot);
      rcService.build(projectRoot);

      // Need to reset state to idle for second switch.
      _writeRuntimeState(layout, {'state': 'idle', 'current_version': '1.0.0'});

      service.switchTo(projectRoot, version: '2.0.0');
      status = service.getStatus(projectRoot);
      expect(status.currentVersion, equals('2.0.0'));
      expect(status.previousVersion, equals('1.0.0'));
    });

    test('switchTo emits runtime_switch events', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );
      service.switchTo(projectRoot, version: '1.0.0');

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('runtime_switch_start'));
      expect(runLog, contains('runtime_switch_complete'));
    });

    test('switchTo fails if candidate manifest missing', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );
      final result = service.switchTo(projectRoot, version: '99.99.99');
      expect(result.switched, isFalse);
      expect(result.reason, equals('candidate_manifest_not_found'));
    });

    test('rollback reverts to previous version', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );

      // Set up a state where we're in canary with a previous version.
      _writeRuntimeState(layout, {
        'state': 'canary',
        'current_version': '2.0.0',
        'previous_version': '1.0.0',
      });

      final result = service.rollback(projectRoot);
      expect(result.rolledBack, isTrue);
      expect(result.toVersion, equals('1.0.0'));
      expect(result.fromVersion, equals('2.0.0'));

      final status = service.getStatus(projectRoot);
      expect(status.state, equals(RuntimeSwitchState.rolledBack));
      expect(status.currentVersion, equals('1.0.0'));
    });

    test('rollback emits runtime_rollback event', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );

      _writeRuntimeState(layout, {
        'state': 'canary',
        'current_version': '2.0.0',
        'previous_version': '1.0.0',
      });

      service.rollback(projectRoot);
      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('runtime_rollback'));
    });

    test('getStatus reflects current state', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );

      // Initially idle (no state file).
      var status = service.getStatus(projectRoot);
      expect(status.state, equals(RuntimeSwitchState.idle));

      // After switch.
      service.switchTo(projectRoot, version: '1.0.0');
      status = service.getStatus(projectRoot);
      expect(status.state, equals(RuntimeSwitchState.canary));
      expect(status.currentVersion, equals('1.0.0'));
    });

    test('rollback when no previous version', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );

      // State with no previous version.
      _writeRuntimeState(layout, {
        'state': 'canary',
        'current_version': '1.0.0',
      });

      final result = service.rollback(projectRoot);
      expect(result.rolledBack, isFalse);
      expect(result.reason, equals('no_previous_version'));
    });

    test('switchTo from rolledBack state works', () {
      final service = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );

      _writeRuntimeState(layout, {
        'state': 'rolledBack',
        'current_version': '0.9.0',
      });

      final result = service.switchTo(projectRoot, version: '1.0.0');
      expect(result.switched, isTrue);
      expect(result.fromVersion, equals('0.9.0'));

      final status = service.getStatus(projectRoot);
      expect(status.state, equals(RuntimeSwitchState.canary));
    });
  });

  // ---------------------------------------------------------------------------
  // E3: CanaryValidationService
  // ---------------------------------------------------------------------------
  group('CanaryValidationService', () {
    late Directory tempDir;
    late String projectRoot;
    late ProjectLayout layout;
    late ReleaseCandidateBuilderService rcService;
    late RuntimeSwitchService runtimeSwitchService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('genaisys_canary_test_');
      projectRoot = tempDir.path;
      layout = ProjectLayout(projectRoot);

      // Create required directories.
      for (final dir in layout.requiredDirs) {
        Directory(dir).createSync(recursive: true);
      }

      // Write minimal pubspec.yaml.
      File(
        _join(projectRoot, 'pubspec.yaml'),
      ).writeAsStringSync('name: test\nversion: 1.0.0\n');

      // Write empty state.
      File(layout.statePath).writeAsStringSync('{}');

      // Write empty run log.
      File(layout.runLogPath).writeAsStringSync('');

      // Write tasks.
      File(layout.tasksPath).writeAsStringSync('# Tasks\n');

      // Initialize git.
      Process.runSync('git', ['init'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'config',
        'user.email',
        'test@test.com',
      ], workingDirectory: projectRoot);
      Process.runSync('git', [
        'config',
        'user.name',
        'Test',
      ], workingDirectory: projectRoot);
      Process.runSync('git', ['add', '.'], workingDirectory: projectRoot);
      Process.runSync('git', [
        'commit',
        '--no-gpg-sign',
        '-m',
        'initial',
        '--allow-empty',
      ], workingDirectory: projectRoot);

      // Build a candidate manifest and switch to canary.
      rcService = ReleaseCandidateBuilderService();
      rcService.build(projectRoot);
      runtimeSwitchService = RuntimeSwitchService(
        releaseCandidateBuilderService: rcService,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    HealthReport makeHealthReport({
      double score = 80.0,
      HealthGrade grade = HealthGrade.healthy,
    }) {
      return HealthReport(
        overallScore: score,
        grade: grade,
        components: const [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
    }

    TrendReport makeTrendReport({
      double overallDelta = 0.0,
      List<String> regressions = const [],
    }) {
      return TrendReport(
        overallDirection: overallDelta > 5
            ? TrendDirection.improving
            : overallDelta < -5
            ? TrendDirection.declining
            : TrendDirection.stable,
        overallDelta: overallDelta,
        currentScore: 80.0,
        baselineScore: 80.0 - overallDelta,
        snapshotCount: 5,
        componentTrends: const [],
        regressions: regressions,
        improvements: const [],
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
    }

    test('validate returns not_in_canary when state is idle', () {
      // State is idle by default (no runtime switch state file).
      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
      );

      final result = service.validate(
        projectRoot,
        healthReport: makeHealthReport(),
        trendReport: makeTrendReport(),
      );

      expect(result.passed, isFalse);
      expect(result.reason, equals('not_in_canary'));
    });

    test('validate triggers rollback on critical health grade', () {
      // Switch to canary first.
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
        canaryCycles: 10,
      );

      final result = service.validate(
        projectRoot,
        healthReport: makeHealthReport(
          score: 20.0,
          grade: HealthGrade.critical,
        ),
        trendReport: makeTrendReport(),
      );

      expect(result.passed, isFalse);
      expect(result.rollbackTrigger, equals('critical_health_grade'));
      expect(result.reason, equals('rollback_triggered'));

      // Verify state was rolled back.
      final status = runtimeSwitchService.getStatus(projectRoot);
      expect(status.state, equals(RuntimeSwitchState.rolledBack));
    });

    test('validate triggers rollback on score below threshold', () {
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
        criticalScoreThreshold: 35.0,
      );

      final result = service.validate(
        projectRoot,
        healthReport: makeHealthReport(
          score: 30.0,
          grade: HealthGrade.degraded,
        ),
        trendReport: makeTrendReport(),
      );

      expect(result.passed, isFalse);
      expect(result.rollbackTrigger, equals('score_below_threshold'));
    });

    test('validate triggers rollback on regression with large delta', () {
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
        regressionThreshold: 15.0,
      );

      final result = service.validate(
        projectRoot,
        healthReport: makeHealthReport(
          score: 60.0,
          grade: HealthGrade.degraded,
        ),
        trendReport: makeTrendReport(
          overallDelta: -20.0,
          regressions: ['pipeline', 'review'],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.rollbackTrigger, equals('regression_detected'));
    });

    test('validate increments cycle counter', () {
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
        canaryCycles: 10,
      );

      // First cycle.
      var result = service.validate(
        projectRoot,
        healthReport: makeHealthReport(),
        trendReport: makeTrendReport(),
      );
      expect(result.cyclesCompleted, equals(1));
      expect(result.reason, equals('in_progress'));

      // Second cycle.
      result = service.validate(
        projectRoot,
        healthReport: makeHealthReport(),
        trendReport: makeTrendReport(),
      );
      expect(result.cyclesCompleted, equals(2));
    });

    test('validate passes when cycles reach target', () {
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
        canaryCycles: 3,
      );

      // Run 3 cycles.
      CanaryValidationResult? result;
      for (var i = 0; i < 3; i++) {
        result = service.validate(
          projectRoot,
          healthReport: makeHealthReport(),
          trendReport: makeTrendReport(),
        );
      }

      expect(result!.passed, isTrue);
      expect(result.cyclesCompleted, equals(3));
      expect(result.cyclesTarget, equals(3));
      expect(result.reason, equals('canary_passed'));
    });

    test('validate emits canary_validation_passed on success', () {
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
        canaryCycles: 1,
      );

      service.validate(
        projectRoot,
        healthReport: makeHealthReport(),
        trendReport: makeTrendReport(),
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('canary_validation_passed'));
    });

    test('validate emits canary_validation_failed on rollback trigger', () {
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
      );

      service.validate(
        projectRoot,
        healthReport: makeHealthReport(
          score: 20.0,
          grade: HealthGrade.critical,
        ),
        trendReport: makeTrendReport(),
      );

      final runLog = File(layout.runLogPath).readAsStringSync();
      expect(runLog, contains('canary_validation_failed'));
    });

    test('validate sets state to idle after passing', () {
      runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

      final service = CanaryValidationService(
        runtimeSwitchService: runtimeSwitchService,
        canaryCycles: 1,
      );

      service.validate(
        projectRoot,
        healthReport: makeHealthReport(),
        trendReport: makeTrendReport(),
      );

      final status = runtimeSwitchService.getStatus(projectRoot);
      expect(status.state, equals(RuntimeSwitchState.idle));
    });

    test(
      'validate does not trigger rollback when regression but delta above threshold',
      () {
        runtimeSwitchService.switchTo(projectRoot, version: '1.0.0');

        final service = CanaryValidationService(
          runtimeSwitchService: runtimeSwitchService,
          regressionThreshold: 15.0,
          canaryCycles: 10,
        );

        // Regressions exist but delta is not large enough.
        final result = service.validate(
          projectRoot,
          healthReport: makeHealthReport(
            score: 70.0,
            grade: HealthGrade.healthy,
          ),
          trendReport: makeTrendReport(
            overallDelta: -5.0,
            regressions: ['pipeline'],
          ),
        );

        expect(result.passed, isFalse);
        expect(result.rollbackTrigger, isNull);
        expect(result.reason, equals('in_progress'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // ProjectLayout updates
  // ---------------------------------------------------------------------------
  group('ProjectLayout releases paths', () {
    test('releasesDir is under genaisysDir', () {
      final layout = ProjectLayout('/tmp/test');
      expect(layout.releasesDir, contains('.genaisys'));
      expect(layout.releasesDir, contains('releases'));
    });

    test('releaseCandidatesDir is under releasesDir', () {
      final layout = ProjectLayout('/tmp/test');
      expect(layout.releaseCandidatesDir, contains('releases'));
      expect(layout.releaseCandidatesDir, contains('candidates'));
    });

    test('releaseStableDir is under releasesDir', () {
      final layout = ProjectLayout('/tmp/test');
      expect(layout.releaseStableDir, contains('releases'));
      expect(layout.releaseStableDir, contains('stable'));
    });

    test('requiredDirs includes releases directories', () {
      final layout = ProjectLayout('/tmp/test');
      expect(layout.requiredDirs, contains(layout.releasesDir));
      expect(layout.requiredDirs, contains(layout.releaseCandidatesDir));
      expect(layout.requiredDirs, contains(layout.releaseStableDir));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _join(String left, String right) {
  final separator = Platform.pathSeparator;
  if (left.endsWith(separator)) {
    return '$left$right';
  }
  return '$left$separator$right';
}

void _writeRuntimeState(ProjectLayout layout, Map<String, Object?> state) {
  final dir = Directory(layout.auditDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  File(
    layout.runtimeSwitchStatePath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(state));
}
