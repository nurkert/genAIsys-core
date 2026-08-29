// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_scope.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ResetShell(controller: controller),
    );
  }
}

class _ResetShell extends StatefulWidget {
  const _ResetShell({required this.controller});

  final AppController controller;

  @override
  State<_ResetShell> createState() => _ResetShellState();
}

class _ResetShellState extends State<_ResetShell> {
  late final TextEditingController _projectRootController;

  @override
  void initState() {
    super.initState();
    _projectRootController = TextEditingController();
  }

  @override
  void dispose() {
    _projectRootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;

    if (!state.busy &&
        state.projectRoot != _projectRootController.text &&
        (state.projectRoot?.isNotEmpty ?? false)) {
      _projectRootController.text = state.projectRoot!;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Genaisys UI Reset',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Neustart der UI: alte Oberfläche entfernt, neue Oberfläche folgt.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _projectRootController,
                    decoration: const InputDecoration(
                      labelText: 'Projektverzeichnis',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                widget.controller.selectProject(
                                  _projectRootController.text,
                                );
                              },
                        child: const Text('Projekt laden'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: state.busy
                            ? null
                            : widget.controller.refresh,
                        child: const Text('Status aktualisieren'),
                      ),
                    ],
                  ),
                  if (state.busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 20),
                  if (state.projectRoot != null) ...[
                    Text('Aktuelles Projekt: ${state.projectRoot}'),
                    const SizedBox(height: 8),
                    Text('Projekt vorhanden: ${state.projectExists}'),
                    Text('Genaisys bereit: ${state.genaisysReady}'),
                  ],
                  if (state.projectExists && !state.genaisysReady) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () => widget.controller.initializeProject(),
                      child: const Text('Genaisys init'),
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.6),
                      child: ListTile(
                        title: const Text('Fehler'),
                        subtitle: Text(state.errorMessage!),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.controller.clearError,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
