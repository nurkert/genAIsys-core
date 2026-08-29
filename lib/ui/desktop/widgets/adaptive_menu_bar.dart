// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../desktop/services/window_service_interface.dart';
import '../localization/desktop_localization.dart';
import '../localization/desktop_strings.dart';

enum _DesktopMenuAction {
  exit,
  openSettings,
  toggleLeftSidebar,
  toggleRightSidebar,
}

class AdaptiveMenuBar extends StatelessWidget {
  const AdaptiveMenuBar({
    super.key,
    required this.windowService,
    required this.onOpenSettings,
    required this.onToggleLeftSidebar,
    required this.onToggleRightSidebar,
    this.showSettingsAction = true,
    this.showLeftSidebarAction = true,
    this.showRightSidebarAction = true,
    required this.child,
  });

  final WindowServiceInterface windowService;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleLeftSidebar;
  final VoidCallback onToggleRightSidebar;
  final bool showSettingsAction;
  final bool showLeftSidebarAction;
  final bool showRightSidebarAction;
  final Widget child;

  void _dispatch(_DesktopMenuAction action) {
    switch (action) {
      case _DesktopMenuAction.exit:
        windowService.closeWindow();
        return;
      case _DesktopMenuAction.openSettings:
        onOpenSettings();
        return;
      case _DesktopMenuAction.toggleLeftSidebar:
        onToggleLeftSidebar();
        return;
      case _DesktopMenuAction.toggleRightSidebar:
        onToggleRightSidebar();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    const SingleActivator settingsShortcutMac = SingleActivator(
      LogicalKeyboardKey.comma,
      meta: true,
    );
    final List<_DesktopMenuAction> viewActions = <_DesktopMenuAction>[
      if (showLeftSidebarAction) _DesktopMenuAction.toggleLeftSidebar,
      if (showRightSidebarAction) _DesktopMenuAction.toggleRightSidebar,
    ];

    if (Platform.isMacOS) {
      return PlatformMenuBar(
        menus: <PlatformMenuItem>[
          if (showSettingsAction)
            PlatformMenu(
              label: strings.menuApp,
              menus: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: strings.menuSettings,
                  shortcut: settingsShortcutMac,
                  onSelected: () => _dispatch(_DesktopMenuAction.openSettings),
                ),
              ],
            ),
          PlatformMenu(
            label: strings.menuFile,
            menus: <PlatformMenuItem>[
              PlatformMenuItem(
                label: strings.menuExit,
                onSelected: () => _dispatch(_DesktopMenuAction.exit),
              ),
            ],
          ),
          if (viewActions.isNotEmpty)
            PlatformMenu(
              label: strings.menuView,
              menus: viewActions
                  .map(
                    (_DesktopMenuAction action) => PlatformMenuItem(
                      label: _labelForAction(strings, action),
                      onSelected: () => _dispatch(action),
                    ),
                  )
                  .toList(),
            ),
        ],
        child: child,
      );
    }

    return child;
  }
}

class InWindowMenuBar extends StatelessWidget {
  const InWindowMenuBar({
    super.key,
    required this.windowService,
    required this.onOpenSettings,
    required this.onToggleLeftSidebar,
    required this.onToggleRightSidebar,
    this.showSettingsAction = true,
    this.showLeftSidebarAction = true,
    this.showRightSidebarAction = true,
  });

  final WindowServiceInterface windowService;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleLeftSidebar;
  final VoidCallback onToggleRightSidebar;
  final bool showSettingsAction;
  final bool showLeftSidebarAction;
  final bool showRightSidebarAction;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final List<_DesktopMenuAction> viewActions = <_DesktopMenuAction>[
      if (showLeftSidebarAction) _DesktopMenuAction.toggleLeftSidebar,
      if (showRightSidebarAction) _DesktopMenuAction.toggleRightSidebar,
    ];
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.90),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (showSettingsAction)
            _MenuItem(
              label: strings.menuApp,
              entries: <PopupMenuEntry<_DesktopMenuAction>>[
                PopupMenuItem<_DesktopMenuAction>(
                  value: _DesktopMenuAction.openSettings,
                  child: _MenuEntryLabel(
                    label: strings.menuSettings,
                    shortcutHint: strings.menuSettingsShortcutDesktop,
                  ),
                ),
              ],
              onSelected: _dispatch,
            ),
          _MenuItem(
            label: strings.menuFile,
            entries: <PopupMenuEntry<_DesktopMenuAction>>[
              PopupMenuItem<_DesktopMenuAction>(
                value: _DesktopMenuAction.exit,
                child: Text(strings.menuExit),
              ),
            ],
            onSelected: _dispatch,
          ),
          if (viewActions.isNotEmpty)
            _MenuItem(
              label: strings.menuView,
              entries: viewActions
                  .map(
                    (_DesktopMenuAction action) =>
                        PopupMenuItem<_DesktopMenuAction>(
                          value: action,
                          child: Text(_labelForAction(strings, action)),
                        ),
                  )
                  .toList(),
              onSelected: _dispatch,
            ),
          const Spacer(),
          Text(
            strings.brandName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }

  void _dispatch(_DesktopMenuAction action) {
    switch (action) {
      case _DesktopMenuAction.exit:
        windowService.closeWindow();
        return;
      case _DesktopMenuAction.openSettings:
        onOpenSettings();
        return;
      case _DesktopMenuAction.toggleLeftSidebar:
        onToggleLeftSidebar();
        return;
      case _DesktopMenuAction.toggleRightSidebar:
        onToggleRightSidebar();
        return;
    }
  }
}

String _labelForAction(DesktopStrings strings, _DesktopMenuAction action) {
  switch (action) {
    case _DesktopMenuAction.openSettings:
      return strings.menuSettings;
    case _DesktopMenuAction.toggleLeftSidebar:
      return strings.menuToggleLeftSidebar;
    case _DesktopMenuAction.toggleRightSidebar:
      return strings.menuToggleRightSidebar;
    case _DesktopMenuAction.exit:
      return strings.menuExit;
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.entries,
    this.onSelected,
  });

  final String label;
  final List<PopupMenuEntry<_DesktopMenuAction>> entries;
  final ValueChanged<_DesktopMenuAction>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DesktopMenuAction>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => entries,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _MenuEntryLabel extends StatelessWidget {
  const _MenuEntryLabel({required this.label, required this.shortcutHint});

  final String label;
  final String shortcutHint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Text(shortcutHint, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
