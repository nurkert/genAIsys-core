import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/ids/task_slugger.dart';
import 'package:genaisys/core/models/review_bundle.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/observability/architecture_health_service.dart';
import 'package:genaisys/core/services/build_test_runner_service.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_bundle_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/services/spec_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/models/subtask_execution_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('TaskPipelineService runs steps in order', () async {
    final calls = <String>[];
    final reviewService = _FakeReviewAgentService(calls);
    final pipeline = TaskPipelineService(
      specAgentService: _FakeSpecAgentService(calls),
      codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
      reviewAgentService: reviewService,
      reviewBundleService: _FakeReviewBundleService(calls),
      buildTestRunnerService: _FakeBuildTestRunnerService(calls),
      gitService: _FakeGitService(),
    );

    final root = _createProjectRoot();
    final result = await pipeline.run(
      root,
      codingPrompt: 'Do work',
      testSummary: 'Manual checks passed',
    );

    expect(result.review, isNotNull);
    expect(calls, [
      'plan',
      'spec',
      'subtasks',
      'coding',
      'bundle',
      'quality',
      'review',
    ]);
    expect(
      reviewService.lastBundle?.testSummary,
      allOf(contains('Manual checks passed'), contains('Quality Gate: passed')),
    );
  });

  test(
    'TaskPipelineService uses docs system prompt when docs agent profile is enabled',
    () async {
      final calls = <String>[];
      final coding = _CapturingCodingAgentService(calls, exitCode: 0);
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: coding,
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['docs/architecture/guide.md'],
        ),
      );

      final root = _createProjectRoot();
      final config = File('$root/.genaisys/config.yml');
      final original = config.readAsStringSync();
      config.writeAsStringSync(
        original.replaceFirst(
          'docs:\\n    enabled: false',
          'docs:\\n    enabled: true',
        ),
      );

      final docsPrompt = File('$root/.genaisys/agent_contexts/docs.md');
      docsPrompt.writeAsStringSync('DOCS_PROMPT_MARKER');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Manual checks passed',
        taskCategory: TaskCategory.docs,
      );

      expect(result.review, isNotNull);
      expect(coding.lastSystemPrompt, isNotNull);
      expect(coding.lastSystemPrompt, contains('DOCS_PROMPT_MARKER'));
    },
  );

  test(
    'TaskPipelineService uses security persona even when agent profile is disabled',
    () async {
      final calls = <String>[];
      final coding = _CapturingCodingAgentService(calls, exitCode: 0);
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: coding,
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      // Disable the security agent profile.
      final config = File('$root/.genaisys/config.yml');
      final original = config.readAsStringSync();
      config.writeAsStringSync(
        original.replaceAll(
          RegExp(r'security:\s*\n\s*enabled:\s*true'),
          'security:\n    enabled: false\n    system_prompt: "agent_contexts/security.md"',
        ),
      );

      final secPrompt = File('$root/.genaisys/agent_contexts/security.md');
      secPrompt.createSync(recursive: true);
      secPrompt.writeAsStringSync('SECURITY_PERSONA_MARKER');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Manual checks passed',
        taskCategory: TaskCategory.security,
      );

      expect(result.review, isNotNull);
      expect(coding.lastSystemPrompt, isNotNull);
      expect(coding.lastSystemPrompt, contains('SECURITY_PERSONA_MARKER'));
    },
  );

  test(
    'TaskPipelineService uses UI persona even when agent profile is disabled',
    () async {
      final calls = <String>[];
      final coding = _CapturingCodingAgentService(calls, exitCode: 0);
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: coding,
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      // Disable the UI agent profile.
      final config = File('$root/.genaisys/config.yml');
      final original = config.readAsStringSync();
      config.writeAsStringSync(
        original.replaceAll(
          RegExp(r'ui:\s*\n\s*enabled:\s*true'),
          'ui:\n    enabled: false\n    system_prompt: "agent_contexts/ui.md"',
        ),
      );

      final uiPrompt = File('$root/.genaisys/agent_contexts/ui.md');
      uiPrompt.createSync(recursive: true);
      uiPrompt.writeAsStringSync('UI_PERSONA_MARKER');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Manual checks passed',
        taskCategory: TaskCategory.ui,
      );

      expect(result.review, isNotNull);
      expect(coding.lastSystemPrompt, isNotNull);
      expect(coding.lastSystemPrompt, contains('UI_PERSONA_MARKER'));
    },
  );

  test(
    'TaskPipelineService auto-formats changed Dart files before quality gate',
    () async {
      final calls = <String>[];
      final quality = _FakeBuildTestRunnerService(
        calls,
        recordAutoFormatInCalls: true,
      );
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: quality,
        gitService: _FakeGitService(
          changedPathsList: const ['lib/core/new_logic.dart', 'README.md'],
        ),
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(root, codingPrompt: 'Do work');

      expect(result.review, isNotNull);
      expect(quality.autoFormatRequests, hasLength(1));
      expect(
        quality.autoFormatRequests.single,
        equals(['lib/core/new_logic.dart', 'README.md']),
      );
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'format',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test(
    'TaskPipelineService avoids format-drift reject by auto-formatting before quality gate',
    () async {
      final calls = <String>[];
      final quality = _FormatDriftGuardBuildTestRunnerService(calls);
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: quality,
        gitService: _FakeGitService(
          changedPathsList: const ['lib/core/format_drift.dart'],
        ),
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(root, codingPrompt: 'Do work');

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'format',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test('TaskPipelineService skips review when coding fails', () async {
    final calls = <String>[];
    final pipeline = TaskPipelineService(
      specAgentService: _FakeSpecAgentService(calls),
      codingAgentService: _FakeCodingAgentService(calls, exitCode: 1),
      reviewAgentService: _FakeReviewAgentService(calls),
      reviewBundleService: _FakeReviewBundleService(calls),
      buildTestRunnerService: _FakeBuildTestRunnerService(calls),
      gitService: _FakeGitService(),
    );

    final root = _createProjectRoot();
    final result = await pipeline.run(root, codingPrompt: 'Do work');

    expect(result.review, isNull);
    expect(calls, ['plan', 'spec', 'subtasks', 'coding']);
  });

  test(
    'TaskPipelineService short-circuits when coding produces no changes (changedPaths empty)',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(changedPathsList: const []),
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Manual checks passed',
      );

      expect(result.review, isNull);
      // The pipeline must stop right after coding: no format, bundle, quality,
      // or review should be invoked.
      expect(calls, ['plan', 'spec', 'subtasks', 'coding']);
    },
  );

  test('TaskPipelineService skips review when no diff (bundle-level)', () async {
    final calls = <String>[];
    final pipeline = TaskPipelineService(
      specAgentService: _FakeSpecAgentService(calls),
      codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
      reviewAgentService: _FakeReviewAgentService(calls),
      reviewBundleService: _FakeReviewBundleService(
        calls,
        diffSummary: '',
        diffPatch: '',
      ),
      buildTestRunnerService: _FakeBuildTestRunnerService(calls),
      // Non-empty changedPaths so we reach the bundle-level no-diff check.
      gitService: _FakeGitService(changedPathsList: const ['lib/core/change.dart']),
    );

    final root = _createProjectRoot();
    final result = await pipeline.run(root, codingPrompt: 'Do work');

    expect(result.review, isNull);
    expect(calls, ['plan', 'spec', 'subtasks', 'coding', 'bundle']);
  });

  test('TaskPipelineService blocks when diff budget is exceeded', () async {
    final calls = <String>[];
    final pipeline = TaskPipelineService(
      specAgentService: _FakeSpecAgentService(calls),
      codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
      reviewAgentService: _FakeReviewAgentService(calls),
      reviewBundleService: _FakeReviewBundleService(calls),
      buildTestRunnerService: _FakeBuildTestRunnerService(calls),
      gitService: _FakeGitService(
        stats: const DiffStats(filesChanged: 99, additions: 0, deletions: 0),
      ),
    );

    final root = _createProjectRoot();
    await expectLater(
      () => pipeline.run(root, codingPrompt: 'Do work'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Policy violation: diff_budget exceeded'),
        ),
      ),
    );

    expect(calls, ['plan', 'spec', 'subtasks', 'coding']);
  });

  test('TaskPipelineService blocks when safe_write is violated', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_safe_write_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    final configDir = Directory('${temp.path}/.genaisys');
    configDir.createSync(recursive: true);
    File('${configDir.path}/config.yml').writeAsStringSync('''
policies:
  safe_write:
    enabled: true
''');

    final calls = <String>[];
    final pipeline = TaskPipelineService(
      specAgentService: _FakeSpecAgentService(calls),
      codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
      reviewAgentService: _FakeReviewAgentService(calls),
      reviewBundleService: _FakeReviewBundleService(calls),
      buildTestRunnerService: _FakeBuildTestRunnerService(calls),
      gitService: _FakeGitService(changedPathsList: ['.git/HEAD']),
    );

    await expectLater(
      () => pipeline.run(temp.path, codingPrompt: 'Do work'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Policy violation: safe_write blocked'),
        ),
      ),
    );

    expect(calls, ['plan', 'spec', 'subtasks', 'coding']);
  });

  test(
    'TaskPipelineService blocks docs tasks from modifying non-doc files (safe_write_scope)',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_safe_write_scope_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      final configDir = Directory('${temp.path}/.genaisys');
      configDir.createSync(recursive: true);
      File('${configDir.path}/config.yml').writeAsStringSync('''
policies:
  safe_write:
    enabled: true
''');

      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(changedPathsList: ['lib/core/evil.dart']),
      );

      await expectLater(
        () => pipeline.run(
          temp.path,
          codingPrompt: 'Do work',
          taskCategory: TaskCategory.docs,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Policy violation: safe_write_scope blocked'),
          ),
        ),
      );

      expect(calls, ['plan', 'spec', 'subtasks', 'coding']);
    },
  );

  test('TaskPipelineService allows docs tasks to modify docs/', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_scope_ok_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    final configDir = Directory('${temp.path}/.genaisys');
    configDir.createSync(recursive: true);
    File('${configDir.path}/config.yml').writeAsStringSync('''
policies:
  safe_write:
    enabled: true
''');

    final calls = <String>[];
    final pipeline = TaskPipelineService(
      specAgentService: _FakeSpecAgentService(calls),
      codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
      reviewAgentService: _FakeReviewAgentService(calls),
      reviewBundleService: _FakeReviewBundleService(calls),
      buildTestRunnerService: _FakeBuildTestRunnerService(calls),
      gitService: _FakeGitService(
        changedPathsList: const ['docs/incident_playbook.md'],
      ),
    );

    final result = await pipeline.run(
      temp.path,
      codingPrompt: 'Do work',
      testSummary: 'Manual checks passed',
      taskCategory: TaskCategory.docs,
    );

    expect(result.review, isNotNull);
    expect(calls, [
      'plan',
      'spec',
      'subtasks',
      'coding',
      'bundle',
      'quality',
      'review',
    ]);
  });

  test(
    'TaskPipelineService allows docs tasks to modify .genaisys/TASKS.md',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_safe_write_docs_tasks_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });
      final configDir = Directory('${temp.path}/.genaisys');
      configDir.createSync(recursive: true);
      File('${configDir.path}/config.yml').writeAsStringSync('''
policies:
  safe_write:
    enabled: true
''');

      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['.genaisys/TASKS.md', 'README.md'],
        ),
      );

      final result = await pipeline.run(
        temp.path,
        codingPrompt: 'Do work',
        testSummary: 'Manual checks passed',
        taskCategory: TaskCategory.docs,
      );

      expect(result.review, isNotNull);
    },
  );

  test(
    'TaskPipelineService rejects when spec-required files are missing from diff',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['docs/unattended_release_checklist.md'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title =
          'Document unattended mode release checklist and safety guard expectations';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `docs/release/unattended-mode-release-checklist.md` (new)
- `README.md` (update: add a link)
''');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.docs,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.reject);
      expect(calls, ['plan', 'spec', 'subtasks', 'coding', 'bundle']);
    },
  );

  test(
    'TaskPipelineService enforces spec required files as any-of (allows partial)',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['docs/release/unattended-mode.md'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Docs spec required any-of test';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `docs/release/unattended-mode.md` (update)
- `README.md` (update)
''');

      // Create changed file on disk so deletion detection does not
      // false-positive (the file is modified, not deleted).
      Directory('$root/docs/release').createSync(recursive: true);
      File('$root/docs/release/unattended-mode.md')
          .writeAsStringSync('# Doc');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.docs,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
    },
  );

  test(
    'TaskPipelineService matches glob-style required files for any-of mode',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['lib/core/services/task_cycle_service.dart'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Glob required files any-of matching test';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `lib/core/**/task_cycle_service*.dart` (update)
- `test/**/task_cycle_service*_test.dart` (update)
''');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test(
    'TaskPipelineService treats directory required targets without trailing slash as prefix matches',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const [
            'lib/core/agents/provider_process_runner.dart',
          ],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Directory required target prefix matching test';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `lib/core`
''');

      // Create the changed file on disk so deletion detection does not
      // false-positive.
      Directory('$root/lib/core/agents').createSync(recursive: true);
      File('$root/lib/core/agents/provider_process_runner.dart')
          .writeAsStringSync('// stub');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
    },
  );

  test(
    'TaskPipelineService ignores non-path bullets in spec Files section when enforcing required files',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const [
            'lib/core/config/project_config.dart',
            'lib/core/config/project_config_schema.dart',
          ],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title =
          'Split `lib/core/config/project_config.dart` into focused config modules';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- Modify: `lib/core/config/project_config.dart`
- `lib/core/config/project_config_schema.dart` (new)
- Update any impacted imports/usages across core
''');

      // Create changed files on disk so deletion detection does not
      // false-positive.
      Directory('$root/lib/core/config').createSync(recursive: true);
      File('$root/lib/core/config/project_config.dart')
          .writeAsStringSync('// stub');
      File('$root/lib/core/config/project_config_schema.dart')
          .writeAsStringSync('// stub');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, isNot(ReviewDecision.reject));
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test(
    'TaskPipelineService scopes required file enforcement to current subtask targets when available',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const [
            'lib/core/config/project_config_schema.dart',
          ],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Split project config (subtask scope test)';
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(title: title, id: 'task-1'),
          subtaskExecution: const SubtaskExecutionState(
            current:
                'Extract schema module: create `lib/core/config/project_config_schema.dart` defining the immutable data model(s).',
          ),
        ),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `README.md` (update)
- `docs/some_other_doc.md` (new)
''');

      // Create the changed file on disk so deletion detection does not
      // false-positive.
      Directory('$root/lib/core/config').createSync(recursive: true);
      File('$root/lib/core/config/project_config_schema.dart')
          .writeAsStringSync('// stub');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test(
    'TaskPipelineService does not enforce spec-level required files when in subtask mode without explicit file targets',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['lib/other_change.dart'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Subtask mode required files fallback test';
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(title: title, id: 'task-1'),
          subtaskExecution: const SubtaskExecutionState(
            current:
                'Baseline the current API surface and document responsibilities.',
          ),
        ),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `lib/core/app/use_cases/in_process_genaisys_api.dart` (required)
''');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test(
    'TaskPipelineService ignores bare .dart filenames in subtask required file extraction',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['lib/other_change.dart'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Bare dart filename subtask target test';
      store.write(
        store.read().copyWith(
          activeTask: ActiveTaskState(title: title, id: 'task-1'),
          subtaskExecution: const SubtaskExecutionState(
            current:
                'Baseline the current API surface in `in_process_genaisys_api.dart`.',
          ),
        ),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `lib/core/app/use_cases/in_process_genaisys_api.dart` (required)
''');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
    },
  );

  test(
    'TaskPipelineService converts quality gate command failure into reject',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(
          calls,
          error: StateError(
            'Policy violation: quality_gate command failed (exit 1): "dart test".',
          ),
        ),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(root, codingPrompt: 'Do work');

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.reject);
      expect(
        result.review!.response.stdout,
        contains('Quality gate failed before review.'),
      );
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
      ]);
    },
  );

  test(
    'TaskPipelineService converts quality gate dependency bootstrap failure into reject',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(
          calls,
          error: StateError(
            'Policy violation: quality_gate dependency bootstrap failed '
            '(exit 1): "flutter pub get".',
          ),
        ),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(root, codingPrompt: 'Do work');

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.reject);
      expect(
        result.review!.response.stdout,
        contains('Quality gate failed before review.'),
      );
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
      ]);
    },
  );

  test(
    'TaskPipelineService still throws on non-retryable quality gate error',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(
          calls,
          error: StateError(
            'Policy violation: quality_gate has no commands configured.',
          ),
        ),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      await expectLater(
        () => pipeline.run(root, codingPrompt: 'Do work'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Policy violation: quality_gate has no commands configured',
            ),
          ),
        ),
      );

      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
      ]);
    },
  );

  test(
    'TaskPipelineService throws on shell allowlist quality gate violation',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(
          calls,
          error: StateError(
            'Policy violation: shell_allowlist blocked quality_gate command "dart analyze".',
          ),
        ),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      await expectLater(
        () => pipeline.run(root, codingPrompt: 'Do work'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Policy violation: shell_allowlist blocked quality_gate command',
            ),
          ),
        ),
      );

      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
      ]);
    },
  );

  test(
    'TaskPipelineService blocks review when test summary is missing',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(
          calls,
          outcome: const BuildTestRunnerOutcome(executed: false),
        ),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      await expectLater(
        () => pipeline.run(root, codingPrompt: 'Do work'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('review bundle requires test results'),
          ),
        ),
      );

      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
      ]);
    },
  );

  test(
    'TaskPipelineService accepts manual test summary when quality gate has no summary',
    () async {
      final calls = <String>[];
      final reviewService = _FakeReviewAgentService(calls);
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: reviewService,
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(
          calls,
          outcome: const BuildTestRunnerOutcome(executed: false),
        ),
        gitService: _FakeGitService(),
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Manual tests passed',
      );

      expect(result.review, isNotNull);
      expect(reviewService.lastBundle?.testSummary, 'Manual tests passed');
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test(
    'TaskPipelineService passes when spec-required files exist on disk but not in diff',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          // Diff only contains an unrelated file — NOT the required one.
          changedPathsList: const ['lib/core/other_change.dart'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Disk fallback spec required files test';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `README.md` (update)
''');

      // Create the required file on disk so the disk fallback triggers.
      File('$root/README.md').writeAsStringSync('# Project README');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Tests passed',
      );

      // Disk fallback should allow the pipeline to proceed to review.
      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  test(
    'TaskPipelineService rejects when spec-required files are missing from disk and diff',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          // Diff only contains an unrelated file.
          changedPathsList: const ['lib/core/other_change.dart'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Disk fallback missing file reject test';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `README.md` (update)
''');

      // Do NOT create README.md on disk — it should fail both diff and disk checks.

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Tests passed',
      );

      // Required file is missing from both diff and disk → should reject.
      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.reject);
      expect(calls, ['plan', 'spec', 'subtasks', 'coding', 'bundle']);
    },
  );

  // ---------- Change #37: changedPaths re-captured after format, before diff budget ----------

  test(
    'TaskPipelineService re-captures changedPaths after auto-format before diff budget',
    () async {
      final calls = <String>[];
      // Use a git service that returns different paths on successive calls:
      // first call (pre-format): 1 file, second call (post-format): 2 files.
      // changedPaths is called 3 times in the pipeline before auto-format
      // sees the paths:
      //   1st: initial no-diff check (line ~273)
      //   2nd: var changedPaths before safe_write (line ~294) — this is
      //        what auto-format receives
      //   3rd: post-format re-capture (line ~306) — this is what diff
      //        budget and downstream code see
      final git = _SequentialChangedPathsGitService(
        callResults: [
          const ['lib/core/a.dart'], // 1st: no-diff check
          const ['lib/core/a.dart'], // 2nd: pre-format changedPaths
          const ['lib/core/a.dart', 'lib/core/b.dart'], // 3rd: post-format
        ],
      );
      final quality = _FakeBuildTestRunnerService(
        calls,
        recordAutoFormatInCalls: true,
      );
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: quality,
        gitService: git,
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(root, codingPrompt: 'Do work');

      // The pipeline should still complete (diff budget uses its own
      // internal diffStats call, not changedPaths).
      expect(result.review, isNotNull);
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'format',
        'bundle',
        'quality',
        'review',
      ]);
      // The auto-format service should have received the pre-format paths.
      expect(quality.autoFormatRequests.single, ['lib/core/a.dart']);
    },
  );

  // ---------- Change #38: spec-required files reject deletion ----------

  test(
    'TaskPipelineService rejects when spec-required file is deleted (not on disk)',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['lib/core/config/project_config.dart'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Spec required file deletion reject test';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `lib/core/config/project_config.dart` (modify)
''');

      // Do NOT create the file on disk — simulates a deletion.

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Tests passed',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.reject);
      expect(
        result.review!.response.stdout,
        contains('deleted instead of modified/added'),
      );
      expect(calls, ['plan', 'spec', 'subtasks', 'coding', 'bundle']);
    },
  );

  test(
    'TaskPipelineService allows spec-required file that exists on disk (not deleted)',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          changedPathsList: const ['lib/core/config/project_config.dart'],
        ),
      );

      final root = _createProjectRoot();
      final layout = ProjectLayout(root);
      final store = StateStore(layout.statePath);
      const title = 'Spec required file exists on disk test';
      store.write(
        store.read().copyWith(activeTask: ActiveTaskState(title: title, id: 'task-1')),
      );

      final slug = TaskSlugger.slug(title);
      Directory(layout.taskSpecsDir).createSync(recursive: true);
      File('${layout.taskSpecsDir}/$slug.md').writeAsStringSync('''
# Task Spec
Title: $title

## Files
- `lib/core/config/project_config.dart` (modify)
''');

      // Create the file on disk — it is modified, not deleted.
      Directory('$root/lib/core/config').createSync(recursive: true);
      File('$root/lib/core/config/project_config.dart')
          .writeAsStringSync('// modified content');

      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Tests passed',
        taskCategory: TaskCategory.core,
      );

      expect(result.review, isNotNull);
      expect(result.review!.decision, ReviewDecision.approve);
      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
        'review',
      ]);
    },
  );

  // ---------- Change #39: post-format no-diff early check ----------

  test(
    'TaskPipelineService short-circuits when auto-format resolves all changes',
    () async {
      final calls = <String>[];
      // First changedPaths call returns non-empty (before format),
      // second call returns empty (format resolved everything).
      final git = _SequentialChangedPathsGitService(
        callResults: [
          const ['lib/core/format_only.dart'],
          const <String>[], // post-format: empty
        ],
      );
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(
          calls,
          recordAutoFormatInCalls: true,
        ),
        gitService: git,
      );

      final root = _createProjectRoot();
      final result = await pipeline.run(
        root,
        codingPrompt: 'Do work',
        testSummary: 'Manual checks passed',
      );

      // Pipeline should stop after format — no bundle, quality, or review.
      expect(result.review, isNull);
      expect(calls, ['plan', 'spec', 'subtasks', 'coding', 'format']);
    },
  );

  // ---------- Change #40: architecture gate discard failure propagation ----------

  test(
    'TaskPipelineService propagates architecture gate discard failure',
    () async {
      final calls = <String>[];
      final pipeline = TaskPipelineService(
        specAgentService: _FakeSpecAgentService(calls),
        codingAgentService: _FakeCodingAgentService(calls, exitCode: 0),
        reviewAgentService: _FakeReviewAgentService(calls),
        reviewBundleService: _FakeReviewBundleService(calls),
        buildTestRunnerService: _FakeBuildTestRunnerService(calls),
        gitService: _FakeGitService(
          discardError: StateError('discard failed: permission denied'),
        ),
        architectureHealthService: _FailingArchitectureHealthService(),
      );

      final root = _createProjectRoot();
      // Architecture gate is enabled by default — no config change needed.

      await expectLater(
        () => pipeline.run(root, codingPrompt: 'Do work'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('discard failed: permission denied'),
          ),
        ),
      );

      expect(calls, [
        'plan',
        'spec',
        'subtasks',
        'coding',
        'bundle',
        'quality',
      ]);
    },
  );
}

String _createProjectRoot() {
  final temp = Directory.systemTemp.createTempSync('genaisys_pipeline_');
  addTearDown(() {
    temp.deleteSync(recursive: true);
  });
  ProjectInitializer(temp.path).ensureStructure(overwrite: true);
  return temp.path;
}

class _FakeSpecAgentService extends SpecAgentService {
  _FakeSpecAgentService(this.calls);

  final List<String> calls;

  @override
  Future<SpecAgentResult> generate(
    String projectRoot, {
    required SpecKind kind,
    bool overwrite = false,
    String? guidanceContext,
  }) async {
    calls.add(kind.name);
    return SpecAgentResult(
      path: '/tmp/${kind.name}.md',
      kind: kind,
      wrote: true,
      usedFallback: false,
      response: const AgentResponse(exitCode: 0, stdout: '', stderr: ''),
    );
  }

  /// Always returns PASS so the AC self-check stage does not call a real agent.
  @override
  Future<AcSelfCheckResult> checkImplementationAgainstAc(
    String projectRoot, {
    required String requirement,
    required String diffSummary,
  }) async =>
      const AcSelfCheckResult(passed: true, skipped: false);
}

class _FakeCodingAgentService extends CodingAgentService {
  _FakeCodingAgentService(this.calls, {required this.exitCode});

  final List<String> calls;
  final int exitCode;

  @override
  Future<CodingAgentResult> run(
    String projectRoot, {
    required String prompt,
    String? systemPrompt,
    TaskCategory? taskCategory,
  }) async {
    calls.add('coding');
    return CodingAgentResult(
      path: '/tmp/attempt.txt',
      usedFallback: false,
      response: AgentResponse(exitCode: exitCode, stdout: '', stderr: ''),
    );
  }
}

class _CapturingCodingAgentService extends _FakeCodingAgentService {
  _CapturingCodingAgentService(super.calls, {required super.exitCode});

  String? lastSystemPrompt;

  @override
  Future<CodingAgentResult> run(
    String projectRoot, {
    required String prompt,
    String? systemPrompt,
    TaskCategory? taskCategory,
  }) async {
    lastSystemPrompt = systemPrompt;
    return super.run(
      projectRoot,
      prompt: prompt,
      systemPrompt: systemPrompt,
      taskCategory: taskCategory,
    );
  }
}

class _FakeReviewAgentService extends ReviewAgentService {
  _FakeReviewAgentService(this.calls);

  final List<String> calls;
  ReviewBundle? lastBundle;

  @override
  Future<ReviewAgentResult> reviewBundle(
    String projectRoot, {
    required ReviewBundle bundle,
    ReviewPersona persona = ReviewPersona.general,
    String strictness = 'standard',
    List<String> contractNotes = const [],
  }) async {
    calls.add('review');
    lastBundle = bundle;
    return ReviewAgentResult(
      decision: ReviewDecision.approve,
      response: const AgentResponse(exitCode: 0, stdout: 'APPROVE', stderr: ''),
      usedFallback: false,
    );
  }
}

class _FakeBuildTestRunnerService extends BuildTestRunnerService {
  _FakeBuildTestRunnerService(
    this.calls, {
    this.error,
    this.outcome,
    this.recordAutoFormatInCalls = false,
  }) : super(commandRunner: _NoopShellRunner());

  final List<String> calls;
  final Object? error;
  final BuildTestRunnerOutcome? outcome;
  final bool recordAutoFormatInCalls;
  final List<List<String>> autoFormatRequests = <List<String>>[];

  @override
  Future<AutoFormatOutcome> autoFormatChangedDartFiles(
    String projectRoot, {
    required List<String> changedPaths,
  }) async {
    autoFormatRequests.add(List<String>.unmodifiable(changedPaths));
    if (recordAutoFormatInCalls) {
      calls.add('format');
    }
    return const AutoFormatOutcome(executed: false, files: 0);
  }

  @override
  Future<BuildTestRunnerOutcome> run(
    String projectRoot, {
    List<String>? changedPaths,
  }) async {
    calls.add('quality');
    if (error != null) {
      throw error!;
    }
    return outcome ??
        const BuildTestRunnerOutcome(
          executed: true,
          summary: 'Quality Gate: passed (1 checks)',
        );
  }
}

class _FormatDriftGuardBuildTestRunnerService extends BuildTestRunnerService {
  _FormatDriftGuardBuildTestRunnerService(this.calls)
    : super(commandRunner: _NoopShellRunner());

  final List<String> calls;
  bool _formatted = false;

  @override
  Future<AutoFormatOutcome> autoFormatChangedDartFiles(
    String projectRoot, {
    required List<String> changedPaths,
  }) async {
    calls.add('format');
    _formatted = true;
    return AutoFormatOutcome(executed: true, files: changedPaths.length);
  }

  @override
  Future<BuildTestRunnerOutcome> run(
    String projectRoot, {
    List<String>? changedPaths,
  }) async {
    calls.add('quality');
    if (!_formatted) {
      throw StateError(
        'Policy violation: quality_gate command failed (exit 1): '
        '"dart format --output=none --set-exit-if-changed .".',
      );
    }
    return const BuildTestRunnerOutcome(
      executed: true,
      summary: 'Quality Gate: passed (format drift auto-fixed)',
    );
  }
}

class _NoopShellRunner implements ShellCommandRunner {
  const _NoopShellRunner();

  @override
  Future<ShellCommandResult> run(
    String command, {
    required String workingDirectory,
    required Duration timeout,
  }) {
    throw UnimplementedError('Noop shell runner should not be used in tests.');
  }
}

class _FakeReviewBundleService extends ReviewBundleService {
  _FakeReviewBundleService(
    this.calls, {
    this.diffSummary = 'diff',
    this.diffPatch = 'patch',
  });

  final List<String> calls;
  final String diffSummary;
  final String diffPatch;

  @override
  ReviewBundle build(String projectRoot, {String? testSummary, String? sinceCommitSha}) {
    calls.add('bundle');
    return ReviewBundle(
      diffSummary: diffSummary,
      diffPatch: diffPatch,
      testSummary: testSummary,
      taskTitle: 'Task',
      spec: 'Spec',
    );
  }
}

class _FakeGitService implements GitService {
  _FakeGitService({
    this.stats = const DiffStats(filesChanged: 0, additions: 0, deletions: 0),
    this.changedPathsList = const ['lib/core/change.dart'],
    this.discardError,
  });

  final DiffStats stats;
  final List<String> changedPathsList;
  final Object? discardError;

  @override
  DiffStats diffStats(String path) => stats;

  @override
  List<String> changedPaths(String path) => changedPathsList;

  @override
  void addAll(String path) {}

  @override
  void abortMerge(String path) {}

  @override
  void checkout(String path, String ref) {}

  @override
  void commit(String path, String message) {}

  @override
  List<String> conflictPaths(String path) => [];

  @override
  void createBranch(String path, String branch, {String? startPoint}) {}

  @override
  String currentBranch(String path) => 'main';

  @override
  bool branchExists(String path, String branch) => true;

  @override
  List<String> localBranchesMergedInto(String path, String baseRef) =>
      const <String>[];

  @override
  String? defaultRemote(String path) => 'origin';

  @override
  void deleteBranch(String path, String branch, {bool force = false}) {}

  @override
  void deleteRemoteBranch(String path, String remote, String branch) {}

  @override
  String diffPatch(String path) => '';

  @override
  String diffSummary(String path) => '';

  @override
  void ensureClean(String path) {}

  @override
  void fetch(String path, String remote) {}

  @override
  bool hasChanges(String path) => false;

  @override
  bool hasRemote(String path, String remote) => true;

  @override
  bool stashPush(
    String path, {
    required String message,
    bool includeUntracked = true,
  }) {
    return true;
  }

  @override
  void stashPop(String path) {}

  @override
  bool hasMergeInProgress(String path) => false;

  @override
  bool isClean(String path) => true;

  @override
  bool isGitRepo(String path) => true;

  @override
  void merge(String path, String branch) {}

  @override
  void pullFastForward(String path, String remote, String branch) {}

  @override
  bool remoteBranchExists(String path, String remote, String branch) => true;

  @override
  void push(String path, String remote, String branch) {}

  @override
  ProcessResult pushDryRun(String path, String remote, String branch) =>
      ProcessResult(0, 0, '', '');

  @override
  bool tagExists(String path, String tag) => false;

  @override
  void createAnnotatedTag(String path, String tag, {required String message}) {}

  @override
  void pushTag(String path, String remote, String tag) {}

  @override
  String repoRoot(String path) => path;

  @override
  DiffStats diffStatsBetween(String path, String fromRef, String toRef) =>
      stats;

  @override
  void discardWorkingChanges(String path) {
    if (discardError != null) {
      throw discardError!;
    }
  }

  @override
  int stashCount(String path) => 0;

  @override
  void dropOldestStashes(String path, {required int maxKeep}) {}

  @override
  void removeFromIndexIfTracked(String path, List<String> relativePaths) {}

  @override
  void hardReset(String path, {String ref = 'HEAD'}) {}

  @override
  void cleanUntracked(String path) {}

  @override
  bool hasRebaseInProgress(String path) => false;

  @override
  List<String> recentCommitMessages(String path, {int count = 10}) => const [];

  @override
  String headCommitSha(String path, {bool short = false}) => 'abc1234';

  @override
  void resetIndex(String path) {}

  @override
  int commitCount(String path) => 1;

  @override
  bool hasStagedChanges(String path) => false;

  @override
  String diffSummaryBetween(String path, String fromRef, String toRef) => '';
  @override
  String diffPatchBetween(String path, String fromRef, String toRef) => '';
  @override
  bool isCommitReachable(String path, String sha) => true;
}

/// A [GitService] that returns different [changedPaths] results on successive
/// calls.  The first call uses [callResults[0]], the second [callResults[1]],
/// etc.  Once all results are exhausted, repeats the last one.
class _SequentialChangedPathsGitService extends _FakeGitService {
  _SequentialChangedPathsGitService({required this.callResults})
    : super(changedPathsList: callResults.first);

  final List<List<String>> callResults;
  int _callIndex = 0;

  @override
  List<String> changedPaths(String path) {
    final result =
        _callIndex < callResults.length
            ? callResults[_callIndex]
            : callResults.last;
    _callIndex++;
    return result;
  }
}

/// An [ArchitectureHealthService] that always reports critical violations,
/// causing the architecture gate to reject and attempt a discard.
class _FailingArchitectureHealthService extends ArchitectureHealthService {
  @override
  ArchitectureHealthReport check(
    String projectRoot, {
    int fanOutThreshold = 10,
  }) {
    return ArchitectureHealthReport(
      violations: const [
        ArchViolation(
          type: 'layer_violation',
          file: 'lib/core/bad_import.dart',
          importedFile: 'lib/ui/widget.dart',
          severity: ArchViolationSeverity.critical,
          message: 'core must not import ui',
        ),
      ],
      warnings: const [],
      score: 0.5,
    );
  }
}
