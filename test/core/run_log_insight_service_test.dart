import 'dart:convert';

import 'package:test/test.dart';

import 'package:genaisys/core/services/observability/run_log_insight_service.dart';
import '../support/test_workspace.dart';

void main() {
  group('reflectionAnalysisWindowLines wiring', () {
    late TestWorkspace workspace;

    setUp(() {
      workspace = TestWorkspace.create();
      workspace.ensureStructure();
    });

    tearDown(() => workspace.dispose());

    test('uses configured analysis_window_lines to limit analyzed events', () {
      // Write config with a small window of 3 lines.
      workspace.writeConfig('reflection:\n  analysis_window_lines: 3\n');

      // Write 6 run log events — only the last 3 should be analyzed.
      workspace.writeRunLog([
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('review_approve'),
        _event('task_done'),
        _event('orchestrator_run_error', data: {'error_kind': 'agent_timeout'}),
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('review_reject'),
      ]);

      final service = RunLogInsightService();
      final insights = service.analyze(workspace.root.path);

      // With a 3-line window only the last 3 events are visible:
      // orchestrator_run_error, orchestrator_run_step, review_reject
      expect(insights.totalEvents, 3);
      expect(insights.failedSteps, 1);
      expect(insights.successfulSteps, 1);
      expect(insights.reviewRejections, 1);
      // The first 3 events (step, approve, task_done) are outside the window.
      expect(insights.reviewApprovals, 0);
      expect(insights.tasksCompleted, 0);
    });

    test('explicit maxLines parameter overrides config', () {
      // Config says 3 lines, but explicit parameter says 6.
      workspace.writeConfig('reflection:\n  analysis_window_lines: 3\n');

      workspace.writeRunLog([
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('review_approve'),
        _event('task_done'),
        _event('orchestrator_run_error', data: {'error_kind': 'agent_timeout'}),
        _event('orchestrator_run_step', data: {'idle': false}),
        _event('review_reject'),
      ]);

      final service = RunLogInsightService();
      final insights = service.analyze(workspace.root.path, maxLines: 6);

      // All 6 events should be visible because explicit maxLines=6 overrides.
      expect(insights.totalEvents, 6);
    });
  });
}

String _event(String event, {Map<String, Object?>? data}) {
  final payload = <String, Object?>{
    'timestamp': '2025-01-01T00:00:00Z',
    'event': event,
  };
  if (data != null) {
    payload['data'] = data;
  }
  return jsonEncode(payload);
}
