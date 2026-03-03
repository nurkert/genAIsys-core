import 'package:test/test.dart';
import 'package:genaisys/core/config/config_field_registry.dart';
import 'package:genaisys/core/config/config_presets.dart';
import 'package:genaisys/core/config/project_config.dart';

import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;

  setUp(() {
    workspace = TestWorkspace.create();
    workspace.ensureStructure();
  });

  tearDown(() => workspace.dispose());

  // -------------------------------------------------------------------------
  // Preset key validation
  // -------------------------------------------------------------------------

  test('all preset keys are valid registry qualified keys', () {
    for (final entry in configPresets.entries) {
      final presetName = entry.key;
      for (final key in entry.value.keys) {
        final field = registryFieldByQualifiedKey(key);
        expect(
          field,
          isNotNull,
          reason:
              'preset "$presetName" uses key "$key" '
              'which is not in the config field registry',
        );
      }
    }
  });

  test('validPresetNames matches configPresets keys', () {
    expect(validPresetNames, configPresets.keys.toSet());
  });

  // -------------------------------------------------------------------------
  // Preset: conservative
  // -------------------------------------------------------------------------

  group('conservative preset', () {
    test('applies conservative defaults', () {
      workspace.writeConfig('preset: conservative\n');
      final config = ProjectConfig.load(workspace.root.path);

      expect(config.autopilotMaxTaskRetries, 2);
      expect(config.autopilotMaxFailures, 3);
      expect(config.reviewMaxRounds, 5);
      expect(config.autopilotScopeMaxFiles, 30);
      expect(config.autopilotScopeMaxAdditions, 3000);
      expect(config.pipelineForensicRecoveryEnabled, isTrue);
      expect(config.autopilotSelfHealEnabled, isTrue);
      expect(config.autopilotReviewContractLockEnabled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Preset: aggressive
  // -------------------------------------------------------------------------

  group('aggressive preset', () {
    test('applies aggressive defaults', () {
      workspace.writeConfig('preset: aggressive\n');
      final config = ProjectConfig.load(workspace.root.path);

      expect(config.autopilotMaxTaskRetries, 5);
      expect(config.autopilotMaxFailures, 10);
      expect(config.reviewMaxRounds, 2);
      expect(config.autopilotScopeMaxFiles, 100);
      expect(config.autopilotScopeMaxAdditions, 10000);
      expect(config.autopilotStepSleep, Duration.zero);
      expect(config.autopilotIdleSleep, const Duration(seconds: 5));
    });
  });

  // -------------------------------------------------------------------------
  // Preset: overnight
  // -------------------------------------------------------------------------

  group('overnight preset', () {
    test('applies overnight defaults', () {
      workspace.writeConfig('preset: overnight\n');
      final config = ProjectConfig.load(workspace.root.path);

      expect(config.autopilotMaxSteps, 500);
      expect(config.autopilotMaxWallclockHours, 8);
      expect(config.autopilotOvernightUnattendedEnabled, isTrue);
      expect(config.autopilotSelfRestart, isTrue);
      expect(config.autopilotSelfHealEnabled, isTrue);
      expect(config.autopilotReviewContractLockEnabled, isTrue);
      expect(config.autopilotReactivateBlocked, isTrue);
      expect(config.autopilotReactivateFailed, isTrue);
      expect(config.autopilotSelectionMode, 'strict_priority');
    });
  });

  // -------------------------------------------------------------------------
  // Layering: explicit YAML overrides preset
  // -------------------------------------------------------------------------

  group('layering', () {
    test('explicit YAML overrides preset values', () {
      workspace.writeConfig('''
preset: overnight
autopilot:
  max_steps: 200
  max_wallclock_hours: 4
''');
      final config = ProjectConfig.load(workspace.root.path);

      // Explicit overrides win.
      expect(config.autopilotMaxSteps, 200);
      expect(config.autopilotMaxWallclockHours, 4);

      // Preset values still apply for non-overridden keys.
      expect(config.autopilotOvernightUnattendedEnabled, isTrue);
      expect(config.autopilotSelfRestart, isTrue);
      expect(config.autopilotSelectionMode, 'strict_priority');
    });

    test('preset values override registry defaults', () {
      // Without preset: max_task_retries defaults to 3.
      workspace.writeConfig('');
      final defaultConfig = ProjectConfig.load(workspace.root.path);
      expect(
        defaultConfig.autopilotMaxTaskRetries,
        ProjectConfig.defaultAutopilotMaxTaskRetries,
      );

      // With conservative preset: max_task_retries becomes 2.
      workspace.writeConfig('preset: conservative\n');
      final presetConfig = ProjectConfig.load(workspace.root.path);
      expect(presetConfig.autopilotMaxTaskRetries, 2);
    });

    test('no preset leaves all values at registry defaults', () {
      workspace.writeConfig('');
      final config = ProjectConfig.load(workspace.root.path);

      expect(
        config.autopilotMaxTaskRetries,
        ProjectConfig.defaultAutopilotMaxTaskRetries,
      );
      expect(config.autopilotMaxSteps, isNull);
      expect(
        config.autopilotScopeMaxFiles,
        ProjectConfig.defaultAutopilotScopeMaxFiles,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Case insensitivity
  // -------------------------------------------------------------------------

  test('preset name is case-insensitive', () {
    workspace.writeConfig('preset: Overnight\n');
    final config = ProjectConfig.load(workspace.root.path);

    expect(config.autopilotMaxSteps, 500);
    expect(config.autopilotOvernightUnattendedEnabled, isTrue);
  });

  // -------------------------------------------------------------------------
  // Unknown preset (parser gracefully ignores, schema validator catches)
  // -------------------------------------------------------------------------

  test('unknown preset name is silently ignored by parser', () {
    workspace.writeConfig('preset: nonexistent\n');
    // Parser doesn't throw — schema validator is the gatekeeper.
    final config = ProjectConfig.load(workspace.root.path);

    // All values remain at registry defaults.
    expect(
      config.autopilotMaxTaskRetries,
      ProjectConfig.defaultAutopilotMaxTaskRetries,
    );
  });

  // -------------------------------------------------------------------------
  // Preset at different positions in the file
  // -------------------------------------------------------------------------

  test('preset before sections applies correctly', () {
    workspace.writeConfig('''
preset: aggressive
review:
  max_rounds: 7
''');
    final config = ProjectConfig.load(workspace.root.path);

    // Explicit override.
    expect(config.reviewMaxRounds, 7);
    // Preset value.
    expect(config.autopilotMaxTaskRetries, 5);
  });
}
