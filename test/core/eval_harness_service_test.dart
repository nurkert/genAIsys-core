import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/policy/diff_budget_policy.dart';
import 'package:genaisys/core/services/eval_harness_service.dart';
import 'package:genaisys/core/services/policy_simulation_service.dart';

import '../support/test_workspace.dart';

class _FakeSimulationService extends PolicySimulationService {
  _FakeSimulationService(this.queue);

  final List<PolicySimulationResult> queue;
  int _index = 0;

  @override
  Future<PolicySimulationResult> run(
    String projectRoot, {
    required String codingPrompt,
    String? testSummary,
    bool overwriteArtifacts = false,
    int? minOpenTasks,
    int? maxPlanAdd,
    bool keepWorkspace = false,
  }) async {
    final result = queue[_index];
    _index = (_index + 1) % queue.length;
    return result;
  }
}

void main() {
  test('EvalHarnessService writes summary and results', () async {
    final workspace = TestWorkspace.create(prefix: 'genaisys_eval_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure();

    final benchmarks = {
      'benchmarks': [
        {
          'id': 'case-1',
          'title': 'Case 1',
          'prompt': 'Do thing',
          'expected_decision': 'approve',
          'require_diff': true,
          'allow_policy_violation': false,
        },
        {
          'id': 'case-2',
          'title': 'Case 2',
          'prompt': 'Do other',
          'expected_decision': 'reject',
          'require_diff': false,
          'allow_policy_violation': false,
        },
      ],
    };
    File(
      workspace.layout.evalBenchmarksPath,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(benchmarks));

    final queue = [
      PolicySimulationResult(
        projectRoot: workspace.root.path,
        workspaceRoot: null,
        hasTask: true,
        activatedTask: true,
        plannedTasksAdded: 0,
        taskTitle: 'Case 1',
        taskId: 'case-1',
        subtask: null,
        reviewDecision: 'approve',
        diffSummary: 'diff',
        diffPatch: '',
        diffStats: DiffStats(filesChanged: 1, additions: 2, deletions: 0),
        policyViolation: false,
        policyMessage: null,
      ),
      PolicySimulationResult(
        projectRoot: workspace.root.path,
        workspaceRoot: null,
        hasTask: true,
        activatedTask: true,
        plannedTasksAdded: 0,
        taskTitle: 'Case 2',
        taskId: 'case-2',
        subtask: null,
        reviewDecision: 'reject',
        diffSummary: '',
        diffPatch: '',
        diffStats: DiffStats(filesChanged: 0, additions: 0, deletions: 0),
        policyViolation: false,
        policyMessage: null,
      ),
    ];

    final service = EvalHarnessService(
      simulationService: _FakeSimulationService(queue),
    );
    final result = await service.run(workspace.root.path);

    expect(result.total, 2);
    expect(result.passed, 2);
    expect(result.successRate, 100);
    expect(Directory(result.outputDir).existsSync(), isTrue);

    final summary =
        jsonDecode(File(workspace.layout.evalSummaryPath).readAsStringSync())
            as Map<String, dynamic>;
    expect(summary['last_run_id'], result.runId);
    expect(summary['passed'], 2);
    expect(summary['total'], 2);
  });
}
