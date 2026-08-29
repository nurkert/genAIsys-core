// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../theme/ui_chrome_config.dart';

class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: UiChromeConfig.space6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _expanded
                      ? PhosphorIconsRegular.caretDown
                      : PhosphorIconsRegular.caretRight,
                  size: 14,
                ),
                const SizedBox(width: UiChromeConfig.space6),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: UiChromeConfig.space6),
            child: Wrap(
              spacing: UiChromeConfig.space8,
              runSpacing: UiChromeConfig.space8,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}
