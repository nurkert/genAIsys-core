// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../models/task.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import '../storage/task_store.dart';
import 'meta_task_service.dart';
import 'retrospective_service.dart';
import 'observability/run_log_insight_service.dart';
import 'task_management/task_write_service.dart';

/// Result of dynamic insight-driven task generation.
class InsightTaskResult {
  const InsightTaskResult({
    required this.created,
    required this.createdTitles,
    required this.reasons,
  });

  final int created;
  final List<String> createdTitles;
  final List<String> reasons;
}

class InsightDrivenTaskService {
  InsightDrivenTaskService({
    RetrospectiveService? retrospectiveService,
    RunLogInsightService? runLogInsightService,
    TaskWriteService? taskWriteService,
  }) : _retrospectiveService = retrospectiveService ?? RetrospectiveService(),
       _runLogInsightService = runLogInsightService ?? RunLogInsightService(),
       _taskWriteService = taskWriteService ?? TaskWriteService();

  final RetrospectiveService _retrospectiveService;
  final RunLogInsightService _runLogInsightService;
  final TaskWriteService _taskWriteService;

  /// Analyze insights and generate improvement tasks if thresholds are met.
  InsightTaskResult generate(String projectRoot) {
    final layout = ProjectLayout(projectRoot);
    final retrospectives = _retrospectiveService.collect(projectRoot);
    final summary = _retrospectiveService.summarize(retrospectives);
    final insights = _runLogInsightService.analyze(projectRoot);

    final suggestions = <MetaTaskSuggestion>[];
    final reasons = <String>[];

    // Rule 1: High block rate → investigate review quality.
    if (summary.totalTasks >= 3 && summary.blockRate > 0.3) {
      suggestions.add(
        MetaTaskSuggestion(
          id: 'insight-high-block-rate',
          title:
              'Investigate high task block rate (${_pct(summary.blockRate)}) '
              '| AC: Block rate reduced below 30% after remediation.',
          priority: TaskPriority.p1,
          category: TaskCategory.qa,
        ),
      );
      reasons.add(
        'Block rate ${_pct(summary.blockRate)} exceeds 30% threshold '
        '(${summary.blockedTasks}/${summary.totalTasks} tasks blocked).',
      );
    }

    // Rule 2: Low review approval rate → refine review prompts.
    if (insights.reviewApprovals + insights.reviewRejections >= 5 &&
        insights.reviewApprovalRate < 0.5) {
      suggestions.add(
        MetaTaskSuggestion(
          id: 'insight-low-approval-rate',
          title:
              'Refine review prompts to improve approval rate '
              '(${_pct(insights.reviewApprovalRate)}) '
              '| AC: Approval rate above 50% over next 10 reviews.',
          priority: TaskPriority.p1,
          category: TaskCategory.agent,
        ),
      );
      reasons.add(
        'Review approval rate ${_pct(insights.reviewApprovalRate)} is below 50% '
        '(${insights.reviewApprovals} approvals / '
        '${insights.reviewApprovals + insights.reviewRejections} total).',
      );
    }

    // Rule 3: Frequent provider quota hits → optimize provider rotation.
    if (insights.providerQuotaHits >= 5) {
      suggestions.add(
        MetaTaskSuggestion(
          id: 'insight-quota-pressure',
          title:
              'Reduce provider quota pressure (${insights.providerQuotaHits} hits) '
              '| AC: Quota hits per session reduced by 50%.',
          priority: TaskPriority.p2,
          category: TaskCategory.core,
        ),
      );
      reasons.add(
        'Provider pool hit quota limits ${insights.providerQuotaHits} times.',
      );
    }

    // Rule 4: Dominant error kind → targeted fix.
    if (insights.errorKindCounts.isNotEmpty) {
      final topKind = insights.errorKindCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      if (topKind.value >= 3) {
        suggestions.add(
          MetaTaskSuggestion(
            id: 'insight-error-${topKind.key}',
            title:
                'Address recurring ${topKind.key} errors (${topKind.value} occurrences) '
                '| AC: ${topKind.key} errors eliminated or reduced by 80%.',
            priority: TaskPriority.p1,
            category: TaskCategory.core,
          ),
        );
        reasons.add(
          'Error kind "${topKind.key}" occurred ${topKind.value} times.',
        );
      }
    }

    // Rule 5: Dead-letter tasks accumulating → improve retry/decomposition.
    if (insights.deadLetterCount >= 3) {
      final topStage = summary.topBlockingStages.isNotEmpty
          ? summary.topBlockingStages.first.key
          : 'unknown';
      suggestions.add(
        MetaTaskSuggestion(
          id: 'insight-dead-letter-backlog',
          title:
              'Reduce dead-letter task backlog '
              '(${insights.deadLetterCount} quarantined, top stage: $topStage) '
              '| AC: Dead-letter count stays below 3.',
          priority: TaskPriority.p1,
          category: TaskCategory.qa,
        ),
      );
      reasons.add(
        '${insights.deadLetterCount} tasks quarantined as dead letters '
        '(top blocking stage: $topStage).',
      );
    }

    // Deduplicate against existing tasks.
    final existing = TaskStore(
      layout.tasksPath,
    ).readTasks().map((task) => _normalize(task.title)).toSet();

    final created = <String>[];
    for (final suggestion in suggestions) {
      final normalized = _normalize(suggestion.title);
      if (existing.contains(normalized)) continue;
      try {
        _taskWriteService.createTask(
          projectRoot,
          title: suggestion.title,
          priority: suggestion.priority,
          category: suggestion.category,
        );
        created.add(suggestion.title);
        existing.add(normalized);
      } catch (_) {
        // Best-effort task creation.
      }
    }

    RunLogStore(layout.runLogPath).append(
      event: 'insight_driven_tasks',
      message: 'Dynamic improvement tasks generated from insights',
      data: {
        'root': projectRoot,
        'created': created.length,
        'suggestions': suggestions.length,
        'reasons': reasons,
      },
    );

    return InsightTaskResult(
      created: created.length,
      createdTitles: created,
      reasons: reasons,
    );
  }

  String _pct(double value) {
    return '${(value * 100).round()}%';
  }

  String _normalize(String title) {
    return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
