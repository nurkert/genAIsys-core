// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../theme/ui_chrome_config.dart';
import '../common/bronze_button.dart';

/// Reusable confirmation dialog with configurable title, message, and actions.
///
/// The dialog follows the Genaisys design system and can be centrally styled
/// for all confirmation popups across the application.
///
/// Returns `true` when the user confirms, `false` or `null` when cancelled.
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData? icon;

  /// Shows the dialog and returns `true` if confirmed, `null` if cancelled.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiChromeConfig.cardRadius),
      ),
      icon: icon != null
          ? Icon(
              icon,
              size: 32,
              color: isDestructive
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            )
          : null,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: dark
                ? theme.colorScheme.onSurface.withValues(alpha: 0.72)
                : theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        UiChromeConfig.space16,
        0,
        UiChromeConfig.space16,
        UiChromeConfig.space16,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        if (isDestructive)
          _DestructiveButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
          )
        else
          IntrinsicWidth(
            child: BronzeButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: confirmLabel,
              seed: title.hashCode,
            ),
          ),
      ],
    );
  }
}

/// A destructive action button styled in the error/red color scheme.
class _DestructiveButton extends StatefulWidget {
  const _DestructiveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_DestructiveButton> createState() => _DestructiveButtonState();
}

class _DestructiveButtonState extends State<_DestructiveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color baseColor = theme.colorScheme.error;
    final Color foreground = theme.colorScheme.onError;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _hovered
                ? baseColor.withValues(alpha: 0.92)
                : baseColor.withValues(alpha: 0.80),
            foregroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: UiChromeConfig.space16,
              vertical: UiChromeConfig.space10,
            ),
          ),
          onPressed: widget.onPressed,
          child: Text(
            widget.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
