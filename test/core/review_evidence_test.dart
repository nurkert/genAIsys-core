import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/review_bundle.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';

void main() {
  group('Review Evidence Validation', () {
    late Directory temp;
    late ProjectLayout layout;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('genaisys_review_ev_');
      layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      // Enable evidence validation.
      File(layout.configPath).writeAsStringSync('''
review:
  require_evidence: true
''');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('rejects review with response shorter than 50 chars', () async {
      final agent = _FakeReviewAgentService('APPROVE ok');
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/foo.dart | 10 +',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.reject);
    });

    test('rejects review without file reference from diff', () async {
      // Long enough response but doesn't mention any changed file.
      final responseText =
          'APPROVE\nThis is a great change that improves the system. '
          'I have reviewed all aspects thoroughly and found no issues '
          'with correctness, performance, or maintainability.';
      final agent = _FakeReviewAgentService(responseText);
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/services/foo_service.dart | 15 +- 3 -',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.reject);
    });

    test('approves review with file reference from diff', () async {
      final responseText =
          'APPROVE\nThe changes in lib/core/services/foo_service.dart look correct. '
          'The new method follows the existing patterns and has proper test coverage. '
          'Error handling is appropriate.';
      final agent = _FakeReviewAgentService(responseText);
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/services/foo_service.dart | 15 +- 3 -',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.approve);
    });

    test('skips evidence check when require_evidence is false', () async {
      File(layout.configPath).writeAsStringSync('''
review:
  require_evidence: false
''');

      // Short response that would fail evidence check.
      final agent = _FakeReviewAgentService('APPROVE ok');
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/foo.dart | 10 +',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.approve);
    });

    test('evidence check skipped for rejected reviews', () async {
      // A reject decision should pass through without evidence check.
      final agent = _FakeReviewAgentService('REJECT\nThis needs fixes.');
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/foo.dart | 10 +',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.reject);
    });

    test('approves review with basename file reference', () async {
      // Review mentions "foo_service.dart" but not the full path.
      final responseText =
          'APPROVE\nThe foo_service.dart changes look correct. '
          'The new method follows existing patterns and has proper test '
          'coverage. Error handling is appropriate.';
      final agent = _FakeReviewAgentService(responseText);
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/services/foo_service.dart | 15 +- 3 -',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.approve);
    });

    test('extracts root-level file paths without directory separator',
        () async {
      // Root-level file like pubspec.yaml (no '/').
      final responseText =
          'APPROVE\nThe pubspec.yaml dependency update is correct. '
          'Version constraints are appropriate and compatible '
          'with the existing dependency tree.';
      final agent = _FakeReviewAgentService(responseText);
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'pubspec.yaml | 2 +-',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.approve);
    });

    test('approves review with partial path reference', () async {
      // Review mentions "services/foo_service.dart" (last two segments).
      final responseText =
          'APPROVE\nThe services/foo_service.dart changes are solid. '
          'The implementation follows the existing patterns and '
          'error handling is comprehensive.';
      final agent = _FakeReviewAgentService(responseText);
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/services/foo_service.dart | 15 +- 3 -',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.approve);
    });

    test('accepts substantive review without file reference', () async {
      // >200 chars with technical terms but no file name.
      final responseText =
          'APPROVE\nThe implementation follows good software engineering '
          'practices. The class constructor validates all parameters '
          'correctly. The method returns the expected type and handles '
          'edge cases. The test coverage is comprehensive and covers '
          'both happy path and error scenarios. The logic is '
          'straightforward and readable.';
      final agent = _FakeReviewAgentService(responseText);
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/services/foo_service.dart | 15 +- 3 -',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.approve);
    });

    test('rejects short generic response without file reference', () async {
      // ~100 chars, no file references, no substantive content.
      final responseText =
          'APPROVE\nThis is a good change. I have reviewed it and '
          'it looks fine. No issues found at all.';
      final agent = _FakeReviewAgentService(responseText);
      final service = ReviewAgentService(agentService: agent);

      final result = await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/services/foo_service.dart | 15 +- 3 -',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      expect(result.decision, ReviewDecision.reject);
    });

    test('logs review_evidence_weak event on weak evidence', () async {
      final agent = _FakeReviewAgentService('APPROVE ok');
      final service = ReviewAgentService(agentService: agent);

      await service.reviewBundle(
        temp.path,
        bundle: ReviewBundle(
          diffSummary: 'lib/core/foo.dart | 10 +',
          diffPatch: '@@ some patch',
          testSummary: 'All tests pass',
          taskTitle: 'Test task',
          spec: null,
        ),
      );

      final runLog = File(layout.runLogPath);
      expect(runLog.existsSync(), isTrue);
      final content = runLog.readAsStringSync();
      expect(content, contains('review_evidence_weak'));
    });
  });
}

class _FakeReviewAgentService extends AgentService {
  _FakeReviewAgentService(this.output);

  final String output;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    return AgentServiceResult(
      response: AgentResponse(exitCode: 0, stdout: output, stderr: ''),
      usedFallback: false,
    );
  }
}
