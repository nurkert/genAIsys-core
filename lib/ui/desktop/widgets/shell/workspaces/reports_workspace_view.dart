// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../../core/app/app.dart';
import '../../../controllers/project_workspace_controller.dart';
import '../../../controllers/run_log_viewer_controller.dart';
import '../../../localization/desktop_localization.dart';
import '../../../localization/desktop_strings.dart';
import '../../../theme/premium_white_bronze_tokens.dart';
import '../../../theme/ui_chrome_config.dart';
import '../../../theme/ui_surface_styles.dart';
import 'workspace_feedback_banner.dart';
import 'workspace_header.dart';

class ReportsWorkspaceView extends StatefulWidget {
  const ReportsWorkspaceView({super.key, required this.controller});

  final ProjectWorkspaceController controller;

  @override
  State<ReportsWorkspaceView> createState() => _ReportsWorkspaceViewState();
}

class _ReportsWorkspaceViewState extends State<ReportsWorkspaceView> {
  late final RunLogViewerController _logController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _logController = RunLogViewerController(
      projectRootPath: widget.controller.projectRootPath,
    );
    unawaited(_logController.refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _logController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        WorkspaceHeader(
          title: strings.reportsTitle,
          subtitle: strings.reportsSubtitle,
          seed: 71,
        ),
        const SizedBox(height: UiChromeConfig.space12),
        ValueListenableBuilder<({String? error, String? info})>(
          valueListenable: widget.controller.feedbackNotifier,
          builder:
              (
                BuildContext context,
                ({String? error, String? info}) feedback,
                Widget? child,
              ) {
                return WorkspaceFeedbackBanner(
                  errorMessage: feedback.error,
                  infoMessage: feedback.info,
                  onDismiss: widget.controller.clearFeedback,
                );
              },
        ),
        ValueListenableBuilder<({String? error, String? info})>(
          valueListenable: widget.controller.feedbackNotifier,
          builder:
              (
                BuildContext context,
                ({String? error, String? info}) feedback,
                Widget? child,
              ) {
                if (feedback.error != null || feedback.info != null) {
                  return const SizedBox(height: UiChromeConfig.space12);
                }
                return const SizedBox.shrink();
              },
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _logController,
            builder: (BuildContext context, Widget? child) {
              final int policyViolationCount =
                  _logController.policyViolationCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          strings.reportsRunLogTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (policyViolationCount > 0)
                        _PolicyViolationBadge(
                          label: strings.reportsPolicyViolationsLabel,
                          count: policyViolationCount,
                        ),
                    ],
                  ),
                  const SizedBox(height: UiChromeConfig.space10),
                  _RunLogControls(
                    strings: strings,
                    controller: _logController,
                    searchController: _searchController,
                  ),
                  const SizedBox(height: UiChromeConfig.space12),
                  WorkspaceFeedbackBanner(
                    errorMessage: _logController.errorMessage,
                    infoMessage: null,
                    onDismiss: _logController.clearError,
                  ),
                  if (_logController.errorMessage != null)
                    const SizedBox(height: UiChromeConfig.space12),
                  Expanded(
                    child: _RunLogList(
                      strings: strings,
                      controller: _logController,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PolicyViolationBadge extends StatelessWidget {
  const _PolicyViolationBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('reports.policyViolation.badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space10,
        vertical: UiChromeConfig.space6,
      ),
      decoration: BoxDecoration(
        color: const Color(0x33B71C1C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            PhosphorIconsRegular.warningCircle,
            size: 14,
            color: Color(0xFFB71C1C),
          ),
          const SizedBox(width: UiChromeConfig.space6),
          Text(
            '$label: $count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFFB71C1C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunLogControls extends StatelessWidget {
  const _RunLogControls({
    required this.strings,
    required this.controller,
    required this.searchController,
  });

  final DesktopStrings strings;
  final RunLogViewerController controller;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final Widget searchField = TextField(
      controller: searchController,
      onChanged: controller.setQuery,
      decoration: InputDecoration(
        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        hintText: strings.reportsRunLogSearchHint,
      ),
    );

    final Widget filterField = DropdownButtonFormField<RunLogFilter>(
      key: ValueKey<RunLogFilter>(controller.filter),
      initialValue: controller.filter,
      isExpanded: true,
      decoration: InputDecoration(labelText: strings.reportsRunLogFilterLabel),
      items: <DropdownMenuItem<RunLogFilter>>[
        DropdownMenuItem<RunLogFilter>(
          value: RunLogFilter.all,
          child: Text(
            strings.reportsRunLogFilterAll,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem<RunLogFilter>(
          value: RunLogFilter.errors,
          child: Text(
            strings.reportsRunLogFilterErrors,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      onChanged: controller.isLoading
          ? null
          : (RunLogFilter? value) {
              if (value == null) {
                return;
              }
              controller.setFilter(value);
            },
    );

    final Widget refreshButton = IconButton(
      tooltip: strings.reportsRunLogRefreshTooltip,
      onPressed: controller.isLoading
          ? null
          : () => unawaited(controller.refresh()),
      icon: controller.isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(PhosphorIconsRegular.arrowsClockwise),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 860;
        if (compact) {
          return Column(
            children: <Widget>[
              searchField,
              const SizedBox(height: UiChromeConfig.space10),
              Row(
                children: <Widget>[
                  Expanded(child: filterField),
                  const SizedBox(width: UiChromeConfig.space10),
                  refreshButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: searchField),
            const SizedBox(width: UiChromeConfig.space10),
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: 220),
              child: filterField,
            ),
            const SizedBox(width: UiChromeConfig.space10),
            refreshButton,
          ],
        );
      },
    );
  }
}

class _RunLogList extends StatelessWidget {
  const _RunLogList({required this.strings, required this.controller});

  final DesktopStrings strings;
  final RunLogViewerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: UiSurfaceStyles.panel(context, tone: DesktopSurfaceTone.soft),
      child: controller.isLoading && controller.events.isEmpty
          ? const Center(child: CircularProgressIndicator.adaptive())
          : controller.events.isEmpty
          ? Center(
              child: Text(
                strings.reportsRunLogEmptyLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            )
          : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(
                vertical: UiChromeConfig.space10,
              ),
              itemCount: controller.events.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == controller.events.length) {
                  if (!controller.hasOlder) {
                    return const SizedBox(height: UiChromeConfig.space10);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: UiChromeConfig.space12,
                      right: UiChromeConfig.space12,
                      top: UiChromeConfig.space6,
                      bottom: UiChromeConfig.space12,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: controller.isLoadingMore
                          ? null
                          : () => unawaited(controller.loadOlder()),
                      icon: controller.isLoadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(PhosphorIconsRegular.arrowUp),
                      label: Text(strings.reportsRunLogLoadOlderAction),
                    ),
                  );
                }

                final entry = controller.events[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UiChromeConfig.space12,
                    vertical: UiChromeConfig.space6,
                  ),
                  child: _RunLogEntryTile(strings: strings, entry: entry),
                );
              },
            ),
    );
  }
}

class _RunLogEntryTile extends StatefulWidget {
  const _RunLogEntryTile({required this.strings, required this.entry});

  final DesktopStrings strings;
  final AppRunLogEventDto entry;

  @override
  State<_RunLogEntryTile> createState() => _RunLogEntryTileState();
}

class _RunLogEntryTileState extends State<_RunLogEntryTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final bool isError = _isError(entry);

    final Color text = Theme.of(context).colorScheme.onSurface;
    final Color indicator = isError
        ? const Color(0xFFB71C1C)
        : const Color(0xFF8E5C3A);

    final Gradient accent = isError
        ? const LinearGradient(
            colors: <Color>[Color(0xFFB71C1C), Color(0xFFFF8A65)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : PremiumWhiteBronzeTokens.bronzeGradientFor(entry.event.hashCode);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: UiSurfaceStyles.panel(
        context,
        tone: isError ? DesktopSurfaceTone.accent : DesktopSurfaceTone.base,
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        elevated: false,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(UiChromeConfig.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: UiChromeConfig.space10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: UiChromeConfig.space8,
                            runSpacing: 6,
                            children: <Widget>[
                              _EventChip(
                                label: entry.event,
                                accent: indicator,
                                error: isError,
                              ),
                              Text(
                                _formatTimestamp(entry.timestamp),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: text.withValues(alpha: 0.65),
                                    ),
                              ),
                              if (entry.data?['error_kind'] != null)
                                _MiniTag(
                                  label: entry.data!['error_kind'].toString(),
                                  tone: const Color(0xFFB71C1C),
                                ),
                              if (entry.data?['task_id'] != null)
                                _MiniTag(
                                  label: 'task ${entry.data!['task_id']}',
                                  tone: const Color(0xFF44576D),
                                ),
                              if (entry.data?['subtask_id'] != null)
                                _MiniTag(
                                  label: 'subtask ${entry.data!['subtask_id']}',
                                  tone: const Color(0xFF44576D),
                                ),
                            ],
                          ),
                          const SizedBox(height: UiChromeConfig.space6),
                          Text(
                            entry.message?.trim().isEmpty ?? true
                                ? '(no message)'
                                : entry.message!.trim(),
                            maxLines: _expanded ? 8 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: UiChromeConfig.space10),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        PhosphorIconsRegular.caretDown,
                        size: 18,
                        color: text.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? _details(context, entry)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _details(BuildContext context, AppRunLogEventDto entry) {
    final Map<String, Object?> payload = <String, Object?>{
      'timestamp': entry.timestamp,
      'event': entry.event,
      'message': entry.message,
      if (entry.data != null) 'data': entry.data,
    };

    final String json = RunLogViewerController.prettyJson(payload);
    final bool hasJson = json.trim().isNotEmpty;

    final Color subdued = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.7);

    final String? monospace = switch (Theme.of(context).platform) {
      TargetPlatform.macOS => 'Menlo',
      TargetPlatform.windows => 'Consolas',
      TargetPlatform.linux => 'monospace',
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(top: UiChromeConfig.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasJson)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(UiChromeConfig.space12),
              decoration: UiSurfaceStyles.panel(
                context,
                tone: DesktopSurfaceTone.strong,
                borderRadius: BorderRadius.circular(
                  UiChromeConfig.controlRadius,
                ),
                elevated: false,
              ),
              child: SelectableText(
                json,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: monospace,
                  color: subdued,
                  height: 1.25,
                ),
              ),
            ),
          if (hasJson) const SizedBox(height: UiChromeConfig.space10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: hasJson
                  ? () => unawaited(_copyJson(context, json))
                  : null,
              icon: const Icon(PhosphorIconsRegular.copy, size: 16),
              label: Text(widget.strings.reportsRunLogCopyJsonAction),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyJson(BuildContext context, String json) async {
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.reportsRunLogCopiedToast)),
    );
  }

  bool _isError(AppRunLogEventDto entry) {
    final String event = entry.event.toLowerCase();
    if (event.contains('error') || event.contains('reject')) {
      return true;
    }
    if (entry.data == null) {
      return false;
    }
    final String? kind = entry.data!['error_kind']?.toString();
    return kind != null && kind.trim().isNotEmpty;
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.trim().isEmpty) {
      return '(unknown time)';
    }
    try {
      final DateTime parsed = DateTime.parse(timestamp).toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
          '${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}';
    } catch (_) {
      return timestamp;
    }
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.label,
    required this.accent,
    required this.error,
  });

  final String label;
  final Color accent;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final Color text = Theme.of(context).colorScheme.onSurface;
    final Color fill = error
        ? accent.withValues(alpha: 0.12)
        : Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.82);
    final Color border = error
        ? accent.withValues(alpha: 0.35)
        : Theme.of(context).dividerColor.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: border.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: text.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tone.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: tone,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
