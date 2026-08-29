// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../theme/ui_chrome_config.dart';

class HealthCheckRow extends StatelessWidget {
  const HealthCheckRow({super.key, required this.label, required this.ok});

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
