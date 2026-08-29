// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../controllers/project_workspace_controller.dart';
import '../../../localization/desktop_localization.dart';
import '../../../models/workspace_models.dart';
import '../../../theme/premium_white_bronze_tokens.dart';
import '../../../theme/ui_chrome_config.dart';
import '../../../theme/ui_surface_styles.dart';
import 'workspace_header.dart';

@immutable
class ChatWorkspacePresentation {
  const ChatWorkspacePresentation({
    this.titleOverride,
    this.includeProjectRootMessage = true,
  });

  final String? titleOverride;
  final bool includeProjectRootMessage;
}

class ChatWorkspaceView extends StatefulWidget {
  const ChatWorkspaceView({
    super.key,
    required this.controller,
    this.presentation = const ChatWorkspacePresentation(),
  });

  final ProjectWorkspaceController controller;
  final ChatWorkspacePresentation presentation;

  @override
  State<ChatWorkspaceView> createState() => _ChatWorkspaceViewState();
}

class _ChatWorkspaceViewState extends State<ChatWorkspaceView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _initialized = false;
  int _messageCounter = 100;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final strings = context.strings;
    final String projectRoot = widget.controller.projectRootPath.trim();
    final List<ChatMessage> initialMessages = <ChatMessage>[
      ChatMessage(
        id: 'm1',
        author: strings.chatAssistantName,
        content: strings.chatWelcomeMessage,
        fromAssistant: true,
        type: ChatMessageType.system,
      ),
    ];

    if (widget.presentation.includeProjectRootMessage) {
      initialMessages.add(
        ChatMessage(
          id: 'm2',
          author: strings.chatAssistantName,
          content: projectRoot.isEmpty
              ? strings.chatNoProjectRootAttachedMessage
              : '${strings.chatConnectedProjectRootPrefix} $projectRoot',
          fromAssistant: true,
          type: ChatMessageType.system,
        ),
      );
    }

    _messages = initialMessages;
    _initialized = true;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final String content = _inputController.text.trim();
    if (content.isEmpty) {
      return;
    }

    final strings = context.strings;
    final ChatMessage userMessage = ChatMessage(
      id: 'user-${_messageCounter++}',
      author: strings.chatUserDisplayName,
      content: content,
      fromAssistant: false,
      status: ChatMessageStatus.sending,
    );

    setState(() {
      _messages = <ChatMessage>[..._messages, userMessage];
      _inputController.clear();
    });
    _scrollToBottom();

    await widget.controller.runTaskCycle(prompt: content);
    if (!mounted) {
      return;
    }

    final bool isError = widget.controller.errorMessage != null;
    final String reply = isError
        ? 'Task cycle failed: ${widget.controller.errorMessage}'
        : _buildSuccessReply();
    final ChatMessage assistantReply = ChatMessage(
      id: 'assistant-${_messageCounter++}',
      author: strings.chatAssistantName,
      content: reply,
      fromAssistant: true,
      type: isError ? ChatMessageType.error : ChatMessageType.text,
    );
    setState(() {
      _messages = <ChatMessage>[..._messages, assistantReply];
    });
    _scrollToBottom();
  }

  String _buildSuccessReply() {
    final String? activeTaskTitle = widget.controller.status?.activeTaskTitle;
    final String resolvedTitle =
        activeTaskTitle == null || activeTaskTitle.isEmpty
        ? 'No active task'
        : activeTaskTitle;
    final String? reviewStatus = widget.controller.reviewStatus?.status;
    final String resolvedReview = reviewStatus == null || reviewStatus.isEmpty
        ? 'n/a'
        : reviewStatus;
    return 'Task cycle executed. Active task: $resolvedTitle. Review: '
        '$resolvedReview.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final String headerTitle =
        widget.presentation.titleOverride ?? strings.chatTitle;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius panelRadius = BorderRadius.circular(
      UiChromeConfig.cardRadius,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        WorkspaceHeader(title: headerTitle, subtitle: null, seed: 51),
        const SizedBox(height: UiChromeConfig.space12),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: -2,
                height: dark ? 64 : 56,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(UiChromeConfig.cardRadius),
                        bottomRight: Radius.circular(UiChromeConfig.cardRadius),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? 0.18 : 0.08,
                          ),
                          blurRadius: dark ? 24 : 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRRect(
                  clipBehavior: Clip.hardEdge,
                  borderRadius: panelRadius,
                  child: Container(
                    decoration: UiSurfaceStyles.panel(
                      context,
                      tone: DesktopSurfaceTone.soft,
                      borderRadius: panelRadius,
                      shadows: false,
                    ),
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(
                              UiChromeConfig.space16,
                            ),
                            itemCount:
                                _messages.length +
                                1, // +1 for thinking indicator
                            itemBuilder: (BuildContext context, int index) {
                              if (index == _messages.length) {
                                return _ThinkingIndicator(
                                  notifier: widget
                                      .controller
                                      .actionInProgressNotifier,
                                );
                              }

                              final ChatMessage message = _messages[index];
                              final bool showTimestamp = _shouldShowTimestamp(
                                index,
                              );

                              return Column(
                                children: <Widget>[
                                  if (showTimestamp)
                                    _TimestampDivider(
                                      timestamp: message.timestamp,
                                    ),
                                  if (message.type == ChatMessageType.system)
                                    _SystemBubble(message: message)
                                  else if (message.fromAssistant)
                                    _AssistantBubble(message: message)
                                  else
                                    _UserBubble(message: message),
                                  const SizedBox(height: UiChromeConfig.space6),
                                ],
                              );
                            },
                          ),
                        ),
                        _ChatInputBar(
                          inputController: _inputController,
                          focusNode: _inputFocusNode,
                          actionNotifier:
                              widget.controller.actionInProgressNotifier,
                          hintText: strings.chatInputPlaceholder,
                          onSend: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowTimestamp(int index) {
    if (index == 0) {
      return true;
    }
    final DateTime current = _messages[index].timestamp;
    final DateTime previous = _messages[index - 1].timestamp;
    return current.difference(previous).inMinutes >= 2;
  }
}

// ---------------------------------------------------------------------------
// Timestamp divider
// ---------------------------------------------------------------------------

class _TimestampDivider extends StatelessWidget {
  const _TimestampDivider({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final Color muted = UiSurfaceStyles.mutedOnSurface(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UiChromeConfig.space10),
      child: Center(
        child: Text(
          _formatTimestamp(timestamp),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final DateTime local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

// ---------------------------------------------------------------------------
// System bubble (centered, muted, no bubble)
// ---------------------------------------------------------------------------

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: UiChromeConfig.space4),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: UiSurfaceStyles.mutedOnSurface(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assistant bubble (left-aligned, soft surface, avatar)
// ---------------------------------------------------------------------------

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isError = message.type == ChatMessageType.error;
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: PremiumWhiteBronzeTokens.bronzeGradientFor(51),
            ),
            child: const Center(
              child: Icon(
                PhosphorIconsRegular.robot,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: UiChromeConfig.space10),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiChromeConfig.space14,
                  vertical: UiChromeConfig.space10,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: isError
                      ? Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.5),
                        )
                      : null,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  message.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User bubble (right-aligned, bronze tint)
// ---------------------------------------------------------------------------

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UiChromeConfig.space14,
            vertical: UiChromeConfig.space10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? <Color>[
                      PremiumWhiteBronzeTokens.bronzeDark.withValues(
                        alpha: 0.45,
                      ),
                      PremiumWhiteBronzeTokens.bronzeHighlight.withValues(
                        alpha: 0.30,
                      ),
                    ]
                  : <Color>[
                      PremiumWhiteBronzeTokens.bronzeDark.withValues(
                        alpha: 0.12,
                      ),
                      PremiumWhiteBronzeTokens.bronzeHighlight.withValues(
                        alpha: 0.08,
                      ),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: SelectableText(
            message.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thinking indicator (pulse animation)
// ---------------------------------------------------------------------------

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({required this.notifier});

  final ValueNotifier<bool> notifier;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    widget.notifier.addListener(_syncAnimation);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _ThinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_syncAnimation);
      widget.notifier.addListener(_syncAnimation);
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.notifier.value) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_syncAnimation);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.notifier,
      builder: (BuildContext context, bool busy, Widget? child) {
        if (!busy) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 40,
              top: UiChromeConfig.space4,
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PremiumWhiteBronzeTokens.bronzeHighlight,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PremiumWhiteBronzeTokens.bronzeHighlight
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PremiumWhiteBronzeTokens.bronzeHighlight
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking...',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: UiSurfaceStyles.mutedOnSurface(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Chat input bar (panel-styled, Cmd+Enter to send)
// ---------------------------------------------------------------------------

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.inputController,
    required this.focusNode,
    required this.actionNotifier,
    required this.hintText,
    required this.onSend,
  });

  final TextEditingController inputController;
  final FocusNode focusNode;
  final ValueNotifier<bool> actionNotifier;
  final String hintText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    const double sendButtonDiameter = 34;
    const double textFieldCornerRadius = sendButtonDiameter / 2;
    final Color textFieldFillColor = dark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.96)
        : (theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface);
    final Color barColor = dark
        ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92)
        : theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        UiChromeConfig.space14,
        UiChromeConfig.space10,
        UiChromeConfig.space10,
        UiChromeConfig.space10,
      ),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(UiChromeConfig.cardRadius),
          bottomRight: Radius.circular(UiChromeConfig.cardRadius),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (event is! KeyDownEvent ||
                    event.logicalKey != LogicalKeyboardKey.enter) {
                  return KeyEventResult.ignored;
                }
                if (HardwareKeyboard.instance.isShiftPressed) {
                  return KeyEventResult.ignored;
                }
                if (!actionNotifier.value) {
                  onSend();
                }
                return KeyEventResult.handled;
              },
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: inputController,
                builder:
                    (BuildContext context, TextEditingValue value, Widget? _) {
                      final bool singleLine = !value.text.contains('\n');
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(
                          textFieldCornerRadius,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: sendButtonDiameter,
                          ),
                          alignment: singleLine
                              ? Alignment.centerLeft
                              : Alignment.topLeft,
                          color: textFieldFillColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiChromeConfig.space12,
                          ),
                          child: TextField(
                            controller: inputController,
                            focusNode: focusNode,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            textAlignVertical: TextAlignVertical.center,
                            keyboardType: TextInputType.multiline,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: hintText,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: UiSurfaceStyles.mutedOnSurface(context),
                              ),
                              filled: false,
                              hoverColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                      );
                    },
              ),
            ),
          ),
          const SizedBox(width: UiChromeConfig.space8),
          ValueListenableBuilder<bool>(
            valueListenable: actionNotifier,
            builder: (BuildContext context, bool busy, Widget? child) {
              return IconButton(
                tooltip: 'Send (Enter), new line (Shift+Enter)',
                onPressed: busy ? null : onSend,
                icon: Container(
                  width: sendButtonDiameter,
                  height: sendButtonDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: busy
                        ? null
                        : PremiumWhiteBronzeTokens.bronzeGradientFor(51),
                    color: busy
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIconsRegular.paperPlaneTilt,
                      size: 16,
                      color: busy
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                          : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
