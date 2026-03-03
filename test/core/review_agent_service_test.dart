import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_review_svc_');
    layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  test('ReviewAgentService approves when response says approve', () async {
    final service = ReviewAgentService(
      agentService: _FakeAgentService(
        'APPROVE\nThe changes in lib/core/a.dart are correct. '
        'Error handling follows existing patterns. Tests cover the new path.',
      ),
    );

    final result = await service.review(
      temp.path,
      diffSummary: 'lib/core/a.dart | 5 +-',
    );

    expect(result.decision, ReviewDecision.approve);
  });

  test('ReviewAgentService rejects when response says reject', () async {
    final service = ReviewAgentService(
      agentService: _FakeAgentService('REJECT\nNeeds fixes.'),
    );

    final result = await service.review(
      temp.path,
      diffSummary: 'Changed file b.dart',
    );

    expect(result.decision, ReviewDecision.reject);
  });

  test('ReviewAgentService rejects when response is unclear', () async {
    final service = ReviewAgentService(
      agentService: _FakeAgentService('Please review further.'),
    );

    final result = await service.review(
      temp.path,
      diffSummary: 'Changed file c.dart',
    );

    expect(result.decision, ReviewDecision.reject);
  });

  test(
    'approves when response contains "ready to merge" without keyword',
    () async {
      final service = ReviewAgentService(
        agentService: _FakeAgentService(
          '## Review Summary\n\n'
          'All checks pass. Changes in lib/core/a.dart are correct.\n\n'
          '**Ready to merge.**',
        ),
      );

      final result = await service.review(
        temp.path,
        diffSummary: 'lib/core/a.dart | 5 +-',
      );

      expect(result.decision, ReviewDecision.approve);
    },
  );

  test('approves when response contains LGTM without keyword', () async {
    final service = ReviewAgentService(
      agentService: _FakeAgentService(
        'LGTM — changes to lib/core/a.dart look fine and follow existing patterns.',
      ),
    );

    final result = await service.review(
      temp.path,
      diffSummary: 'lib/core/a.dart | 3 +-',
    );

    expect(result.decision, ReviewDecision.approve);
  });

  test(
    'approves when both APPROVE and REJECT appear but APPROVE on first line',
    () async {
      final service = ReviewAgentService(
        agentService: _FakeAgentService(
          'APPROVE\nNo reason to reject. Changes in lib/core/a.dart look good.',
        ),
      );

      final result = await service.review(
        temp.path,
        diffSummary: 'lib/core/a.dart | 2 +-',
      );

      expect(result.decision, ReviewDecision.approve);
    },
  );

  test('ReviewAgentService rejects non-English notes', () async {
    final service = ReviewAgentService(
      agentService: _FakeAgentService('APPROVE\nNicht gut.'),
    );

    await expectLater(
      service.review(temp.path, diffSummary: 'Changed file d.dart'),
      throwsStateError,
    );
  });

  group('malformed response handling', () {
    test(
      'rejects with synthetic reject when response has no decision keyword',
      () async {
        final service = ReviewAgentService(
          agentService: _FakeAgentService(
            'The code looks interesting but I am not sure what to say.',
          ),
        );

        final result = await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 3 +-',
        );

        expect(result.decision, ReviewDecision.reject);
      },
    );

    test(
      'emits review_malformed_response run-log event when no decision keyword',
      () async {
        final service = ReviewAgentService(
          agentService: _FakeAgentService(
            'I cannot determine the quality of this change.',
          ),
        );

        await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 3 +-',
        );

        final logFile = File(layout.runLogPath);
        expect(logFile.existsSync(), isTrue);
        final logContent = logFile.readAsStringSync();
        expect(logContent, contains('review_malformed_response'));
        expect(logContent, contains('error_class'));
        expect(logContent, contains('error_kind'));
      },
    );

    test('rejects with synthetic reject when response is empty', () async {
      final service = ReviewAgentService(
        agentService: _FakeAgentService(''),
      );

      final result = await service.review(
        temp.path,
        diffSummary: 'lib/core/a.dart | 3 +-',
      );

      expect(result.decision, ReviewDecision.reject);

      final logFile = File(layout.runLogPath);
      expect(logFile.existsSync(), isTrue);
      final logContent = logFile.readAsStringSync();
      expect(logContent, contains('review_malformed_response'));
    });

    test(
      'does not emit malformed event when APPROVE keyword is present',
      () async {
        final service = ReviewAgentService(
          agentService: _FakeAgentService(
            'APPROVE\nThe changes in lib/core/a.dart are correct and '
            'well tested. Error handling is solid.',
          ),
        );

        final result = await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 5 +-',
        );

        expect(result.decision, ReviewDecision.approve);
        final logFile = File(layout.runLogPath);
        if (logFile.existsSync()) {
          final logContent = logFile.readAsStringSync();
          expect(logContent, isNot(contains('review_malformed_response')));
        }
      },
    );

    test(
      'does not emit malformed event when REJECT keyword is present',
      () async {
        final service = ReviewAgentService(
          agentService: _FakeAgentService('REJECT\nNeeds more tests.'),
        );

        final result = await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 5 +-',
        );

        expect(result.decision, ReviewDecision.reject);
        final logFile = File(layout.runLogPath);
        if (logFile.existsSync()) {
          final logContent = logFile.readAsStringSync();
          expect(logContent, isNot(contains('review_malformed_response')));
        }
      },
    );

    test(
      'does not emit malformed event when positive pattern LGTM is present',
      () async {
        final service = ReviewAgentService(
          agentService: _FakeAgentService(
            'LGTM — changes to lib/core/a.dart look fine and follow '
            'existing patterns.',
          ),
        );

        final result = await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 3 +-',
        );

        expect(result.decision, ReviewDecision.approve);
        final logFile = File(layout.runLogPath);
        if (logFile.existsSync()) {
          final logContent = logFile.readAsStringSync();
          expect(logContent, isNot(contains('review_malformed_response')));
        }
      },
    );
  });

  group('configurable evidence threshold', () {
    test(
      'rejects short APPROVE response below custom evidence threshold',
      () async {
        // Configure a custom evidence_min_length of 100.
        File(layout.configPath).writeAsStringSync('''
review:
  require_evidence: true
  evidence_min_length: 100
''');

        final service = ReviewAgentService(
          agentService: _FakeAgentService(
            'APPROVE\nLooks good. lib/core/a.dart is fine.',
          ),
        );

        final result = await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 3 +-',
        );

        // Response is under 100 chars, so evidence check should reject.
        expect(result.decision, ReviewDecision.reject);
      },
    );

    test(
      'approves response that meets custom evidence threshold',
      () async {
        // Configure a custom evidence_min_length of 20.
        File(layout.configPath).writeAsStringSync('''
review:
  require_evidence: true
  evidence_min_length: 20
''');

        final service = ReviewAgentService(
          agentService: _FakeAgentService(
            'APPROVE\nThe changes in lib/core/a.dart are correct. '
            'Error handling follows existing patterns. Tests cover the '
            'new path and edge cases. Overall well-structured delivery.',
          ),
        );

        final result = await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 5 +-',
        );

        expect(result.decision, ReviewDecision.approve);
      },
    );

    test(
      'uses default evidence threshold of 50 when not configured',
      () async {
        // No review section at all — default evidence_min_length of 50.
        File(layout.configPath).writeAsStringSync('');

        final service = ReviewAgentService(
          agentService: _FakeAgentService(
            'APPROVE\nlib/core/a.dart ok.',
          ),
        );

        final result = await service.review(
          temp.path,
          diffSummary: 'lib/core/a.dart | 3 +-',
        );

        // Response is under 50 chars, so evidence check should reject.
        expect(result.decision, ReviewDecision.reject);
      },
    );
  });
}

class _FakeAgentService extends AgentService {
  _FakeAgentService(this.output);

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
