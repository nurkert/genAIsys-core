import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/errors/operation_errors.dart';
import 'package:genaisys/core/models/review_bundle.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/init_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/templates/default_files.dart';

// ---------------------------------------------------------------------------
// D5: Subtask-Aware Review Scoping
// ---------------------------------------------------------------------------
void main() {
  group('D5: Subtask-Aware Review Scoping', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('heph_d5_');
      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('subtask review prompt contains scoping instructions', () async {
      final service = ReviewAgentService(
        agentService: _PromptCapturingAgentService(
          'APPROVE\nSubtask delivery is correct. Changes in lib/core/a.dart '
          'implement the described scope.',
        ),
      );

      await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/a.dart | 5 +-',
          diffPatch: 'diff --git a/lib/core/a.dart b/lib/core/a.dart\n+ok',
          testSummary: 'All tests passed',
          taskTitle: 'Build full feature',
          spec: 'Implement the entire feature end to end.',
          subtaskDescription: 'Add input validation to the form',
        ),
      );

      final captured = _PromptCapturingAgentService.lastPrompt!;
      expect(
        captured,
        contains('## Review Scope: SUBTASK DELIVERY'),
        reason: 'Subtask review should include scoping header',
      );
      expect(
        captured,
        contains('Add input validation to the form'),
        reason: 'Subtask description should appear in prompt',
      );
      expect(
        captured,
        contains('Evaluate ONLY whether this subtask'),
        reason: 'Scoping instruction should be present',
      );
      expect(
        captured,
        contains('Full Task (Context)'),
        reason: 'Full task should be labeled as context, not evaluation target',
      );
    });

    test('full-task review prompt does not contain subtask scoping', () async {
      final service = ReviewAgentService(
        agentService: _PromptCapturingAgentService(
          'APPROVE\nChanges in lib/core/a.dart are correct.',
        ),
      );

      await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/a.dart | 5 +-',
          diffPatch: 'diff --git a/lib/core/a.dart b/lib/core/a.dart\n+ok',
          testSummary: 'All tests passed',
          taskTitle: 'Build full feature',
          spec: 'Implement the entire feature end to end.',
        ),
      );

      final captured = _PromptCapturingAgentService.lastPrompt!;
      expect(
        captured,
        isNot(contains('## Review Scope: SUBTASK DELIVERY')),
        reason: 'Full-task review should not have subtask scoping',
      );
      expect(
        captured,
        isNot(contains('Full Task (Context)')),
        reason: 'Full-task review should label task as "Task", not "Context"',
      );
    });

    test('ReviewBundle carries subtaskDescription through', () {
      final bundle = ReviewBundle(
        diffSummary: 'summary',
        diffPatch: 'patch',
        testSummary: 'tests pass',
        taskTitle: 'Main task',
        spec: 'Full spec',
        subtaskDescription: 'Subtask A',
      );
      expect(bundle.subtaskDescription, 'Subtask A');

      final bundleNoSubtask = ReviewBundle(
        diffSummary: 'summary',
        diffPatch: 'patch',
        testSummary: null,
        taskTitle: null,
        spec: null,
      );
      expect(bundleNoSubtask.subtaskDescription, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // D7: Review Agent Crash Resilience
  // ---------------------------------------------------------------------------
  group('D7: Review Agent Crash Resilience', () {
    test('review agent crash errors are classified as transient', () {
      final trace = StackTrace.current;

      final error1 = StateError('Review agent failed with exit_code 1.');
      final classified1 = classifyOperationError(error1, trace);
      expect(classified1, isA<TransientError>());

      final error2 = StateError('Review agent crashed during execution.');
      final classified2 = classifyOperationError(error2, trace);
      expect(classified2, isA<TransientError>());
    });

    test('non-review agent errors are not automatically transient', () {
      final error = StateError('Unknown critical failure in pipeline');
      final classified = classifyOperationError(error, StackTrace.current);
      expect(classified, isA<PermanentError>());
    });
  });

  // ---------------------------------------------------------------------------
  // D8: Init Template Robustness
  // ---------------------------------------------------------------------------
  group('D8: Init Template Robustness', () {
    test('configYaml with hasRemote=false sets auto_push/auto_merge false', () {
      final yaml = DefaultFiles.configYaml(hasRemote: false);
      expect(yaml, contains('auto_push: false'));
      expect(yaml, contains('auto_merge: false'));
    });

    test(
      'configYaml with hasRemote=true (default) sets auto_push/auto_merge true',
      () {
        final yaml = DefaultFiles.configYaml(hasRemote: true);
        expect(yaml, contains('auto_push: true'));
        expect(yaml, contains('auto_merge: true'));
      },
    );

    test('configYaml default (no hasRemote arg) sets auto_push true', () {
      final yaml = DefaultFiles.configYaml();
      expect(yaml, contains('auto_push: true'));
      expect(yaml, contains('auto_merge: true'));
    });

    test('init on non-git directory sets auto_push false', () {
      final temp = Directory.systemTemp.createTempSync('heph_d8_no_git_');
      addTearDown(() => temp.deleteSync(recursive: true));

      final service = InitService();
      service.initialize(temp.path);

      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.loadFromFile(layout.configPath);
      expect(
        config.workflowAutoPush,
        isFalse,
        reason:
            'Non-git directory should generate config with auto_push: false',
      );
      expect(
        config.workflowAutoMerge,
        isFalse,
        reason:
            'Non-git directory should generate config with auto_merge: false',
      );
    });

    test('init logs has_remote in run log event', () {
      final temp = Directory.systemTemp.createTempSync('heph_d8_log_');
      addTearDown(() => temp.deleteSync(recursive: true));

      final service = InitService();
      service.initialize(temp.path);

      final layout = ProjectLayout(temp.path);
      final logContent = File(layout.runLogPath).readAsStringSync();
      expect(logContent, contains('"has_remote"'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// An [AgentService] that captures the last prompt for inspection.
class _PromptCapturingAgentService extends AgentService {
  _PromptCapturingAgentService(this.output);

  final String output;
  static String? lastPrompt;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastPrompt = request.prompt;
    return AgentServiceResult(
      response: AgentResponse(exitCode: 0, stdout: output, stderr: ''),
      usedFallback: false,
    );
  }
}
