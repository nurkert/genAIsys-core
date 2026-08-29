// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../../core/app/app.dart';
import '../../../controllers/project_workspace_controller.dart';
import '../../../localization/desktop_localization.dart';
import '../../../localization/desktop_strings.dart';
import '../../../models/dashboard_models.dart';
import '../../../models/workspace_models.dart';
import '../../../theme/premium_white_bronze_tokens.dart';
import '../../../theme/ui_chrome_config.dart';
import '../../../theme/ui_motion_config.dart';
import '../../../theme/ui_surface_styles.dart';
import '../../common/bronze_button.dart';
import '../../common/bronze_gradient_text.dart';

class DashboardWorkspaceView extends StatelessWidget {
  const DashboardWorkspaceView({
    super.key,
    required this.controller,
    required this.topCornerRadius,
    required this.leftSidebarVisible,
    required this.rightSidebarVisible,
  });

  final ProjectWorkspaceController controller;
  final double topCornerRadius;
  final bool leftSidebarVisible;
  final bool rightSidebarVisible;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AnimatedContainer(
      duration: UiMotionConfig.shellDuration,
      curve: UiMotionConfig.shellCurve,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(leftSidebarVisible ? topCornerRadius : 0),
          topRight: Radius.circular(rightSidebarVisible ? topCornerRadius : 0),
        ),
      ),
      child: Padding(
        padding: UiChromeConfig.panelPadding,
        child: ValueListenableBuilder<AppDashboardDto?>(
          valueListenable: controller.dashboardNotifier,
          builder:
              (
                BuildContext context,
                AppDashboardDto? dashboard,
                Widget? child,
              ) {
                return ValueListenableBuilder<AppTaskListDto>(
                  valueListenable: controller.taskListNotifier,
                  builder:
                      (
                        BuildContext context,
                        AppTaskListDto taskList,
                        Widget? innerChild,
                      ) {
                        final stats = _buildStats(strings, dashboard?.status);
                        final activities = _buildActivities(taskList);

                        return LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool compact = constraints.maxWidth < 980;
                                final bool useScrollableFallback =
                                    !compact && constraints.maxHeight < 760;
                                if (compact || useScrollableFallback) {
                                  return SingleChildScrollView(
                                    child: Column(
                                      children: <Widget>[
                                        _MainHeader(
                                          strings: strings,
                                          controller: controller,
                                        ),
                                        const SizedBox(
                                          height: UiChromeConfig.space10,
                                        ),
                                        const SizedBox(
                                          height: UiChromeConfig
                                              .dashboardSectionGap,
                                        ),
                                        _StatsRow(
                                          compact: compact,
                                          stats: stats,
                                        ),
                                        const SizedBox(
                                          height:
                                              UiChromeConfig.dashboardSplitGap,
                                        ),
                                        _AnalyticsRow(
                                          compact: compact,
                                          strings: strings,
                                          status: dashboard?.status,
                                          taskList: taskList,
                                        ),
                                        const SizedBox(
                                          height: UiChromeConfig
                                              .dashboardSectionGap,
                                        ),
                                        if (compact)
                                          _ActivityList(
                                            title: strings.teamActivity,
                                            activities: activities,
                                            compact: true,
                                          )
                                        else
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Expanded(
                                                flex: 6,
                                                child: _ActivityList(
                                                  title: strings.teamActivity,
                                                  activities: activities,
                                                  compact: true,
                                                ),
                                              ),
                                              const SizedBox(
                                                width: UiChromeConfig
                                                    .dashboardSplitGap,
                                              ),
                                              Expanded(
                                                flex: 4,
                                                child: _ProjectHealthPanel(
                                                  strings: strings,
                                                  status: dashboard?.status,
                                                  controller: controller,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (compact) ...<Widget>[
                                          const SizedBox(
                                            height: UiChromeConfig
                                                .dashboardSplitGap,
                                          ),
                                          _ProjectHealthPanel(
                                            strings: strings,
                                            status: dashboard?.status,
                                            controller: controller,
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }
                                return Column(
                                  children: <Widget>[
                                    _MainHeader(
                                      strings: strings,
                                      controller: controller,
                                    ),
                                    const SizedBox(
                                      height: UiChromeConfig.space10,
                                    ),
                                    const SizedBox(
                                      height:
                                          UiChromeConfig.dashboardSectionGap,
                                    ),
                                    _StatsRow(compact: compact, stats: stats),
                                    const SizedBox(
                                      height: UiChromeConfig.dashboardSplitGap,
                                    ),
                                    _AnalyticsRow(
                                      compact: compact,
                                      strings: strings,
                                      status: dashboard?.status,
                                      taskList: taskList,
                                    ),
                                    const SizedBox(
                                      height:
                                          UiChromeConfig.dashboardSectionGap,
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            flex: 6,
                                            child: _ActivityList(
                                              title: strings.teamActivity,
                                              activities: activities,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: UiChromeConfig
                                                .dashboardSplitGap,
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: _ProjectHealthPanel(
                                              strings: strings,
                                              status: dashboard?.status,
                                              controller: controller,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                        );
                      },
                );
              },
        ),
      ),
    );
  }

  List<StatCardModel> _buildStats(
    DesktopStrings strings,
    AppStatusSnapshotDto? status,
  ) {
    final int tasksTotal = status?.tasksTotal ?? 0;
    final int tasksOpen = status?.tasksOpen ?? 0;
    final int tasksDone = status?.tasksDone ?? 0;
    final int tasksBlocked = status?.tasksBlocked ?? 0;
    return <StatCardModel>[
      StatCardModel(
        title: 'Open Tasks',
        value: '$tasksOpen',
        delta: tasksTotal == 0
            ? 'No tasks yet'
            : '${((tasksOpen / tasksTotal) * 100).round()}% of total',
        metal: MetalKind.silver,
      ),
      StatCardModel(
        title: 'Completed',
        value: '$tasksDone',
        delta: tasksTotal == 0
            ? 'No tasks yet'
            : '${((tasksDone / tasksTotal) * 100).round()}% completion',
        metal: MetalKind.gold,
      ),
      StatCardModel(
        title: 'Blocked',
        value: '$tasksBlocked',
        delta: tasksBlocked == 0 ? 'No blockers' : 'Needs attention',
        metal: MetalKind.bronze,
      ),
    ];
  }

  List<ActivityEntry> _buildActivities(AppTaskListDto taskList) {
    final List<AppTaskDto> tasks = taskList.tasks;
    if (tasks.isEmpty) {
      return const <ActivityEntry>[];
    }
    return tasks
        .take(5)
        .map((AppTaskDto task) {
          return ActivityEntry(
            avatar: task.category.isEmpty
                ? 'T'
                : task.category.substring(0, 1).toUpperCase(),
            title: task.title,
            subtitle: 'Section: ${task.section} | Priority: ${task.priority}',
          );
        })
        .toList(growable: false);
  }
}

class _MainHeader extends StatelessWidget {
  const _MainHeader({required this.strings, required this.controller});

  final DesktopStrings strings;
  final ProjectWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: UiChromeConfig.dashboardHeaderWrapRunSpacing,
      spacing: UiChromeConfig.dashboardHeaderWrapSpacing,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              BronzeGradientText(
                strings.dashboardTitle,
                seed: 11,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: UiChromeConfig.dashboardHeaderSubtitleGap),
              Text(
                strings.dashboardSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _onSurfaceMuted(context, lightAlpha: 0.74),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: controller.actionInProgressNotifier,
          builder: (BuildContext context, bool busy, Widget? _) {
            return BronzeButton(
              onPressed: busy
                  ? null
                  : () => unawaited(
                      controller.createTask(
                        title:
                            'New dashboard task (${DateTime.now().toIso8601String()})',
                        priority: BacklogTaskPriority.p2,
                        category: AppTaskCategory.ui,
                        section: 'Backlog',
                      ),
                    ),
              icon: PhosphorIconsRegular.plus,
              label: strings.newProject,
              glow: true,
            );
          },
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.compact, required this.stats});

  final bool compact;
  final List<StatCardModel> stats;

  @override
  Widget build(BuildContext context) {
    final List<Widget> statTiles = stats
        .map((StatCardModel item) => _MetalStat(item: item))
        .toList();

    if (compact) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < statTiles.length; i++) ...<Widget>[
            statTiles[i],
            if (i != statTiles.length - 1)
              const SizedBox(height: UiChromeConfig.dashboardStatsCompactGap),
          ],
        ],
      );
    }

    return Row(
      children: <Widget>[
        for (int i = 0; i < statTiles.length; i++) ...<Widget>[
          Expanded(child: statTiles[i]),
          if (i != statTiles.length - 1)
            const SizedBox(width: UiChromeConfig.dashboardStatsGap),
        ],
      ],
    );
  }
}

class _MetalStat extends StatelessWidget {
  const _MetalStat({required this.item});

  final StatCardModel item;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (item.metal) {
      MetalKind.silver => const Color(0xFF9C9C9C),
      MetalKind.gold => const Color(0xFFD4AF37),
      MetalKind.bronze => const Color(0xFFAA7248),
    };
    final DesktopSurfaceTone tone = switch (item.metal) {
      MetalKind.silver => DesktopSurfaceTone.soft,
      MetalKind.gold => DesktopSurfaceTone.accent,
      MetalKind.bronze => DesktopSurfaceTone.muted,
    };

    return Container(
      constraints: const BoxConstraints(
        minHeight: UiChromeConfig.dashboardStatCardMinHeight,
      ),
      padding: const EdgeInsets.all(UiChromeConfig.dashboardStatCardPadding),
      decoration: UiSurfaceStyles.panel(
        context,
        tone: tone,
        borderRadius: BorderRadius.circular(UiChromeConfig.space14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 4,
            width: 46,
            decoration: BoxDecoration(
              gradient: PremiumWhiteBronzeTokens.bronzeGradientFor(
                item.title.hashCode,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space10),
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: UiChromeConfig.dashboardStatTitleGap),
          Text(item.value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: UiChromeConfig.dashboardStatDeltaGap),
          Text(
            item.delta,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({
    required this.compact,
    required this.strings,
    required this.status,
    required this.taskList,
  });

  final bool compact;
  final DesktopStrings strings;
  final AppStatusSnapshotDto? status;
  final AppTaskListDto taskList;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: <Widget>[
          _TaskCompletionChart(strings: strings, taskList: taskList),
          SizedBox(height: UiChromeConfig.dashboardSplitGap),
          _TaskStatusDonut(strings: strings, status: status),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          flex: 7,
          child: _TaskCompletionChart(strings: strings, taskList: taskList),
        ),
        const SizedBox(width: UiChromeConfig.dashboardSplitGap),
        Expanded(
          flex: 3,
          child: _TaskStatusDonut(strings: strings, status: status),
        ),
      ],
    );
  }
}

class _TaskCompletionChart extends StatelessWidget {
  const _TaskCompletionChart({required this.strings, required this.taskList});

  final DesktopStrings strings;
  final AppTaskListDto taskList;

  @override
  Widget build(BuildContext context) {
    final List<AppTaskDto> tasks = taskList.tasks;
    final int total = tasks.length;
    final int done = tasks
        .where((AppTaskDto t) => t.status == AppTaskStatus.done)
        .length;

    // Build simple bar data: one bar per task, height = 1 for done, 0.3 for open
    final List<BarChartGroupData> barGroups = <BarChartGroupData>[];
    for (int i = 0; i < tasks.length && i < 12; i++) {
      final bool isDone = tasks[i].status == AppTaskStatus.done;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: <BarChartRodData>[
            BarChartRodData(
              toY: isDone ? 1.0 : 0.3,
              width: 18,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              gradient: isDone
                  ? PremiumWhiteBronzeTokens.bronzeGradientFor(i + 31)
                  : null,
              color: isDone
                  ? null
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
          ],
        ),
      );
    }

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.revenueMomentum,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                total == 0 ? '' : '$done / $total done',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _onSurfaceMuted(context, lightAlpha: 0.62),
                ),
              ),
            ],
          ),
          const SizedBox(height: UiChromeConfig.space14),
          SizedBox(
            height: 154,
            child: total == 0
                ? Center(
                    child: Text(
                      'No tasks yet. Create a task to see completion data.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _onSurfaceMuted(context, lightAlpha: 0.5),
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: 1.2,
                      barGroups: barGroups,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.3,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: _chartGrid(context), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskStatusDonut extends StatelessWidget {
  const _TaskStatusDonut({required this.strings, required this.status});

  final DesktopStrings strings;
  final AppStatusSnapshotDto? status;

  @override
  Widget build(BuildContext context) {
    final int open = status?.tasksOpen ?? 0;
    final int done = status?.tasksDone ?? 0;
    final int blocked = status?.tasksBlocked ?? 0;
    final int total = status?.tasksTotal ?? 0;
    final double completion = total == 0 ? 0 : done / total;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.automationReadiness,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: UiChromeConfig.space18),
          Center(
            child: total == 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: UiChromeConfig.space18,
                    ),
                    child: Text(
                      'No tasks yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _onSurfaceMuted(context, lightAlpha: 0.5),
                      ),
                    ),
                  )
                : SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 52,
                            startDegreeOffset: -90,
                            sections: <PieChartSectionData>[
                              if (done > 0)
                                PieChartSectionData(
                                  value: done.toDouble(),
                                  radius: 12,
                                  showTitle: false,
                                  gradient:
                                      PremiumWhiteBronzeTokens.bronzeGradientFor(
                                        41,
                                      ),
                                ),
                              if (open > 0)
                                PieChartSectionData(
                                  value: open.toDouble(),
                                  radius: 12,
                                  showTitle: false,
                                  color: _progressTrack(context),
                                ),
                              if (blocked > 0)
                                PieChartSectionData(
                                  value: blocked.toDouble(),
                                  radius: 12,
                                  showTitle: false,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.error.withValues(alpha: 0.6),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${(completion * 100).round()}%',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              strings.targetLabel,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: _onSurfaceMuted(
                                      context,
                                      lightAlpha: 0.62,
                                      darkAlpha: 0.72,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.title,
    required this.activities,
    this.compact = false,
  });

  final String title;
  final List<ActivityEntry> activities;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: UiChromeConfig.dashboardFormFieldGap),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: UiChromeConfig.space14,
              ),
              child: Text(
                'No tasks yet. Create a task to see activity here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _onSurfaceMuted(context, lightAlpha: 0.5),
                ),
              ),
            ),
          if (activities.isNotEmpty && compact)
            Column(
              children: activities
                  .map(
                    (ActivityEntry activity) => _ActivityTile(item: activity),
                  )
                  .toList(),
            ),
          if (activities.isNotEmpty && !compact)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: activities
                      .map(
                        (ActivityEntry activity) =>
                            _ActivityTile(item: activity),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityEntry item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: UiChromeConfig.dashboardActivityItemVerticalPadding,
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: _avatarFill(context),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            child: Text(item.avatar),
          ),
          const SizedBox(width: UiChromeConfig.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _onSurfaceMuted(context, lightAlpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project Health Panel – replaces Quick Create + MVP Control Deck
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectHealthPanel extends StatelessWidget {
  const _ProjectHealthPanel({
    required this.strings,
    required this.status,
    required this.controller,
  });

  final DesktopStrings strings;
  final AppStatusSnapshotDto? status;
  final ProjectWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = _onSurfaceMuted(context, lightAlpha: 0.62);

    return _SurfaceCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Project Health',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: UiChromeConfig.space14),
            if (status == null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: UiChromeConfig.space18,
                ),
                child: Text(
                  'No project data available yet. Open a project to see health information.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              )
            else ...<Widget>[
              _HealthRow(
                icon: PhosphorIconsRegular.target,
                label: 'Active Task',
                value: status?.activeTaskTitle ?? 'None',
              ),
              _HealthRow(
                icon: PhosphorIconsRegular.magnifyingGlass,
                label: 'Review Status',
                value: status?.reviewStatus ?? 'None',
              ),
              _HealthRow(
                icon: PhosphorIconsRegular.gitBranch,
                label: 'Workflow Stage',
                value: status!.workflowStage,
              ),
              _HealthRow(
                icon: PhosphorIconsRegular.clockCounterClockwise,
                label: 'Last Updated',
                value: _formatTime(status?.lastUpdated),
              ),
              _HealthRow(
                icon: PhosphorIconsRegular.arrowsClockwise,
                label: 'Cycle Count',
                value: '${status!.cycleCount}',
              ),
              if (status?.lastError != null &&
                  status!.lastError!.trim().isNotEmpty)
                _HealthRow(
                  icon: PhosphorIconsRegular.warning,
                  label: 'Last Error',
                  value: status!.lastError!.trim(),
                  isError: true,
                ),
              const SizedBox(height: UiChromeConfig.space14),
              // Health Checks
              Text(
                'Health Checks',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: UiChromeConfig.space8),
              _HealthCheckIndicator(
                label: 'Agent',
                ok: status!.health.agent.ok,
              ),
              _HealthCheckIndicator(
                label: 'Allowlist',
                ok: status!.health.allowlist.ok,
              ),
              _HealthCheckIndicator(label: 'Git', ok: status!.health.git.ok),
              _HealthCheckIndicator(
                label: 'Review',
                ok: status!.health.review.ok,
              ),
            ],
            const SizedBox(height: UiChromeConfig.space14),
            // Quick Navigation
            Text(
              'Quick Navigation',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: UiChromeConfig.space10),
            ValueListenableBuilder<bool>(
              valueListenable: controller.actionInProgressNotifier,
              builder: (BuildContext context, bool busy, Widget? _) {
                return Wrap(
                  spacing: UiChromeConfig.space10,
                  runSpacing: UiChromeConfig.space10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => unawaited(controller.activateNextTask()),
                      icon: const Icon(
                        PhosphorIconsRegular.arrowRight,
                        size: 16,
                      ),
                      label: const Text('Activate Next'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => unawaited(controller.markActiveTaskDone()),
                      icon: const Icon(PhosphorIconsRegular.check, size: 16),
                      label: const Text('Mark Done'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => unawaited(controller.approveReview()),
                      icon: const Icon(
                        PhosphorIconsRegular.sealCheck,
                        size: 16,
                      ),
                      label: const Text('Approve Review'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? value) {
    final DateTime? parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) {
      return value?.trim().isNotEmpty == true ? value!.trim() : '-';
    }
    final DateTime local = parsed.toLocal();
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isError = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UiChromeConfig.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: UiChromeConfig.space8),
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isError ? Theme.of(context).colorScheme.error : null,
                fontWeight: isError ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthCheckIndicator extends StatelessWidget {
  const _HealthCheckIndicator({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UiChromeConfig.space6),
      child: Row(
        children: <Widget>[
          Icon(
            ok
                ? PhosphorIconsRegular.checkCircle
                : PhosphorIconsRegular.warning,
            size: 15,
          ),
          const SizedBox(width: UiChromeConfig.space8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            ok ? 'OK' : 'Fail',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UiChromeConfig.dashboardListCardPadding),
      decoration: UiSurfaceStyles.panel(context, tone: DesktopSurfaceTone.soft),
      child: child,
    );
  }
}

Color _onSurfaceMuted(
  BuildContext context, {
  required double lightAlpha,
  double darkAlpha = 0.82,
}) {
  return UiSurfaceStyles.mutedOnSurface(
    context,
    lightAlpha: lightAlpha,
    darkAlpha: darkAlpha,
  );
}

Color _chartGrid(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0x26FFFFFF)
      : const Color(0x14000000);
}

Color _progressTrack(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2A2A2A)
      : PremiumWhiteBronzeTokens.lightTrack;
}

Color _avatarFill(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF303030)
      : const Color(0xFFE6EDF5);
}
