import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/services/config_service.dart';

import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;
  late ConfigService service;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_config_svc_');
    workspace.ensureStructure();
    service = ConfigService();
  });

  tearDown(() => workspace.dispose());

  test('load from valid YAML with all fields', () {
    workspace.writeConfig('''
git:
  base_branch: develop
  feature_prefix: fix/
policies:
  safe_write:
    enabled: false
  diff_budget:
    max_files: 5
    max_additions: 100
    max_deletions: 50
review:
  max_rounds: 1
  fresh_context: false
''');

    final config = service.load(workspace.root.path);

    expect(config.gitBaseBranch, 'develop');
    expect(config.gitFeaturePrefix, 'fix/');
    expect(config.safeWriteEnabled, isFalse);
    expect(config.diffBudgetMaxFiles, 5);
    expect(config.diffBudgetMaxAdditions, 100);
    expect(config.diffBudgetMaxDeletions, 50);
    expect(config.reviewMaxRounds, 1);
    expect(config.reviewFreshContext, isFalse);
  });

  test('load with missing optional fields applies defaults', () {
    workspace.writeConfig('''
policies:
  safe_write:
    enabled: true
''');

    final config = service.load(workspace.root.path);

    expect(config.safeWriteEnabled, isTrue);
    // All other fields should have their defaults.
    expect(config.gitBaseBranch, 'main');
    expect(config.diffBudgetMaxFiles, ProjectConfig.defaultDiffBudgetMaxFiles);
    expect(config.reviewMaxRounds, ProjectConfig.defaultReviewMaxRounds);
    expect(
      config.autopilotMaxFailures,
      ProjectConfig.defaultAutopilotMaxFailures,
    );
  });

  test('update persists field correctly', () {
    final updated = service.update(
      workspace.root.path,
      update: const ConfigUpdate(gitBaseBranch: 'develop'),
    );

    expect(updated.gitBaseBranch, 'develop');

    // Re-load and verify persistence.
    final reloaded = service.load(workspace.root.path);
    expect(reloaded.gitBaseBranch, 'develop');
  });

  test('round-trip preservation (update one field, others unchanged)', () {
    workspace.writeConfig('''
git:
  base_branch: main
  feature_prefix: feat/
policies:
  diff_budget:
    max_files: 15
    max_additions: 500
    max_deletions: 400
review:
  max_rounds: 2
''');

    // Update only gitBaseBranch.
    service.update(
      workspace.root.path,
      update: const ConfigUpdate(gitBaseBranch: 'develop'),
    );

    // All other fields should be preserved.
    final config = service.load(workspace.root.path);
    expect(config.gitBaseBranch, 'develop');
    expect(config.diffBudgetMaxFiles, 15);
    expect(config.diffBudgetMaxAdditions, 500);
    expect(config.diffBudgetMaxDeletions, 400);
    expect(config.reviewMaxRounds, 2);
  });

  test('malformed YAML falls back to defaults', () {
    File(workspace.layout.configPath).writeAsStringSync('{{{bad yaml');

    // ProjectConfig.load should handle malformed YAML gracefully.
    final config = service.load(workspace.root.path);
    // Should return defaults (not throw).
    expect(config.gitBaseBranch, isNotEmpty);
    expect(config.diffBudgetMaxFiles, greaterThan(0));
  });

  test('shell allowlist normalization includes minimal entries', () {
    service.update(
      workspace.root.path,
      update: const ConfigUpdate(
        shellAllowlistProfile: 'custom',
        shellAllowlist: ['my-tool'],
      ),
    );

    final config = service.load(workspace.root.path);
    // Custom profile + minimal entries should always be included.
    expect(config.shellAllowlist, contains('my-tool'));
    // Minimal entries like 'rg', 'ls', 'cat', 'git status', 'git diff'
    // should be appended.
    expect(config.shellAllowlist, contains('rg'));
    expect(config.shellAllowlist, contains('git status'));
  });
}
