// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../../../models/workspace_models.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_motion_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import '../../../shared/animated_delete_badge.dart';
import 'backlog_board_state.dart';

/// Draggable task card with hover-reveal delete badge and shrink animation.
class DraggableTaskCard extends StatefulWidget {
  const DraggableTaskCard({
    super.key,
    required this.cardKey,
    required this.task,
    required this.status,
    required this.selected,
    required this.onTap,
    required this.priorityLabel,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onDeleteRequested,
  });

  final GlobalKey cardKey;
  final BacklogTask task;
  final BacklogTaskStatus status;
  final bool selected;
  final VoidCallback onTap;
  final String priorityLabel;
  final ValueChanged<BacklogActiveDrag> onDragStarted;
  final ValueChanged<BacklogDragEnd> onDragEnded;
  final VoidCallback onDeleteRequested;

  @override
  State<DraggableTaskCard> createState() => _DraggableTaskCardState();
}

class _DraggableTaskCardState extends State<DraggableTaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shrinkController;
  late final Animation<double> _shrinkAnimation;

  /// Buffered pointer offset relative to card top-left, captured in
  /// [onPointerDown] and applied to [BacklogActiveDrag] in [onDragStarted].
  Offset? _pendingAnchorOffset;

  /// Tracks whether the mouse is hovering over this card.
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _shrinkController = AnimationController(
      vsync: this,
      duration: UiMotionConfig.kanbanSourceShrinkDuration,
    );
    _shrinkAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _shrinkController,
        curve: UiMotionConfig.kanbanGapCurve,
      ),
    );
  }

  @override
  void dispose() {
    _shrinkController.dispose();
    super.dispose();
  }

  Widget _buildCardContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.task.title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: UiChromeConfig.space6),
        Text(
          widget.task.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: UiChromeConfig.space8),
        Wrap(
          spacing: UiChromeConfig.space8,
          runSpacing: UiChromeConfig.space8,
          children: <Widget>[
            Chip(label: Text(widget.priorityLabel)),
            Chip(label: Text(widget.task.assignedAgent)),
          ],
        ),
      ],
    );
  }

  /// Half the delete button that overflows outside the card edge.
  static const double _deleteButtonOverflow = 8;

  Widget _buildCardBody(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // Extra hit-test area so the hover zone covers the overflow badge.
      hitTestBehavior: HitTestBehavior.deferToChild,
      child: Padding(
        // Reserve space above & to the right for the overflowing badge.
        padding: const EdgeInsets.only(
          top: _deleteButtonOverflow,
          right: _deleteButtonOverflow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // ── Card surface ──
            Material(
              key: Key('backlog.task.${widget.task.id}'),
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  UiChromeConfig.controlRadius,
                ),
                onTap: widget.onTap,
                child: Container(
                  key: widget.cardKey,
                  padding: const EdgeInsets.all(UiChromeConfig.space10),
                  decoration: UiSurfaceStyles.panel(
                    context,
                    tone: widget.selected
                        ? DesktopSurfaceTone.accent
                        : DesktopSurfaceTone.base,
                    borderRadius: BorderRadius.circular(
                      UiChromeConfig.controlRadius,
                    ),
                    elevated: widget.selected,
                  ),
                  child: _buildCardContent(context),
                ),
              ),
            ),
            // ── Delete badge – overflows the card corner ──
            Positioned(
              top: -_deleteButtonOverflow,
              right: -_deleteButtonOverflow,
              child: AnimatedDeleteButton(
                visible: _hovered,
                onPressed: widget.onDeleteRequested,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lightweight card copy for the drag feedback overlay (no GlobalKeys).
  Widget _buildFeedbackBody(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(UiChromeConfig.space10),
        decoration: UiSurfaceStyles.panel(
          context,
          tone: widget.selected
              ? DesktopSurfaceTone.accent
              : DesktopSurfaceTone.base,
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          elevated: widget.selected,
        ),
        child: _buildCardContent(context),
      ),
    );
  }

  /// Ghost card for the source placeholder (no GlobalKeys).
  Widget _buildGhostBody(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(UiChromeConfig.space10),
        decoration: UiSurfaceStyles.panel(
          context,
          tone: DesktopSurfaceTone.base,
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        ),
        child: _buildCardContent(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget cardBody = _buildCardBody(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double feedbackWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 280;
        return Listener(
          onPointerDown: (PointerDownEvent event) {
            _pendingAnchorOffset = event.localPosition;
          },
          child: Draggable<BacklogDragPayload>(
            data: BacklogDragPayload(
              taskId: widget.task.id,
              sourceStatus: widget.status,
            ),
            dragAnchorStrategy: childDragAnchorStrategy,
            onDragStarted: () {
              _shrinkController.forward();
              final RenderObject? rawRenderObject = context.findRenderObject();
              final double measuredHeight =
                  rawRenderObject is RenderBox && rawRenderObject.hasSize
                  ? rawRenderObject.size.height
                  : kDefaultCardHeight;
              final BacklogActiveDrag drag = BacklogActiveDrag(
                taskId: widget.task.id,
                sourceStatus: widget.status,
                height: measuredHeight,
              );
              drag.anchorOffset = _pendingAnchorOffset;
              widget.onDragStarted(drag);
            },
            onDragEnd: (DraggableDetails details) {
              _shrinkController.reverse();
              widget.onDragEnded(
                BacklogDragEnd(
                  taskId: widget.task.id,
                  sourceStatus: widget.status,
                  wasAccepted: details.wasAccepted,
                ),
              );
            },
            feedback: SizedBox(
              width: feedbackWidth,
              child: Opacity(opacity: 0.94, child: _buildFeedbackBody(context)),
            ),
            childWhenDragging: SizeTransition(
              sizeFactor: _shrinkAnimation,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: 0.30,
                child: IgnorePointer(child: _buildGhostBody(context)),
              ),
            ),
            child: cardBody,
          ),
        );
      },
    );
  }
}
