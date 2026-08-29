// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/settings/project_registry.dart';
import '../../../core/settings/project_registry_service.dart';
import '../../../desktop/services/window_service_interface.dart';
import '../controllers/project_hub_controller.dart';
import '../controllers/project_workspace_controller.dart';
import '../localization/desktop_localization.dart';
import '../localization/desktop_strings.dart';
import '../theme/platform_corner_profile.dart';
import '../theme/platform_window_controls_profile.dart';
import '../theme/ui_chrome_config.dart';
import 'dialogs/clone_repository_dialog.dart';
import 'dialogs/new_project_dialog.dart';
import 'project_hub_content_panel.dart';
import 'project_hub_sidebar.dart';
import 'shell/shell_top_bar.dart';

class ProjectHubWindow extends StatefulWidget {
  const ProjectHubWindow({
    super.key,
    required this.onOpenSettings,
    required this.windowService,
    required this.projectRegistryService,
  });

  final VoidCallback onOpenSettings;
  final WindowServiceInterface windowService;
  final ProjectRegistryService projectRegistryService;

  @override
  State<ProjectHubWindow> createState() => _ProjectHubWindowState();
}

class _ProjectHubWindowState extends State<ProjectHubWindow> {
  late final ProjectHubController _controller = ProjectHubController(
    registryService: widget.projectRegistryService,
  );
  late final ProjectWorkspaceController _chatController =
      ProjectWorkspaceController(projectRootPath: '');
  static const PlatformWindowControlsResolver _windowControlsResolver =
      PlatformWindowControlsResolver();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _chatController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DesktopStrings strings = context.strings;
    final TargetPlatform platform = Theme.of(context).platform;
    final double topInset = UiChromeConfig.topInsetFor(platform);
    final double topBarHeight = UiChromeConfig.topBarHeightFor(platform);
    final PlatformCornerProfile corners = PlatformCornerProfile.resolve();
    final PlatformWindowControlsProfile windowControlsProfile =
        _windowControlsResolver.resolve(platform: platform);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ValueListenableBuilder<bool>(
        valueListenable: widget.windowService.fullscreen,
        builder: (BuildContext context, bool fullscreen, Widget? child) {
          return Column(
            children: <Widget>[
              SizedBox(height: topInset),
              // Top bar: static -- does NOT rebuild when controller data changes.
              ShellTopBar(
                height: topBarHeight,
                fullscreen: fullscreen,
                windowControlsProfile: windowControlsProfile,
                projectDisplayName: strings.projectHubTitle,
                showLeftToggle: false,
                showRightToggle: false,
                leftHidden: false,
                rightVisible: false,
                onToggleLeftVisibility: () {},
                onToggleRightVisibility: () {},
              ),
              const SizedBox(height: UiChromeConfig.panelGap),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: UiChromeConfig.windowInset,
                  ),
                  child: Row(
                    children: <Widget>[
                      // Left sidebar: scoped rebuild for section state.
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: UiChromeConfig.windowInset,
                        ),
                        child: SizedBox(
                          width: UiChromeConfig.leftSidebarExpandedWidth,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (BuildContext context, Widget? _) {
                              return ProjectHubSidebar(
                                cornerRadius: corners.sidebarRadius,
                                strings: strings,
                                selectedSection: _controller.activeSection,
                                onSelectSection: _controller.selectSection,
                                onOpenSettings: widget.onOpenSettings,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: UiChromeConfig.panelGap),
                      // Right content: scoped rebuild for project data.
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(corners.mainTopRadius),
                            ),
                          ),
                          child: Padding(
                            padding: UiChromeConfig.panelPadding,
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (BuildContext context, Widget? _) {
                                return ProjectHubContentPanel(
                                  strings: strings,
                                  activeSection: _controller.activeSection,
                                  chatController: _chatController,
                                  projects: _controller.filteredProjects,
                                  lastOpenedProjectId:
                                      _controller.lastOpenedProjectId,
                                  searchQuery: _controller.searchQuery,
                                  isLoading: _controller.isLoading,
                                  onOpenProject: _openProject,
                                  onDeleteProject: _deleteProjectWithConfirm,
                                  onNewProject: _newProject,
                                  onOpenExistingProject: _openExistingProject,
                                  onCloneRepository: _cloneRepository,
                                  onSearchQueryChanged:
                                      _controller.updateSearchQuery,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _newProject() async {
    final ({String name, String path})? result = await NewProjectDialog.show(
      context,
      context.strings,
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await _controller.registerProject(
        projectName: result.name,
        projectRootPath: result.path,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('${context.strings.projectSaveFailedLabel}: $error');
    }
  }

  Future<void> _openExistingProject() async {
    final String? directoryPath = await getDirectoryPath(
      confirmButtonText: context.strings.openProjectAction,
    );
    if (directoryPath == null || !mounted) {
      return;
    }
    try {
      final String name = directoryPath.split(Platform.pathSeparator).last;
      await _controller.registerProject(
        projectName: name,
        projectRootPath: directoryPath,
        markAsLastOpened: true,
      );
      // Find the just-registered project and open it.
      final RegisteredProject? project = _controller.projects
          .where((RegisteredProject p) => p.rootPath == directoryPath)
          .firstOrNull;
      if (project != null) {
        await _openProjectWindow(project);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('${context.strings.openProjectFailedLabel}: $error');
    }
  }

  Future<void> _cloneRepository() async {
    final DesktopStrings strings = context.strings;
    final ({String url, String targetPath})? result =
        await CloneRepositoryDialog.show(context, strings);
    if (result == null || !mounted) {
      return;
    }
    // For now, register as a project stub. Actual git clone is a future task.
    try {
      final String name = result.url.split('/').last.replaceAll('.git', '');
      final String fullPath =
          '${result.targetPath}${Platform.pathSeparator}$name';
      await _controller.registerProject(
        projectName: name,
        projectRootPath: fullPath,
      );
      _showSnackBar('Registered "$name". Git clone is not yet implemented.');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('${strings.projectSaveFailedLabel}: $error');
    }
  }

  Future<void> _openProject(RegisteredProject project) async {
    try {
      await _controller.markProjectOpened(project.id);
      await _openProjectWindow(project);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('${context.strings.openProjectFailedLabel}: $error');
    }
  }

  Future<void> _openProjectWindow(RegisteredProject project) async {
    await widget.windowService.openProjectWorkspaceWindow(
      projectName: project.name,
      projectRootPath: project.rootPath,
    );
    await widget.windowService.hideWindow();
  }

  Future<void> _deleteProjectWithConfirm(RegisteredProject project) async {
    final DesktopStrings strings = context.strings;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings.deleteProjectAction),
          content: Text(
            '${strings.deleteProjectConfirmationPrefix} ${project.name}?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.deleteProjectAction),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _controller.deleteProject(project.id);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('${strings.projectDeleteFailedLabel}: $error');
    }
  }

  void _showSnackBar(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
