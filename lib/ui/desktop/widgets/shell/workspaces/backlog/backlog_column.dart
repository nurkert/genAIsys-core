// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../localization/desktop_localization.dart';
import '../../../../models/workspace_models.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_motion_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import '../../../shared/snap_position_overlay.dart';
import 'backlog_board_state.dart';
import 'backlog_task_card.dart';

// ---------------------------------------------------------------------------
// BacklogColumn: single kanban column with animated-gap drag-and-drop
// ---------------------------------------------------------------------------

class BacklogColumn extends StatefulWidget {
  const BacklogColumn({
    super.key,
    required this.title,
    required this.status,
    required this.tasks,
    required this.selectedTaskId,
    required this.onTaskSelected,
    required this.onTaskDropped,
    required this.onTaskDeleted,
    required this.priorityLabelBuilder,
    required this.activeDrag,
    required this.onTaskDragStarted,
    required this.onTaskDragEnded,
    this.onCreateTaskRequested,
  });

  final String title;
  final BacklogTaskStatus status;
  final List<BacklogTask> tasks;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;
  final Future<void> Function({
    required BacklogDragPayload payload,
    required BacklogTaskStatus destination,
    required int insertionIndex,
  })
  onTaskDropped;
  final Future<void> Function(String taskId) onTaskDeleted;
  final String Function(BacklogTaskPriority priority) priorityLabelBuilder;
  final BacklogActiveDrag? activeDrag;
  final ValueChanged<BacklogActiveDrag> onTaskDragStarted;
  final ValueChanged<BacklogDragEnd> onTaskDragEnded;
  final VoidCallback? onCreateTaskRequested;

  @override
  State<BacklogColumn> createState() => _BacklogColumnState();
}

class _BacklogColumnState extends State<BacklogColumn> {
  final _ColumnDragState _dragState = _ColumnDragState();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  Timer? _autoScrollTimer;

  /// Eagerly-cached active drag reference. Updated immediately in the
  /// onDragStarted callback (same frame), before the parent rebuilds and
  /// before [widget.activeDrag] becomes available.
  BacklogActiveDrag? _cachedActiveDrag;

  /// Task ID currently in the snap-settle overlay animation.
  /// The real card is hidden (opacity 0) while this is non-null.
  String? _settlingTaskId;
  OverlayEntry? _settleOverlayEntry;

  @override
  void dispose() {
    _stopAutoScroll();
    _cancelSettleAnimation();
    _scrollController.dispose();
    _dragState.dispose();
    super.dispose();
  }

  void _cancelSettleAnimation() {
    _settleOverlayEntry?.remove();
    _settleOverlayEntry = null;
    _settlingTaskId = null;
  }

  // -- Insertion index computation (single column-level DragTarget) ---------

  int _computeInsertionIndex(DragTargetDetails<BacklogDragPayload> details) {
    final Offset resolvedPointer = _resolvedPointerOffset(details);
    final String draggedTaskId = details.data.taskId;

    // Walk task cards using their actual rendered positions.
    // Skip the dragged card itself — its RenderBox size is unreliable
    // during the source-shrink animation.
    for (int i = 0; i < widget.tasks.length; i++) {
      if (widget.tasks[i].id == draggedTaskId) continue;

      final _CardMeasurement? m = _measureCard(i);
      if (m == null) continue;

      final double cardCenter = m.globalTop + (m.height / 2);
      final double hysteresis =
          m.height * UiChromeConfig.kanbanInsertionHysteresisRatio;

      final int? currentPreview = _dragState.previewInsertionIndex;
      if (currentPreview == i) {
        if (resolvedPointer.dy <= cardCenter + hysteresis) return i;
      } else if (currentPreview == i + 1) {
        if (resolvedPointer.dy <= cardCenter - hysteresis) return i;
      } else {
        if (resolvedPointer.dy <= cardCenter) return i;
      }
    }
    return widget.tasks.length;
  }

  _CardMeasurement? _measureCard(int index) {
    final BacklogTask task = widget.tasks[index];
    final BuildContext? ctx = _cardKeys[task.id]?.currentContext;
    if (ctx == null) return null;
    final RenderObject? obj = ctx.findRenderObject();
    if (obj is! RenderBox || !obj.hasSize) return null;
    final Offset globalTopLeft = obj.localToGlobal(Offset.zero);
    return _CardMeasurement(
      globalTop: globalTopLeft.dy,
      height: obj.size.height,
    );
  }

  Offset _resolvedPointerOffset(
    DragTargetDetails<BacklogDragPayload> details,
  ) {
    // Prefer the eagerly-cached drag (available same-frame), fall back to
    // widget.activeDrag which is available after the parent rebuilds.
    final BacklogActiveDrag? drag = _cachedActiveDrag ?? widget.activeDrag;
    final Offset? anchorOffset = drag?.anchorOffset;
    if (anchorOffset != null) {
      return details.offset + anchorOffset;
    }
    return details.offset;
  }

  // -- Auto-scroll when dragging near edges ---------------------------------

  double _currentAutoScrollDelta = 0;

  void _handleAutoScroll(DragTargetDetails<BacklogDragPayload> details) {
    final RenderObject? rawRenderObject = _listKey.currentContext
        ?.findRenderObject();
    if (rawRenderObject is! RenderBox ||
        !rawRenderObject.hasSize ||
        !_scrollController.hasClients) {
      _stopAutoScroll();
      return;
    }

    final Offset local = rawRenderObject.globalToLocal(details.offset);
    final double listHeight = rawRenderObject.size.height;
    const double zone = UiChromeConfig.kanbanAutoScrollZone;
    const double maxSpeed = UiChromeConfig.kanbanAutoScrollMaxSpeed;

    double delta = 0;
    if (local.dy < zone && local.dy >= 0) {
      final double proximity = 1 - (local.dy / zone).clamp(0.0, 1.0);
      delta = -maxSpeed * proximity;
    } else if (local.dy > listHeight - zone && local.dy <= listHeight) {
      final double proximity =
          1 - ((listHeight - local.dy) / zone).clamp(0.0, 1.0);
      delta = maxSpeed * proximity;
    }

    if (delta == 0) {
      _stopAutoScroll();
      return;
    }

    _currentAutoScrollDelta = delta;
    _autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollController.hasClients) return;
      final double newOffset =
          (_scrollController.offset + _currentAutoScrollDelta / 60).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
      _scrollController.jumpTo(newOffset);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _currentAutoScrollDelta = 0;
  }

  // -- Drop handling --------------------------------------------------------

  void _handleTaskDrop({
    required BacklogDragPayload payload,
    required int insertionIndex,
    required Offset dropOffset,
    required double feedbackWidth,
  }) {
    // Clear drag state synchronously to avoid accessing disposed listeners
    // after the async widget.onTaskDropped triggers a full rebuild.
    _dragState.clear();

    // Remember the drop position so we can run a snap animation.
    _pendingSnapDropOffset = dropOffset;
    _pendingSnapFeedbackWidth = feedbackWidth;
    _pendingSnapTaskId = payload.taskId;

    // Fire the drop handler. The board's _handleTaskDrop calls setState
    // synchronously, which schedules a rebuild for the next frame.
    unawaited(
      widget.onTaskDropped(
        payload: payload,
        destination: widget.status,
        insertionIndex: insertionIndex,
      ),
    );

    // Schedule the snap animation to start after the next frame, when the
    // card has been laid out at its final position.
    _maybeStartSnapAnimation();
  }

  // -- Snap-settle animation ------------------------------------------------

  Offset? _pendingSnapDropOffset;
  double? _pendingSnapFeedbackWidth;
  String? _pendingSnapTaskId;

  /// Called after a state update has placed the card in its final list
  /// position. Measures the card's rendered location and kicks off the
  /// overlay snap animation.
  void _maybeStartSnapAnimation() {
    final String? taskId = _pendingSnapTaskId;
    final Offset? dropOffset = _pendingSnapDropOffset;
    final double? feedbackWidth = _pendingSnapFeedbackWidth;
    _pendingSnapTaskId = null;
    _pendingSnapDropOffset = null;
    _pendingSnapFeedbackWidth = null;

    if (taskId == null || dropOffset == null || feedbackWidth == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final GlobalKey? key = _cardKeys[taskId];
      if (key == null) return;
      final BuildContext? ctx = key.currentContext;
      if (ctx == null) return;
      final RenderObject? obj = ctx.findRenderObject();
      if (obj is! RenderBox || !obj.hasSize) return;

      final Offset finalGlobal = obj.localToGlobal(Offset.zero);
      final double distance = (dropOffset - finalGlobal).distance;

      // Skip animation for very short distances — just show the card.
      if (distance < UiMotionConfig.kanbanSnapMinDistance) {
        return;
      }

      _startSettleOverlay(
        taskId: taskId,
        from: dropOffset,
        to: finalGlobal,
        cardSize: obj.size,
        feedbackWidth: feedbackWidth,
        distance: distance,
      );
    });
  }

  void _startSettleOverlay({
    required String taskId,
    required Offset from,
    required Offset to,
    required Size cardSize,
    required double feedbackWidth,
    required double distance,
  }) {
    // Cancel any in-progress settle animation.
    _cancelSettleAnimation();

    setState(() {
      _settlingTaskId = taskId;
    });

    // Calculate distance-based duration.
    final double t =
        ((distance - UiMotionConfig.kanbanSnapMinDistance) /
                (UiMotionConfig.kanbanSnapMaxDistance -
                    UiMotionConfig.kanbanSnapMinDistance))
            .clamp(0.0, 1.0);
    final Duration duration = Duration(
      milliseconds:
          UiMotionConfig.kanbanSettleMinDuration.inMilliseconds +
          ((UiMotionConfig.kanbanSettleMaxDuration.inMilliseconds -
                      UiMotionConfig.kanbanSettleMinDuration.inMilliseconds) *
                  t)
              .round(),
    );

    // Find the BacklogTask data to build a matching card widget.
    BacklogTask? task;
    for (final BacklogTask t in widget.tasks) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    if (task == null) {
      // Task no longer in this column — abort.
      setState(() {
        _settlingTaskId = null;
      });
      return;
    }

    final Widget cardContent = _buildSettleCardContent(task);

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) {
        return SnapOverlay(
          from: from,
          to: to,
          width: feedbackWidth,
          duration: duration,
          curve: UiMotionConfig.kanbanSettleCurve,
          onComplete: () {
            if (!mounted) return;
            _settleOverlayEntry?.remove();
            _settleOverlayEntry = null;
            setState(() {
              _settlingTaskId = null;
            });
          },
          child: cardContent,
        );
      },
    );

    _settleOverlayEntry = entry;
    Overlay.of(context).insert(entry);
  }

  /// Builds a visual copy of a task card for the settle overlay.
  Widget _buildSettleCardContent(BacklogTask task) {
    final bool selected = task.id == widget.selectedTaskId;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(UiChromeConfig.space10),
        decoration: UiSurfaceStyles.panel(
          context,
          tone: selected ? DesktopSurfaceTone.accent : DesktopSurfaceTone.base,
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          elevated: selected,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              task.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: UiChromeConfig.space6),
            Text(
              task.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: UiChromeConfig.space8),
            Wrap(
              spacing: UiChromeConfig.space8,
              runSpacing: UiChromeConfig.space8,
              children: <Widget>[
                Chip(label: Text(widget.priorityLabelBuilder(task.priority))),
                Chip(label: Text(task.assignedAgent)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -- Card keys for measurement --------------------------------------------

  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};

  GlobalKey _cardKeyFor(String taskId) {
    return _cardKeys.putIfAbsent(taskId, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    final bool showCreateTaskAction =
        widget.onCreateTaskRequested != null &&
        (widget.status == BacklogTaskStatus.todo ||
            widget.status == BacklogTaskStatus.blocked);

    return DragTarget<BacklogDragPayload>(
      onMove: (DragTargetDetails<BacklogDragPayload> details) {
        if (widget.tasks.isEmpty) {
          _dragState.updatePreview(0);
        } else {
          final int index = _computeInsertionIndex(details);
          _dragState.updatePreview(index);
        }
        _handleAutoScroll(details);
      },
      onAcceptWithDetails: (DragTargetDetails<BacklogDragPayload> details) {
        _stopAutoScroll();
        final int insertionIndex =
            _dragState.previewInsertionIndex ??
            (widget.tasks.isEmpty ? 0 : _computeInsertionIndex(details));

        // Capture the feedback widget's global position for the snap animation.
        final Offset dropOffset = details.offset;

        // Use the column's layout width for the feedback card.
        final RenderObject? columnObj = _listKey.currentContext
            ?.findRenderObject();
        final double feedbackWidth = columnObj is RenderBox && columnObj.hasSize
            ? columnObj.size.width -
                  (UiChromeConfig.space10 * 2) // list padding
            : 280;

        _handleTaskDrop(
          payload: details.data,
          insertionIndex: insertionIndex,
          dropOffset: dropOffset,
          feedbackWidth: feedbackWidth,
        );
      },
      onLeave: (BacklogDragPayload? _) {
        _stopAutoScroll();
        _dragState.clear();
      },
      builder:
          (
            BuildContext context,
            List<BacklogDragPayload?> candidateData,
            List<dynamic> rejectedData,
          ) {
            return AnimatedContainer(
              key: Key('backlog.column.${widget.status.name}'),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: UiSurfaceStyles.panel(
                context,
                tone: candidateData.isNotEmpty
                    ? DesktopSurfaceTone.accent
                    : DesktopSurfaceTone.muted,
                borderRadius: BorderRadius.circular(UiChromeConfig.cardRadius),
                elevated: false,
                shadows: false,
              ),
              child: Column(
                children: <Widget>[
                  // Column header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      UiChromeConfig.space12,
                      UiChromeConfig.space10,
                      UiChromeConfig.space12,
                      UiChromeConfig.space8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (showCreateTaskAction) ...<Widget>[
                                const SizedBox(width: UiChromeConfig.space4),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  tooltip: context.strings.create,
                                  onPressed: widget.onCreateTaskRequested,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 22,
                                    minHeight: 22,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${widget.tasks.length}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: UiChromeConfig.space6),
                  // Task list with animated gap insertion
                  Expanded(child: _buildTaskList(context)),
                ],
              ),
            );
          },
    );
  }

  Widget _buildTaskList(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return ListenableBuilder(
        listenable: _dragState,
        builder: (BuildContext context, Widget? _) {
          final bool active = _dragState.previewInsertionIndex == 0;
          final Color accent = Theme.of(context).colorScheme.primary;
          final double height = active
              ? (widget.activeDrag?.height ?? kDefaultCardHeight)
              : 0.0;
          return ListView(
            key: _listKey,
            controller: _scrollController,
            padding: const EdgeInsets.all(UiChromeConfig.space10),
            children: <Widget>[
              AnimatedContainer(
                duration: active
                    ? UiMotionConfig.kanbanGapOpenDuration
                    : UiMotionConfig.kanbanGapCloseDuration,
                curve: UiMotionConfig.kanbanGapCurve,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    UiChromeConfig.controlRadius,
                  ),
                  color: active
                      ? accent.withValues(alpha: 0.10)
                      : Colors.transparent,
                ),
              ),
            ],
          );
        },
      );
    }

    // itemCount = tasks.length + 1 (trailing gap slot for "insert at end").
    return ListView.builder(
      key: _listKey,
      controller: _scrollController,
      padding: const EdgeInsets.all(UiChromeConfig.space10),
      itemCount: widget.tasks.length + 1,
      itemBuilder: (BuildContext context, int index) {
        // Trailing gap (insert at end position).
        if (index == widget.tasks.length) {
          return _AnimatedGapWidget(
            dragState: _dragState,
            gapIndex: widget.tasks.length,
            gapHeight: widget.activeDrag?.height ?? kDefaultCardHeight,
          );
        }

        final BacklogTask task = widget.tasks[index];
        final bool isSettling = _settlingTaskId == task.id;
        return _AnimatedGapCard(
          key: ValueKey<String>('backlog.gap.${task.id}'),
          dragState: _dragState,
          gapIndex: index,
          gapHeight: widget.activeDrag?.height ?? kDefaultCardHeight,
          child: RepaintBoundary(
            child: Opacity(
              opacity: isSettling ? 0 : 1,
              child: DraggableTaskCard(
                cardKey: _cardKeyFor(task.id),
                task: task,
                status: widget.status,
                selected: task.id == widget.selectedTaskId,
                onTap: () => widget.onTaskSelected(task.id),
                priorityLabel: widget.priorityLabelBuilder(task.priority),
                onDragStarted: (BacklogActiveDrag drag) {
                  _cachedActiveDrag = drag;
                  _dragState.activateSourcePlaceholder(index);
                  widget.onTaskDragStarted(drag);
                },
                onDragEnded: (BacklogDragEnd details) {
                  _cachedActiveDrag = null;
                  if (!details.wasAccepted) {
                    _dragState.clear();
                  }
                  widget.onTaskDragEnded(details);
                },
                onDeleteRequested: () {
                  unawaited(widget.onTaskDeleted(task.id));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _ColumnDragState: reactive drag state scoped to a single column
// ---------------------------------------------------------------------------

class _ColumnDragState extends ChangeNotifier {
  int? _previewInsertionIndex;

  int? get previewInsertionIndex => _previewInsertionIndex;

  void updatePreview(int index) {
    if (_previewInsertionIndex == index) return;
    _previewInsertionIndex = index;
    notifyListeners();
  }

  void activateSourcePlaceholder(int index) {
    if (_previewInsertionIndex == index) return;
    _previewInsertionIndex = index;
    notifyListeners();
  }

  void clear() {
    if (_previewInsertionIndex == null) return;
    _previewInsertionIndex = null;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// _AnimatedGapCard: per-card wrapper that smoothly opens a gap above itself
// ---------------------------------------------------------------------------

class _AnimatedGapCard extends StatefulWidget {
  const _AnimatedGapCard({
    super.key,
    required this.dragState,
    required this.gapIndex,
    required this.gapHeight,
    required this.child,
  });

  final _ColumnDragState dragState;
  final int gapIndex;
  final double gapHeight;
  final Widget child;

  @override
  State<_AnimatedGapCard> createState() => _AnimatedGapCardState();
}

class _AnimatedGapCardState extends State<_AnimatedGapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _gapAnimation;
  bool _showGap = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: UiMotionConfig.kanbanGapOpenDuration,
    );
    _gapAnimation = _buildAnimation();
    widget.dragState.addListener(_onDragStateChanged);
    _syncWithDragState();
  }

  @override
  void didUpdateWidget(covariant _AnimatedGapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gapHeight != widget.gapHeight) {
      _gapAnimation = _buildAnimation();
    }
    if (oldWidget.dragState != widget.dragState) {
      oldWidget.dragState.removeListener(_onDragStateChanged);
      widget.dragState.addListener(_onDragStateChanged);
    }
    _syncWithDragState();
  }

  @override
  void dispose() {
    widget.dragState.removeListener(_onDragStateChanged);
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _buildAnimation() {
    return Tween<double>(begin: 0, end: widget.gapHeight).animate(
      CurvedAnimation(
        parent: _controller,
        curve: UiMotionConfig.kanbanGapCurve,
      ),
    );
  }

  void _onDragStateChanged() {
    _syncWithDragState();
  }

  void _syncWithDragState() {
    final bool shouldShowGap =
        widget.dragState.previewInsertionIndex == widget.gapIndex;
    if (shouldShowGap == _showGap) return;
    _showGap = shouldShowGap;

    if (shouldShowGap) {
      _controller.duration = UiMotionConfig.kanbanGapOpenDuration;
      _controller.forward();
    } else {
      _controller.duration = UiMotionConfig.kanbanGapCloseDuration;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _gapAnimation,
      builder: (BuildContext context, Widget? child) {
        final double gap = _gapAnimation.value;
        return Padding(
          padding: EdgeInsets.only(
            top: gap > 0 ? gap + UiChromeConfig.kanbanEdgeGap : 0,
            bottom: UiChromeConfig.kanbanCardGap,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// _AnimatedGapWidget: trailing gap for "insert at end" position
// ---------------------------------------------------------------------------

class _AnimatedGapWidget extends StatefulWidget {
  const _AnimatedGapWidget({
    required this.dragState,
    required this.gapIndex,
    required this.gapHeight,
  });

  final _ColumnDragState dragState;
  final int gapIndex;
  final double gapHeight;

  @override
  State<_AnimatedGapWidget> createState() => _AnimatedGapWidgetState();
}

class _AnimatedGapWidgetState extends State<_AnimatedGapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _gapAnimation;
  bool _showGap = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: UiMotionConfig.kanbanGapOpenDuration,
    );
    _gapAnimation = _buildAnimation();
    widget.dragState.addListener(_onDragStateChanged);
    _syncWithDragState();
  }

  @override
  void didUpdateWidget(covariant _AnimatedGapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gapHeight != widget.gapHeight) {
      _gapAnimation = _buildAnimation();
    }
    if (oldWidget.dragState != widget.dragState) {
      oldWidget.dragState.removeListener(_onDragStateChanged);
      widget.dragState.addListener(_onDragStateChanged);
    }
    _syncWithDragState();
  }

  @override
  void dispose() {
    widget.dragState.removeListener(_onDragStateChanged);
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _buildAnimation() {
    return Tween<double>(begin: 0, end: widget.gapHeight).animate(
      CurvedAnimation(
        parent: _controller,
        curve: UiMotionConfig.kanbanGapCurve,
      ),
    );
  }

  void _onDragStateChanged() {
    _syncWithDragState();
  }

  void _syncWithDragState() {
    final bool shouldShowGap =
        widget.dragState.previewInsertionIndex == widget.gapIndex;
    if (shouldShowGap == _showGap) return;
    _showGap = shouldShowGap;

    if (shouldShowGap) {
      _controller.duration = UiMotionConfig.kanbanGapOpenDuration;
      _controller.forward();
    } else {
      _controller.duration = UiMotionConfig.kanbanGapCloseDuration;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _gapAnimation,
      builder: (BuildContext context, Widget? _) {
        final double height = _gapAnimation.value;
        if (height < 1) return const SizedBox.shrink();
        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
            color: accent.withValues(alpha: 0.10),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _CardMeasurement: card position/size snapshot for insertion calculations
// ---------------------------------------------------------------------------

@immutable
class _CardMeasurement {
  const _CardMeasurement({required this.globalTop, required this.height});

  final double globalTop;
  final double height;
}
