// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../theme/premium_white_bronze_tokens.dart';
import '../../theme/ui_chrome_config.dart';

/// Search field for filtering tasks across all columns.
class BacklogSearchField extends StatefulWidget {
  const BacklogSearchField({
    super.key,
    required this.placeholder,
    required this.value,
    required this.onChanged,
  });

  final String placeholder;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<BacklogSearchField> createState() => _BacklogSearchFieldState();
}

class _BacklogSearchFieldState extends State<BacklogSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant BacklogSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value || _controller.text == widget.value) {
      return;
    }
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: dark
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48)
              : PremiumWhiteBronzeTokens.onSurface.withValues(alpha: 0.48),
        ),
        prefixIcon: Icon(
          PhosphorIconsRegular.magnifyingGlass,
          size: 16,
          color: dark
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48)
              : PremiumWhiteBronzeTokens.onSurface.withValues(alpha: 0.48),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: UiChromeConfig.sidebarItemHeight,
        ),
        filled: true,
        fillColor: dark
            ? PremiumWhiteBronzeTokens.darkSurfaceMuted
            : PremiumWhiteBronzeTokens.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          vertical: UiChromeConfig.space8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
