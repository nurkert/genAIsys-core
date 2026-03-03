import 'package:test/test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/services/error_pattern_registry_service.dart';
import '../support/test_workspace.dart';

void main() {
  group('forensicRecoveryEnabled config', () {
    test('parses false from pipeline section', () {
      final workspace = TestWorkspace.create();
      addTearDown(workspace.dispose);
      workspace.ensureStructure();
      workspace.writeConfig('pipeline:\n  forensic_recovery_enabled: false\n');

      final config = ProjectConfig.load(workspace.root.path);
      expect(config.pipelineForensicRecoveryEnabled, isFalse);
    });

    test('defaults to true when not configured', () {
      final workspace = TestWorkspace.create();
      addTearDown(workspace.dispose);
      workspace.ensureStructure();

      final config = ProjectConfig.load(workspace.root.path);
      expect(config.pipelineForensicRecoveryEnabled, isTrue);
    });
  });

  group('errorPatternLearningEnabled gating', () {
    test('mergeObservations does not record when learning is disabled', () {
      final workspace = TestWorkspace.create();
      addTearDown(workspace.dispose);
      workspace.ensureStructure();
      workspace.writeConfig(
        'pipeline:\n  error_pattern_learning_enabled: false\n',
      );

      final service = ErrorPatternRegistryService();

      // Seed one existing pattern so we can verify it's still readable.
      service.save(workspace.root.path, [
        ErrorPatternEntry(
          errorKind: 'existing_pattern',
          count: 5,
          lastSeen: '2026-01-01T00:00:00Z',
        ),
      ]);

      // Attempt to merge new observations — should be a no-op.
      service.mergeObservations(
        workspace.root.path,
        errorKindCounts: {'new_pattern': 3},
      );

      final entries = service.load(workspace.root.path);
      // Existing pattern is still readable (serving works).
      expect(entries.length, 1);
      expect(entries[0].errorKind, 'existing_pattern');
      // New pattern was NOT recorded (learning is disabled).
      expect(entries.any((e) => e.errorKind == 'new_pattern'), isFalse);
    });

    test('mergeObservations records when learning is enabled', () {
      final workspace = TestWorkspace.create();
      addTearDown(workspace.dispose);
      workspace.ensureStructure();
      workspace.writeConfig(
        'pipeline:\n  error_pattern_learning_enabled: true\n',
      );

      final service = ErrorPatternRegistryService();
      service.mergeObservations(
        workspace.root.path,
        errorKindCounts: {'new_pattern': 2},
      );

      final entries = service.load(workspace.root.path);
      expect(entries.length, 1);
      expect(entries[0].errorKind, 'new_pattern');
      expect(entries[0].count, 2);
    });
  });

  group('impactContextMaxFiles config', () {
    test('parses from pipeline section', () {
      final workspace = TestWorkspace.create();
      addTearDown(workspace.dispose);
      workspace.ensureStructure();
      workspace.writeConfig('pipeline:\n  impact_context_max_files: 3\n');

      final config = ProjectConfig.load(workspace.root.path);
      expect(config.pipelineImpactContextMaxFiles, 3);
    });

    test('defaults to 10 when not configured', () {
      final workspace = TestWorkspace.create();
      addTearDown(workspace.dispose);
      workspace.ensureStructure();

      final config = ProjectConfig.load(workspace.root.path);
      expect(config.pipelineImpactContextMaxFiles, 10);
    });
  });
}
