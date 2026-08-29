// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/settings/project_registry.dart';
import '../controllers/project_workspace_controller.dart';
import '../localization/desktop_strings.dart';
import '../models/project_hub_models.dart';
import '../theme/premium_white_bronze_tokens.dart';
import '../theme/ui_chrome_config.dart';
import '../theme/ui_surface_styles.dart';
import 'common/bronze_button.dart';
import 'project_hub_components.dart';
import 'shell/workspaces/chat_workspace_view.dart';

class ProjectHubContentPanel extends StatelessWidget {
  const ProjectHubContentPanel({
    super.key,
    required this.strings,
    required this.activeSection,
    required this.chatController,
    required this.projects,
    required this.lastOpenedProjectId,
    required this.searchQuery,
    required this.isLoading,
    required this.onOpenProject,
    required this.onDeleteProject,
    required this.onNewProject,
    required this.onOpenExistingProject,
    required this.onCloneRepository,
    required this.onSearchQueryChanged,
  });

  final DesktopStrings strings;
  final ProjectHubSection activeSection;
  final ProjectWorkspaceController chatController;
  final List<RegisteredProject> projects;
  final String? lastOpenedProjectId;
  final String searchQuery;
  final bool isLoading;
  final ValueChanged<RegisteredProject> onOpenProject;
  final ValueChanged<RegisteredProject> onDeleteProject;
  final VoidCallback onNewProject;
  final VoidCallback onOpenExistingProject;
  final VoidCallback onCloneRepository;
  final ValueChanged<String> onSearchQueryChanged;

  @override
  Widget build(BuildContext context) {
    return switch (activeSection) {
      ProjectHubSection.projects => _ProjectsView(
        strings: strings,
        projects: projects,
        lastOpenedProjectId: lastOpenedProjectId,
        searchQuery: searchQuery,
        isLoading: isLoading,
        onOpenProject: onOpenProject,
        onDeleteProject: onDeleteProject,
        onNewProject: onNewProject,
        onOpenExistingProject: onOpenExistingProject,
        onCloneRepository: onCloneRepository,
        onSearchQueryChanged: onSearchQueryChanged,
      ),
      ProjectHubSection.chat => ChatWorkspaceView(
        controller: chatController,
        presentation: ChatWorkspacePresentation(
          titleOverride: strings.hubChatTitle,
          includeProjectRootMessage: false,
        ),
      ),
      ProjectHubSection.settings => _PlaceholderView(
        message: strings.hubSettingsPlaceholder,
      ),
      ProjectHubSection.learn => _PlaceholderView(
        message: strings.hubLearnPlaceholder,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Projects view
// ---------------------------------------------------------------------------

class _ProjectsView extends StatelessWidget {
  const _ProjectsView({
    required this.strings,
    required this.projects,
    required this.lastOpenedProjectId,
    required this.searchQuery,
    required this.isLoading,
    required this.onOpenProject,
    required this.onDeleteProject,
    required this.onNewProject,
    required this.onOpenExistingProject,
    required this.onCloneRepository,
    required this.onSearchQueryChanged,
  });

  final DesktopStrings strings;
  final List<RegisteredProject> projects;
  final String? lastOpenedProjectId;
  final String searchQuery;
  final bool isLoading;
  final ValueChanged<RegisteredProject> onOpenProject;
  final ValueChanged<RegisteredProject> onDeleteProject;
  final VoidCallback onNewProject;
  final VoidCallback onOpenExistingProject;
  final VoidCallback onCloneRepository;
  final ValueChanged<String> onSearchQueryChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final ButtonStyle secondaryActionStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, UiChromeConfig.sidebarItemHeight),
      padding: const EdgeInsets.symmetric(horizontal: UiChromeConfig.space14),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: UiChromeConfig.sidebarItemHeight,
                child: _ProjectsSearchField(
                  placeholder: strings.hubSearchPlaceholder,
                  value: searchQuery,
                  onChanged: onSearchQueryChanged,
                ),
              ),
            ),
            const SizedBox(width: UiChromeConfig.space10),
            IntrinsicWidth(
              child: SizedBox(
                height: UiChromeConfig.sidebarItemHeight,
                child: BronzeButton(
                  onPressed: isLoading ? null : onNewProject,
                  icon: PhosphorIconsRegular.plus,
                  label: strings.hubNewActionShort,
                  height: UiChromeConfig.sidebarItemHeight,
                  seed: 70,
                ),
              ),
            ),
            const SizedBox(width: UiChromeConfig.space10),
            SizedBox(
              height: UiChromeConfig.sidebarItemHeight,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onOpenExistingProject,
                style: secondaryActionStyle,
                icon: const Icon(PhosphorIconsRegular.folderOpen, size: 16),
                label: Text(strings.hubOpenActionShort),
              ),
            ),
            const SizedBox(width: UiChromeConfig.space10),
            SizedBox(
              height: UiChromeConfig.sidebarItemHeight,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onCloneRepository,
                style: secondaryActionStyle,
                icon: const Icon(PhosphorIconsRegular.gitBranch, size: 16),
                label: Text(strings.hubCloneRepositoryAction),
              ),
            ),
          ],
        ),
        const SizedBox(height: UiChromeConfig.space20),
        // Section title.
        Text(
          strings.recentProjectsTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: dark
                ? theme.colorScheme.onSurface
                : PremiumWhiteBronzeTokens.onSurface,
          ),
        ),
        const SizedBox(height: UiChromeConfig.space12),
        // Project list.
        Expanded(
          child: projects.isEmpty
              ? Center(
                  child: Text(
                    strings.noProjectsLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: UiSurfaceStyles.mutedOnSurface(context),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < projects.length;
                        index++
                      ) ...<Widget>[
                        ProjectHubCard(
                          key: ValueKey<String>(projects[index].id),
                          strings: strings,
                          project: projects[index],
                          isLastOpened:
                              lastOpenedProjectId == projects[index].id,
                          onOpenProject: () => onOpenProject(projects[index]),
                          onDeleteProject: () =>
                              onDeleteProject(projects[index]),
                        ),
                        if (index != projects.length - 1)
                          const SizedBox(height: UiChromeConfig.space4),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProjectsSearchField extends StatefulWidget {
  const _ProjectsSearchField({
    required this.placeholder,
    required this.value,
    required this.onChanged,
  });

  final String placeholder;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ProjectsSearchField> createState() => _ProjectsSearchFieldState();
}

class _ProjectsSearchFieldState extends State<_ProjectsSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _ProjectsSearchField oldWidget) {
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          borderSide: BorderSide(
            color: PremiumWhiteBronzeTokens.bronzeMid.withValues(alpha: 0.60),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder view for Settings / Learn
// ---------------------------------------------------------------------------

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: UiSurfaceStyles.mutedOnSurface(context),
        ),
      ),
    );
  }
}
