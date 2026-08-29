import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/services/step_schema_validation_service.dart';

import '../support/test_workspace.dart';

void main() {
  test('StepSchemaValidationService accepts default initialized artifacts', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_schema_ok_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure(overwrite: true);

    final service = StepSchemaValidationService();

    expect(() => service.validate(workspace.root.path), returnsNormally);
  });

  test('StepSchemaValidationService rejects malformed STATE.json schema', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_schema_state_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure(overwrite: true);
    File(workspace.layout.statePath).writeAsStringSync('''
{
  "last_updated": "2026-02-08T00:00:00Z",
  "cycle_count": "invalid"
}
''');

    final service = StepSchemaValidationService();

    expect(
      () => service.validate(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('STATE.json'), contains('cycle_count')),
        ),
      ),
    );
  });

  test('StepSchemaValidationService rejects malformed config.yml schema', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_schema_config_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure(overwrite: true);
    File(workspace.layout.configPath).writeAsStringSync('''
autopilot:
  max_failures: "five"
''');

    final service = StepSchemaValidationService();

    expect(
      () => service.validate(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('config.yml'), contains('autopilot.max_failures')),
        ),
      ),
    );
  });

  test('StepSchemaValidationService rejects malformed TASKS.md entries', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_schema_tasks_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure(overwrite: true);
    workspace.writeTasks('''
# Tasks

## Backlog
- [ ]
''');

    final service = StepSchemaValidationService();

    expect(
      () => service.validate(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('TASKS.md'), contains('task line')),
        ),
      ),
    );
  });

  test(
    'StepSchemaValidationService accepts config.yml with git branch hygiene and sync keys',
    () {
      final workspace = TestWorkspace.create(prefix: 'genaisys_schema_git_');
      addTearDown(workspace.dispose);
      workspace.ensureStructure(overwrite: true);
      File(workspace.layout.configPath).writeAsStringSync('''
git:
  base_branch: "main"
  feature_prefix: "feat/"
  auto_delete_remote_merged_branches: true
  auto_stash: false
  sync_between_loops: true
  sync_strategy: "fetch_only"

autopilot:
  max_failures: 5
''');

      final service = StepSchemaValidationService();
      expect(() => service.validate(workspace.root.path), returnsNormally);
    },
  );

  test(
    'StepSchemaValidationService accepts claude_code_cli_config_overrides in providers',
    () {
      final workspace = TestWorkspace.create(
        prefix: 'genaisys_schema_claude_overrides_',
      );
      addTearDown(workspace.dispose);
      workspace.ensureStructure(overwrite: true);
      File(workspace.layout.configPath).writeAsStringSync('''
providers:
  primary: "claude-code"
  claude_code_cli_config_overrides:
    - "--model=claude-sonnet-4-5-20250929"
''');

      final service = StepSchemaValidationService();
      expect(() => service.validate(workspace.root.path), returnsNormally);
    },
  );

  test(
    'StepSchemaValidationService accepts planning_audit_max_add: 0 when feature disabled',
    () {
      final workspace = TestWorkspace.create(
        prefix: 'genaisys_schema_audit_disabled_',
      );
      addTearDown(workspace.dispose);
      workspace.ensureStructure(overwrite: true);
      File(workspace.layout.configPath).writeAsStringSync('''
autopilot:
  planning_audit_enabled: false
  planning_audit_cadence_steps: 0
  planning_audit_max_add: 0
''');

      final service = StepSchemaValidationService();
      expect(() => service.validate(workspace.root.path), returnsNormally);
    },
  );

  test(
    'StepSchemaValidationService rejects planning_audit_max_add: 0 when feature enabled',
    () {
      final workspace = TestWorkspace.create(
        prefix: 'genaisys_schema_audit_enabled_',
      );
      addTearDown(workspace.dispose);
      workspace.ensureStructure(overwrite: true);
      File(workspace.layout.configPath).writeAsStringSync('''
autopilot:
  planning_audit_enabled: true
  planning_audit_max_add: 0
''');

      final service = StepSchemaValidationService();
      expect(
        () => service.validate(workspace.root.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('config.yml'),
              contains('autopilot.planning_audit_max_add'),
            ),
          ),
        ),
      );
    },
  );

  test('StepSchemaValidationService rejects unsupported git sync strategy', () {
    final workspace = TestWorkspace.create(
      prefix: 'genaisys_schema_git_sync_strategy_',
    );
    addTearDown(workspace.dispose);
    workspace.ensureStructure(overwrite: true);
    File(workspace.layout.configPath).writeAsStringSync('''
git:
  sync_between_loops: true
  sync_strategy: "rebase"
''');

    final service = StepSchemaValidationService();

    expect(
      () => service.validate(workspace.root.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('config.yml'),
            contains('git.sync_strategy'),
            contains('fetch_only'),
            contains('pull_ff'),
          ),
        ),
      ),
    );
  });
}
