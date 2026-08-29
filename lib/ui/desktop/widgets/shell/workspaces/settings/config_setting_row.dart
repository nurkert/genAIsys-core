// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../../../core/app/app.dart';
import '../../../../localization/desktop_strings.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';

/// One setting: name and explanation on the left, its control on the right.
///
/// The control is chosen from the field's declared type, so a newly registered
/// config key renders correctly without anyone writing a widget for it.
class ConfigSettingRow extends StatelessWidget {
  const ConfigSettingRow({
    super.key,
    required this.strings,
    required this.field,
    required this.onChanged,
    required this.onReset,
    this.pending = false,
    this.errorText,
  });

  final DesktopStrings strings;
  final ConfigFieldDto field;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onReset;
  final bool pending;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = UiSurfaceStyles.mutedOnSurface(
      context,
      lightAlpha: 0.62,
      darkAlpha: 0.66,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.space16,
        vertical: UiChromeConfig.space12,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Narrow rows put the control on its own line: a fixed-width control
          // beside the label would otherwise squeeze the text to nothing and
          // eventually overflow.
          final stacked =
              constraints.maxWidth < UiChromeConfig.settingsRowStackBreakpoint;

          final label = _Label(
            strings: strings,
            field: field,
            muted: muted,
            theme: theme,
          );
          final control = _ControlSlot(
            strings: strings,
            field: field,
            pending: pending,
            onChanged: onChanged,
          );
          final reset = SizedBox(
            width: UiChromeConfig.settingsResetSlotWidth,
            child: field.isModified
                ? IconButton(
                    onPressed: pending ? null : onReset,
                    iconSize: 15,
                    visualDensity: VisualDensity.compact,
                    tooltip: strings.settingsRestoreDefaultTooltip(
                      _format(field.defaultValue, strings),
                    ),
                    icon: Icon(
                      PhosphorIconsRegular.arrowCounterClockwise,
                      color: muted,
                    ),
                  )
                : null,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (stacked) ...<Widget>[
                label,
                const SizedBox(height: UiChromeConfig.space8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[control, reset],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: label),
                    const SizedBox(width: UiChromeConfig.space16),
                    control,
                    // Reserve the reset slot even when unmodified so controls
                    // stay on a single vertical line down the whole list.
                    reset,
                  ],
                ),
              if (errorText != null) ...<Widget>[
                const SizedBox(height: UiChromeConfig.space6),
                Text(
                  errorText!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _format(Object? value, DesktopStrings strings) {
    if (value == null) {
      return strings.settingsNotSetLabel;
    }
    return '$value';
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.strings,
    required this.field,
    required this.muted,
    required this.theme,
  });

  final DesktopStrings strings;
  final ConfigFieldDto field;
  final Color muted;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                field.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (field.isModified) ...<Widget>[
              const SizedBox(width: UiChromeConfig.space8),
              _ModifiedDot(
                tooltip: strings.settingsModifiedTooltip,
                color: theme.colorScheme.secondary,
              ),
            ],
            if (field.deprecated) ...<Widget>[
              const SizedBox(width: UiChromeConfig.space8),
              _Pill(
                label: strings.settingsDeprecatedLabel,
                color: theme.colorScheme.error,
              ),
            ],
          ],
        ),
        const SizedBox(height: UiChromeConfig.space4),
        Text(
          field.description ?? field.qualifiedKey,
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _ControlSlot extends StatelessWidget {
  const _ControlSlot({
    required this.strings,
    required this.field,
    required this.pending,
    required this.onChanged,
  });

  final DesktopStrings strings;
  final ConfigFieldDto field;
  final bool pending;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (field.control) {
      case ConfigFieldControl.toggle:
        return Switch(
          value: field.value as bool? ?? false,
          onChanged: pending ? null : (v) => onChanged(v),
        );
      case ConfigFieldControl.choice:
        return _ChoiceControl(
          field: field,
          pending: pending,
          onChanged: onChanged,
        );
      case ConfigFieldControl.number:
      case ConfigFieldControl.duration:
      case ConfigFieldControl.text:
        return _TextualControl(
          strings: strings,
          field: field,
          pending: pending,
          onChanged: onChanged,
        );
    }
  }
}

class _ChoiceControl extends StatelessWidget {
  const _ChoiceControl({
    required this.field,
    required this.pending,
    required this.onChanged,
  });

  final ConfigFieldDto field;
  final bool pending;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = field.choices ?? const <String>[];
    final current = field.value as String?;
    return SizedBox(
      width: UiChromeConfig.settingsControlWidth,
      child: DropdownButtonFormField<String>(
        // DropdownButtonFormField is a FormField: it keeps its own selection
        // state and would not follow a value that changed underneath it (a
        // restore-to-default, or a rejected write rolled back). Keying it on
        // the current value forces a fresh field when the value moves.
        key: ValueKey<String>('${field.qualifiedKey}:$current'),
        initialValue: choices.contains(current) ? current : null,
        isDense: true,
        // Without isExpanded a long choice overflows the fixed-width control.
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        items: <DropdownMenuItem<String>>[
          for (final choice in choices)
            DropdownMenuItem<String>(
              value: choice,
              child: Text(choice, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: pending ? null : (v) => onChanged(v),
      ),
    );
  }
}

/// Numbers, durations, and free text.
///
/// Committed on submit or focus loss rather than on every keystroke: each write
/// hits disk and is validated, so per-character writes would fight the user
/// mid-edit.
class _TextualControl extends StatefulWidget {
  const _TextualControl({
    required this.strings,
    required this.field,
    required this.pending,
    required this.onChanged,
  });

  final DesktopStrings strings;
  final ConfigFieldDto field;
  final bool pending;
  final ValueChanged<Object?> onChanged;

  @override
  State<_TextualControl> createState() => _TextualControlState();
}

class _TextualControlState extends State<_TextualControl> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _display(widget.field.value));
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_TextualControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt a value that changed underneath us (reset, or a rejected write
    // rolled back), but never yank the text out from under an active edit.
    if (!_focusNode.hasFocus && widget.field.value != oldWidget.field.value) {
      _controller.text = _display(widget.field.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  static String _display(Object? value) => value == null ? '' : '$value';

  void _commit() {
    final raw = _controller.text.trim();
    final parsed = _parse(raw);
    if (parsed == widget.field.value) {
      return;
    }
    widget.onChanged(parsed);
  }

  Object? _parse(String raw) {
    if (raw.isEmpty) {
      return widget.field.nullable ? null : widget.field.value;
    }
    switch (widget.field.control) {
      case ConfigFieldControl.number:
      case ConfigFieldControl.duration:
        final asInt = int.tryParse(raw);
        if (asInt != null) {
          return asInt;
        }
        final asDouble = double.tryParse(raw);
        return asDouble ?? widget.field.value;
      case ConfigFieldControl.text:
      case ConfigFieldControl.toggle:
      case ConfigFieldControl.choice:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final numeric =
        widget.field.control == ConfigFieldControl.number ||
        widget.field.control == ConfigFieldControl.duration;

    return SizedBox(
      width: numeric
          ? UiChromeConfig.settingsNumericControlWidth
          : UiChromeConfig.settingsControlWidth,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: !widget.pending,
        textAlign: numeric ? TextAlign.right : TextAlign.start,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters: numeric
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ]
            : null,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          suffixText: widget.field.durationUnit == null
              ? null
              : _unitSuffix(widget.field.durationUnit!),
          hintText: widget.field.nullable
              ? widget.strings.settingsNotSetLabel
              : null,
        ),
        onSubmitted: (_) => _commit(),
      ),
    );
  }

  static String _unitSuffix(String unit) {
    switch (unit) {
      case 'seconds':
        return 's';
      case 'minutes':
        return 'min';
      case 'hours':
        return 'h';
      default:
        return unit;
    }
  }
}

class _ModifiedDot extends StatelessWidget {
  const _ModifiedDot({required this.tooltip, required this.color});

  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}
