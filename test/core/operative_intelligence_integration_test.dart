import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/services/architecture_context_service.dart';
import 'package:genaisys/core/services/observability/architecture_health_service.dart';
import 'package:genaisys/core/services/error_pattern_registry_service.dart';
import 'package:genaisys/core/services/import_graph_service.dart';
import 'package:genaisys/core/services/task_management/task_forensics_service.dart';

void main() {
  group('Impact context integration', () {
    test(
      'assembleImpactContext returns context for known file dependencies',
      () {
        // Use the real project root to verify impact context against actual
        // imports. This serves as a regression guard.
        final projectRoot = _findProjectRoot();
        if (projectRoot == null) {
          // Skip if not running from project directory.
          return;
        }

        final service = ArchitectureContextService();
        final context = service.assembleImpactContext(projectRoot, [
          'lib/core/services/task_management/task_pipeline_service.dart',
        ]);

        // task_pipeline_service.dart is heavily imported — impact context
        // should list dependent modules.
        expect(context, isNotEmpty);
        expect(context, contains('Target files'));
        expect(context, contains('Dependent modules'));
      },
    );

    test('assembleImpactContext returns empty for non-existent files', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final context = _assembleImpactContext(projectRoot, [
        'lib/core/does_not_exist.dart',
      ]);

      // Non-existent files may produce empty or minimal context.
      // The important thing is it does not crash.
      expect(context, isA<String>());
    });
  });

  group('Error patterns in prompt', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('operative_integration_');
      Directory('${temp.path}/.genaisys/audit').createSync(recursive: true);
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('error patterns appear in assembled prompt', () {
      final service = ErrorPatternRegistryService();

      // Seed error patterns.
      service.mergeObservations(
        temp.path,
        errorKindCounts: {'review_rejected': 5, 'diff_budget_exceeded': 3},
      );
      service.recordResolutionStrategy(
        temp.path,
        'review_rejected',
        'Ensure all spec-required files are touched in the diff.',
      );

      final prompt = service.formatForPrompt(temp.path);

      expect(prompt, isNotEmpty);
      expect(prompt, contains('review_rejected'));
      expect(prompt, contains('5 occurrences'));
      expect(prompt, contains('spec-required files'));
      expect(prompt, contains('diff_budget_exceeded'));
    });

    test('empty registry produces empty prompt', () {
      final service = ErrorPatternRegistryService();

      final prompt = service.formatForPrompt(temp.path);

      expect(prompt, isEmpty);
    });

    test('resolution learned from review appears in prompt', () {
      final service = ErrorPatternRegistryService();

      // Step 1: Error observed.
      service.mergeObservations(
        temp.path,
        errorKindCounts: {'quality_gate_failed': 2},
      );

      // Step 2: Review note stored as resolution (simulates W10.1 learning).
      final stored = service.recordResolutionIfNew(
        temp.path,
        'quality_gate_failed',
        'Always run the analyzer before committing and fix all warnings.',
      );
      expect(stored, isTrue);

      // Step 3: Prompt now includes the learned resolution.
      final prompt = service.formatForPrompt(temp.path);
      expect(prompt, contains('quality_gate_failed'));
      expect(prompt, contains('analyzer'));
    });
  });

  group('Architecture health regression guard', () {
    test('real genaisys lib/ passes architecture health check', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final service = ArchitectureHealthService();
      final report = service.check(projectRoot);

      // The real project should have no critical violations.
      expect(
        report.passed,
        isTrue,
        reason:
            'Architecture violations found:\n'
            '${report.violations.map((v) => v.message).join('\n')}',
      );
      expect(report.score, greaterThan(0.0));
    });

    test('architecture health report serializes to valid JSON', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final service = ArchitectureHealthService();
      final report = service.check(projectRoot);

      final json = report.toJson();
      final encoded = jsonEncode(json);

      expect(encoded, isNotEmpty);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['passed'], isA<bool>());
      expect(decoded['score'], isA<double>());
      expect(decoded['violation_count'], isA<int>());
      expect(decoded['warning_count'], isA<int>());
    });

    test('import graph builds successfully for real project', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final service = ImportGraphService();
      final graph = service.buildGraph(projectRoot);

      // The project has many Dart files — graph should be non-trivial.
      expect(graph.allFiles.length, greaterThan(50));
      expect(graph.forward.isNotEmpty, isTrue);
      expect(graph.reverse.isNotEmpty, isTrue);
    });
  });

  group('Forensics service classification', () {
    late TaskForensicsService forensics;

    setUp(() {
      forensics = TaskForensicsService();
    });

    test('classifies spec_too_large from high file count', () {
      final diagnosis = forensics.diagnose(
        '/nonexistent',
        taskTitle: 'Large Feature',
        retryCount: 3,
        requiredFileCount: 10,
      );

      expect(diagnosis.classification, ForensicClassification.specTooLarge);
      expect(diagnosis.suggestedAction, ForensicAction.redecompose);
      expect(diagnosis.guidanceText, isNotNull);
    });

    test('classifies policy_conflict from error kinds', () {
      final diagnosis = forensics.diagnose(
        '/nonexistent',
        taskTitle: 'Policy Task',
        retryCount: 3,
        errorKinds: ['diff_budget_exceeded'],
      );

      expect(diagnosis.classification, ForensicClassification.policyConflict);
      expect(diagnosis.suggestedAction, ForensicAction.block);
    });

    test('classifies persistent_test_failure from quality gate', () {
      final diagnosis = forensics.diagnose(
        '/nonexistent',
        taskTitle: 'Test Task',
        retryCount: 3,
        errorKinds: ['quality_gate_failed'],
      );

      expect(
        diagnosis.classification,
        ForensicClassification.persistentTestFailure,
      );
      expect(diagnosis.suggestedAction, ForensicAction.retryWithGuidance);
    });

    test('classifies spec_incorrect from review notes', () {
      final temp = Directory.systemTemp.createTempSync('forensic_int_');
      try {
        Directory('${temp.path}/.genaisys').createSync(recursive: true);
        _writeRunLog(temp.path, [
          _reviewRejectEvent(
            note:
                'The spec targets the wrong file — this change needs to be '
                'applied to a completely different module path.',
            task: 'Bad Spec Task',
          ),
        ]);

        final diagnosis = forensics.diagnose(
          temp.path,
          taskTitle: 'Bad Spec Task',
          retryCount: 3,
        );

        expect(diagnosis.classification, ForensicClassification.specIncorrect);
        expect(diagnosis.suggestedAction, ForensicAction.regenerateSpec);
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('classifies unknown when no patterns match', () {
      final diagnosis = forensics.diagnose(
        '/nonexistent',
        taskTitle: 'Mystery Task',
        retryCount: 3,
      );

      expect(diagnosis.classification, ForensicClassification.unknown);
      expect(diagnosis.suggestedAction, ForensicAction.block);
    });
  });

  group('Full pipeline feature integration check', () {
    test('all Wave 7-10 services instantiate without error', () {
      // Verify that all services can be constructed independently.
      // This catches dependency issues at construction time.
      expect(() => ImportGraphService(), returnsNormally);
      expect(() => ArchitectureContextService(), returnsNormally);
      expect(() => ArchitectureHealthService(), returnsNormally);
      expect(() => ErrorPatternRegistryService(), returnsNormally);
      expect(() => TaskForensicsService(), returnsNormally);
    });

    test('architecture health service uses import graph service', () {
      // Verify the dependency wiring: ArchitectureHealthService should
      // accept a custom ImportGraphService.
      final customGraph = ImportGraphService();
      final service = ArchitectureHealthService(
        importGraphService: customGraph,
      );

      expect(service, isA<ArchitectureHealthService>());
    });

    test('error pattern registry round-trips through full lifecycle', () {
      final temp = Directory.systemTemp.createTempSync('lifecycle_');
      try {
        Directory('${temp.path}/.genaisys/audit').createSync(recursive: true);
        final service = ErrorPatternRegistryService();

        // Phase 1: Observe errors.
        service.mergeObservations(
          temp.path,
          errorKindCounts: {'review_rejected': 3},
        );

        // Phase 2: Learn resolution from review.
        service.recordResolutionIfNew(
          temp.path,
          'review_rejected',
          'Ensure all required files are present in the diff before review.',
        );

        // Phase 3: Prompt contains learned knowledge.
        final prompt = service.formatForPrompt(temp.path);
        expect(prompt, contains('review_rejected'));
        expect(prompt, contains('required files'));

        // Phase 4: Second resolve attempt does not overwrite.
        final overwritten = service.recordResolutionIfNew(
          temp.path,
          'review_rejected',
          'A completely different strategy.',
        );
        expect(overwritten, isFalse);

        // Phase 5: Auto-resolution tracking.
        service.recordAutoResolution(temp.path, 'review_rejected');
        final entries = service.load(temp.path);
        final entry = entries.firstWhere(
          (e) => e.errorKind == 'review_rejected',
        );
        expect(entry.autoResolvedCount, 1);
      } finally {
        temp.deleteSync(recursive: true);
      }
    });
  });
}

/// Tries to find the Genaisys project root by walking up from CWD.
String? _findProjectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    final heph = Directory('${dir.path}/.genaisys');
    if (pubspec.existsSync() && heph.existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// Helper to call assembleImpactContext via a fresh service instance.
String _assembleImpactContext(String projectRoot, List<String> targetFiles) {
  return ArchitectureContextService().assembleImpactContext(
    projectRoot,
    targetFiles,
  );
}

/// Writes run-log entries to the standard run-log path.
void _writeRunLog(String projectRoot, List<Map<String, Object?>> entries) {
  final path = '$projectRoot/.genaisys/RUN_LOG.jsonl';
  final buffer = StringBuffer();
  for (final entry in entries) {
    buffer.writeln(jsonEncode(entry));
  }
  File(path).writeAsStringSync(buffer.toString());
}

/// Creates a review_reject event for the run-log.
Map<String, Object?> _reviewRejectEvent({
  required String note,
  required String task,
}) {
  return {
    'event': 'review_reject',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'message': 'Review rejected',
    'data': {'note': note, 'task': task, 'decision': 'reject'},
  };
}
