// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../../../core/app/app.dart';
import '../../../../controllers/config_settings_controller.dart';
import '../../../../localization/desktop_strings.dart';
import '../../../../theme/ui_chrome_config.dart';
import '../../../../theme/ui_surface_styles.dart';
import 'config_setting_row.dart';

/// Every project setting, in one place.
///
/// Built entirely from the config schema, so the surface stays complete as
/// config keys are added. Two things keep 100+ settings approachable: a group
/// rail that shows one area at a time, and a search that spans every group so
/// a setting can be found without knowing which area it lives in.
class ConfigSettingsView extends StatefulWidget {
  const ConfigSettingsView({
    super.key,
    required this.controller,
    required this.strings,
  });

  final ConfigSettingsController controller;
  final DesktopStrings strings;

  @override
  State<ConfigSettingsView> createState() => _ConfigSettingsViewState();
}

class _ConfigSettingsViewState extends State<ConfigSettingsView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.controller.query);
    widget.controller.addListener(_onControllerChanged);
    if (widget.controller.schema == null && !widget.controller.isLoading) {
      widget.controller.load();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Selecting a group clears the query; keep the field in step with it.
    if (_searchController.text != widget.controller.query) {
      _searchController.text = widget.controller.query;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final controller = widget.controller;

        if (controller.isLoading && controller.schema == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final loadError = controller.loadError;
        if (loadError != null && controller.schema == null) {
          return _ErrorState(
            // A project without a config file is not an error the user needs
            // the raw message for; it is the same state the legacy settings
            // form reports, so it reads the same way.
            message: controller.isConfigMissing
                ? widget.strings.projectSettingsUnavailableLabel
                : loadError,
            retryLabel: widget.strings.settingsRetryLabel,
            onRetry: controller.load,
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // A fixed-width rail plus a fixed-width control does not fit in a
            // narrow pane; below the breakpoint the rail becomes a dropdown so
            // the setting rows keep their room.
            final narrow =
                constraints.maxWidth < UiChromeConfig.settingsRailBreakpoint;
            final showRail = !controller.isSearching && !narrow;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SettingsToolbar(
                  controller: controller,
                  strings: widget.strings,
                  searchController: _searchController,
                  showGroupPicker: narrow && !controller.isSearching,
                  narrow: narrow,
                ),
                const SizedBox(height: UiChromeConfig.space12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showRail) _GroupRail(controller: controller),
                      if (showRail)
                        const SizedBox(width: UiChromeConfig.space16),
                      Expanded(
                        child: _SectionList(
                          controller: controller,
                          strings: widget.strings,
                          // Without the rail the user cannot see which area
                          // they are in, so each card names its group.
                          alwaysShowGroup: narrow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SettingsToolbar extends StatelessWidget {
  const _SettingsToolbar({
    required this.controller,
    required this.strings,
    required this.searchController,
    required this.showGroupPicker,
    required this.narrow,
  });

  final ConfigSettingsController controller;
  final DesktopStrings strings;
  final TextEditingController searchController;
  final bool showGroupPicker;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = UiSurfaceStyles.mutedOnSurface(
      context,
      lightAlpha: 0.62,
      darkAlpha: 0.66,
    );
    final visibleModified = controller.visibleSections
        .expand((s) => s.fields)
        .where((f) => f.isModified)
        .length;

    final groupPicker = SizedBox(
      width: UiChromeConfig.settingsGroupRailWidth,
      child: DropdownButtonFormField<String>(
        key: ValueKey<String?>(controller.selectedGroup),
        initialValue: controller.selectedGroup,
        isDense: true,
        // Without isExpanded a long group name overflows the fixed-width
        // button instead of being ellipsized.
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        items: <DropdownMenuItem<String>>[
          for (final group in controller.groups)
            DropdownMenuItem<String>(
              value: group,
              child: Text(group, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (String? group) {
          if (group != null) {
            controller.selectGroup(group);
          }
        },
      ),
    );

    final search = TextField(
      controller: searchController,
      onChanged: controller.setQuery,
      decoration: InputDecoration(
        isDense: true,
        hintText: strings.settingsSearchHint,
        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 16),
        suffixIcon: controller.isSearching
            ? IconButton(
                iconSize: 15,
                tooltip: strings.settingsClearSearchTooltip,
                icon: const Icon(PhosphorIconsRegular.x),
                onPressed: () {
                  searchController.clear();
                  controller.setQuery('');
                },
              )
            : null,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );

    final counter = Text(
      controller.isSearching
          ? strings.settingsSearchResultLabel(
              controller.searchResultCount,
              controller.schema?.fieldCount ?? 0,
            )
          : strings.settingsChangedCountLabel(
              controller.modifiedCount,
              controller.schema?.fieldCount ?? 0,
            ),
      style: theme.textTheme.labelSmall?.copyWith(color: muted),
    );

    final restore = visibleModified == 0
        ? null
        : TextButton.icon(
            onPressed: controller.resetVisible,
            icon: const Icon(
              PhosphorIconsRegular.arrowCounterClockwise,
              size: 14,
            ),
            label: Text(strings.settingsRestoreVisibleLabel(visibleModified)),
          );

    // Narrow: the picker, the search field, the counter and the restore button
    // do not fit on one line, so the status line moves below the inputs.
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showGroupPicker) ...<Widget>[
                groupPicker,
                const SizedBox(width: UiChromeConfig.space12),
              ],
              Expanded(child: search),
            ],
          ),
          const SizedBox(height: UiChromeConfig.space8),
          Row(children: <Widget>[counter, const Spacer(), ?restore]),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: search),
        const SizedBox(width: UiChromeConfig.space16),
        counter,
        if (restore != null) ...<Widget>[
          const SizedBox(width: UiChromeConfig.space12),
          restore,
        ],
      ],
    );
  }
}

class _GroupRail extends StatelessWidget {
  const _GroupRail({required this.controller});

  final ConfigSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schema = controller.schema;

    return SizedBox(
      width: 176,
      child: ListView(
        children: <Widget>[
          for (final group in controller.groups)
            _GroupButton(
              label: group,
              selected: group == controller.selectedGroup,
              modifiedCount: schema == null
                  ? 0
                  : schema.sections
                        .where((s) => s.group == group)
                        .fold(0, (sum, s) => sum + s.modifiedCount),
              onPressed: () => controller.selectGroup(group),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.label,
    required this.selected,
    required this.modifiedCount,
    required this.onPressed,
    required this.theme,
  });

  final String label;
  final bool selected;
  final int modifiedCount;
  final VoidCallback onPressed;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final selectedColor = theme.colorScheme.onSurface.withValues(alpha: 0.07);

    return Padding(
      padding: const EdgeInsets.only(bottom: UiChromeConfig.space4),
      child: Material(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(UiChromeConfig.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UiChromeConfig.space12,
              vertical: UiChromeConfig.space10,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (modifiedCount > 0)
                  Text(
                    '$modifiedCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.controller,
    required this.strings,
    this.alwaysShowGroup = false,
  });

  final ConfigSettingsController controller;
  final DesktopStrings strings;
  final bool alwaysShowGroup;

  @override
  Widget build(BuildContext context) {
    final sections = controller.visibleSections;

    if (sections.isEmpty) {
      return _EmptyState(
        message: controller.isSearching
            ? strings.settingsNoMatchLabel(controller.query)
            : strings.settingsNoAreaSettingsLabel,
      );
    }

    return ListView.builder(
      itemCount: sections.length,
      itemBuilder: (BuildContext context, int index) {
        return _SectionCard(
          section: sections[index],
          controller: controller,
          strings: strings,
          // While searching, results span groups, so each card needs to say
          // where its settings actually live.
          showGroup: controller.isSearching || alwaysShowGroup,
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.controller,
    required this.strings,
    required this.showGroup,
  });

  final ConfigSectionDto section;
  final ConfigSettingsController controller;
  final DesktopStrings strings;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.only(bottom: UiChromeConfig.space16),
      child: Container(
        // Same panel treatment as every other workspace card, so the settings
        // surface reads as part of the shell rather than a bolted-on form.
        decoration: UiSurfaceStyles.panel(context, elevated: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiChromeConfig.space16,
                UiChromeConfig.space14,
                UiChromeConfig.space16,
                UiChromeConfig.space8,
              ),
              child: Text(
                showGroup
                    ? '${section.group} · ${section.label}'
                    : section.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (var i = 0; i < section.fields.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, color: divider),
              ConfigSettingRow(
                strings: strings,
                field: section.fields[i],
                pending: controller.isPending(section.fields[i].qualifiedKey),
                errorText: controller.errorFor(section.fields[i].qualifiedKey),
                onChanged: (Object? value) =>
                    controller.setValue(section.fields[i].qualifiedKey, value),
                onReset: () =>
                    controller.resetField(section.fields[i].qualifiedKey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
