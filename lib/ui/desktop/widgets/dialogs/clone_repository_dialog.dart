// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../../localization/desktop_strings.dart';
import '../../theme/ui_chrome_config.dart';
import '../common/bronze_button.dart';

/// Dialog for entering a git repository URL and target directory.
///
/// Returns a `(String url, String targetPath)` record on confirmation,
/// or `null` if the user cancels.
class CloneRepositoryDialog extends StatefulWidget {
  const CloneRepositoryDialog({super.key, required this.strings});

  final DesktopStrings strings;

  /// Shows the dialog and returns the clone parameters, or null if cancelled.
  static Future<({String url, String targetPath})?> show(
    BuildContext context,
    DesktopStrings strings,
  ) {
    return showDialog<({String url, String targetPath})>(
      context: context,
      builder: (BuildContext context) =>
          CloneRepositoryDialog(strings: strings),
    );
  }

  @override
  State<CloneRepositoryDialog> createState() => _CloneRepositoryDialogState();
}

class _CloneRepositoryDialogState extends State<CloneRepositoryDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DesktopStrings strings = widget.strings;

    return AlertDialog(
      title: Text(strings.hubCloneRepositoryAction),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: strings.hubCloneUrlLabel,
                hintText: strings.hubCloneUrlHint,
              ),
            ),
            const SizedBox(height: UiChromeConfig.space12),
            TextField(
              controller: _targetController,
              decoration: InputDecoration(
                labelText: strings.hubCloneTargetLabel,
                hintText: strings.hubCloneTargetHint,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelAction),
        ),
        BronzeButton(
          onPressed: _confirm,
          label: strings.hubCloneAction,
          seed: 80,
        ),
      ],
    );
  }

  void _confirm() {
    final String url = _urlController.text.trim();
    final String target = _targetController.text.trim();
    if (url.isEmpty || target.isEmpty) {
      return;
    }
    Navigator.of(context).pop((url: url, targetPath: target));
  }
}
