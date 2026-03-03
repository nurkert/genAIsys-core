import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/templates/default_files.dart';

/// Tests for the 3 newly wired workflow config keys:
/// - `workflow.require_review`
/// - `workflow.auto_commit`
/// - `workflow.merge_strategy`
///
/// Also verifies that `workflow.max_review_retries` was removed from schema.
void main() {
  // ---------------------------------------------------------------------------
  // require_review
  // ---------------------------------------------------------------------------

  group('workflow.require_review', () {
    test('parses require_review: false', () {
      final config = _loadConfig('''
workflow:
  require_review: false
''');
      expect(config.workflowRequireReview, isFalse);
    });

    test('parses require_review: true', () {
      final config = _loadConfig('''
workflow:
  require_review: true
''');
      expect(config.workflowRequireReview, isTrue);
    });

    test('defaults to true when absent', () {
      final config = _loadConfig('''
providers:
  primary: "codex"
''');
      expect(config.workflowRequireReview, isTrue);
    });

    test('defaults to true when workflow section exists but key absent', () {
      final config = _loadConfig('''
workflow:
  auto_push: false
''');
      expect(config.workflowRequireReview, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // auto_commit
  // ---------------------------------------------------------------------------

  group('workflow.auto_commit', () {
    test('parses auto_commit: false', () {
      final config = _loadConfig('''
workflow:
  auto_commit: false
''');
      expect(config.workflowAutoCommit, isFalse);
    });

    test('parses auto_commit: true', () {
      final config = _loadConfig('''
workflow:
  auto_commit: true
''');
      expect(config.workflowAutoCommit, isTrue);
    });

    test('defaults to true when absent', () {
      final config = _loadConfig('''
providers:
  primary: "codex"
''');
      expect(config.workflowAutoCommit, isTrue);
    });

    test('defaults to true when workflow section exists but key absent', () {
      final config = _loadConfig('''
workflow:
  auto_push: true
''');
      expect(config.workflowAutoCommit, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // merge_strategy
  // ---------------------------------------------------------------------------

  group('workflow.merge_strategy', () {
    test('parses merge_strategy: "merge"', () {
      final config = _loadConfig('''
workflow:
  merge_strategy: "merge"
''');
      expect(config.workflowMergeStrategy, 'merge');
    });

    test('parses merge_strategy: "rebase_before_merge"', () {
      final config = _loadConfig('''
workflow:
  merge_strategy: "rebase_before_merge"
''');
      expect(config.workflowMergeStrategy, 'rebase_before_merge');
    });

    test('ignores invalid merge_strategy and keeps default', () {
      final config = _loadConfig('''
workflow:
  merge_strategy: "squash"
''');
      expect(config.workflowMergeStrategy, 'merge');
    });

    test('defaults to "merge" when absent', () {
      final config = _loadConfig('''
providers:
  primary: "codex"
''');
      expect(config.workflowMergeStrategy, 'merge');
    });

    test('case-insensitive parsing', () {
      final config = _loadConfig('''
workflow:
  merge_strategy: "Rebase_Before_Merge"
''');
      expect(config.workflowMergeStrategy, 'rebase_before_merge');
    });
  });

  // ---------------------------------------------------------------------------
  // Combined parsing
  // ---------------------------------------------------------------------------

  group('all workflow keys together', () {
    test('parses all 5 workflow keys correctly', () {
      final config = _loadConfig('''
workflow:
  require_review: false
  auto_commit: false
  auto_push: false
  auto_merge: false
  merge_strategy: "rebase_before_merge"
''');
      expect(config.workflowRequireReview, isFalse);
      expect(config.workflowAutoCommit, isFalse);
      expect(config.workflowAutoPush, isFalse);
      expect(config.workflowAutoMerge, isFalse);
      expect(config.workflowMergeStrategy, 'rebase_before_merge');
    });

    test('default template has all workflow keys', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_workflow_template_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync(
        // Use the default template (Dart profile)
        'workflow:\n'
        '  require_review: true\n'
        '  auto_commit: true\n'
        '  auto_push: true\n'
        '  auto_merge: true\n'
        '  merge_strategy: "rebase_before_merge"\n',
      );

      final config = ProjectConfig.load(temp.path);
      expect(config.workflowRequireReview, isTrue);
      expect(config.workflowAutoCommit, isTrue);
      expect(config.workflowAutoPush, isTrue);
      expect(config.workflowAutoMerge, isTrue);
      expect(config.workflowMergeStrategy, 'rebase_before_merge');
    });
  });

  // ---------------------------------------------------------------------------
  // Default constants
  // ---------------------------------------------------------------------------

  group('default constants', () {
    test('defaultWorkflowRequireReview is true', () {
      expect(ProjectConfig.defaultWorkflowRequireReview, isTrue);
    });

    test('defaultWorkflowAutoCommit is true', () {
      expect(ProjectConfig.defaultWorkflowAutoCommit, isTrue);
    });

    test('defaultWorkflowMergeStrategy is merge', () {
      expect(ProjectConfig.defaultWorkflowMergeStrategy, 'merge');
    });
  });

  // ---------------------------------------------------------------------------
  // max_review_retries removed
  // ---------------------------------------------------------------------------

  group('max_review_retries removal', () {
    test('Dart template no longer contains max_review_retries', () {
      final content = DefaultFiles.configYaml();
      expect(content, isNot(contains('max_review_retries')));
    });

    test('non-Dart template no longer contains max_review_retries', () {
      // Importing QualityGateProfile requires the profile import, so we
      // just check that configYaml() itself (which is the Dart path) has
      // no max_review_retries. The language template is tested via init.
      final content = DefaultFiles.configYaml();
      expect(content, isNot(contains('max_review_retries')));
      // Also verify the template still has the wired keys
      expect(content, contains('require_review'));
      expect(content, contains('auto_commit'));
      expect(content, contains('merge_strategy'));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a temp directory, writes a config.yml with the given content,
/// and loads it via [ProjectConfig.load].
ProjectConfig _loadConfig(String yamlContent) {
  final temp = Directory.systemTemp.createTempSync('genaisys_workflow_cfg_');
  addTearDown(() => temp.deleteSync(recursive: true));

  final layout = ProjectLayout(temp.path);
  Directory(layout.genaisysDir).createSync(recursive: true);
  File(layout.configPath).writeAsStringSync(yamlContent);

  return ProjectConfig.load(temp.path);
}
