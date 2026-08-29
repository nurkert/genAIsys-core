// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../localization/desktop_strings.dart';
import '../../theme/ui_chrome_config.dart';
import '../common/bronze_button.dart';

/// Dialog for creating a new project with a name and directory path.
///
/// Returns a `(String name, String path)` record on confirmation,
/// or `null` if the user cancels.
class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key, required this.strings});

  final DesktopStrings strings;

  /// Shows the dialog and returns the project parameters, or null if cancelled.
  static Future<({String name, String path})?> show(
    BuildContext context,
    DesktopStrings strings,
  ) {
    return showDialog<({String name, String path})>(
      context: context,
      builder: (BuildContext context) => NewProjectDialog(strings: strings),
    );
  }

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DesktopStrings strings = widget.strings;

    return AlertDialog(
      title: Text(strings.createProjectAction),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: strings.projectNameInputLabel,
                hintText: strings.projectNameInputHint,
              ),
            ),
            const SizedBox(height: UiChromeConfig.space12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: InputDecoration(
                      labelText: strings.projectPathInputLabel,
                      hintText: strings.projectPathInputHint,
                    ),
                  ),
                ),
                const SizedBox(width: UiChromeConfig.space8),
                IconButton(
                  tooltip: 'Browse',
                  onPressed: _pickDirectory,
                  icon: const Icon(PhosphorIconsRegular.folderOpen, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelAction),
        ),
        IntrinsicWidth(
          child: BronzeButton(
            onPressed: _confirm,
            label: strings.create,
            seed: 75,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDirectory() async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath == null || !mounted) {
      return;
    }
    _pathController.text = directoryPath;
    // Auto-fill name from directory basename if name is still empty.
    if (_nameController.text.trim().isEmpty) {
      final String baseName = directoryPath.split('/').last.split('\\').last;
      _nameController.text = baseName;
    }
  }

  void _confirm() {
    final String path = _pathController.text.trim();
    if (path.isEmpty) {
      return;
    }
    final String name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : path.split('/').last.split('\\').last;
    Navigator.of(context).pop((name: name, path: path));
  }
}
