// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/settings/application_settings.dart';
import '../../../../core/settings/application_settings_repository.dart';
import '../../../../core/settings/project_registry_repository.dart';
import '../../localization/desktop_strings.dart';
import '../../models/settings_models.dart';
import '../../theme/ui_chrome_config.dart';
import '../../theme/ui_motion_config.dart';
import '../common/bronze_button.dart';
import '../common/bronze_gradient_text.dart';
import '../common/bronze_switch.dart';
import '../common/settings_card.dart';

class SettingsContentPanel extends StatefulWidget {
  const SettingsContentPanel({
    super.key,
    required this.topCornerRadius,
    required this.leftSidebarVisible,
    required this.rightSidebarVisible,
    required this.strings,
    required this.selectedSection,
    required this.settingsRepository,
    this.onSettingsSaved,
  });

  final double topCornerRadius;
  final bool leftSidebarVisible;
  final bool rightSidebarVisible;
  final DesktopStrings strings;
  final DesktopSettingsSection selectedSection;
  final ApplicationSettingsRepository settingsRepository;
  final ValueChanged<ApplicationSettings>? onSettingsSaved;

  @override
  State<SettingsContentPanel> createState() => _SettingsContentPanelState();
}

class _SettingsContentPanelState extends State<SettingsContentPanel> {
  late final TextEditingController _languageController =
      TextEditingController();
  ApplicationSettings _draft = ApplicationSettings.defaults;
  bool _loading = true;
  bool _saving = false;
  late final String _projectRegistryPath = _resolveProjectRegistryPath();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
    });

    var loaded = ApplicationSettings.defaults;
    try {
      loaded = await widget.settingsRepository.read();
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to load application settings: $error');
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _draft = loaded;
      _languageController.text = loaded.languageCode;
    });
  }

  Future<void> _saveSettings() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });

    final ApplicationSettings next = _draft.copyWith(
      languageCode: _normalizeLanguageCode(_languageController.text),
    );

    try {
      await widget.settingsRepository.write(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = next;
        _languageController.text = next.languageCode;
      });
      widget.onSettingsSaved?.call(next);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to save application settings: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _resetSettings() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
      _draft = ApplicationSettings.defaults;
      _languageController.text = ApplicationSettings.defaults.languageCode;
    });

    try {
      await widget.settingsRepository.reset();
      widget.onSettingsSaved?.call(ApplicationSettings.defaults);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to reset application settings: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _normalizeLanguageCode(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return ApplicationSettings.defaults.languageCode;
    }
    return normalized;
  }

  Widget _buildAppearanceCard() {
    return SettingsCard(
      title: widget.strings.settingsAppearanceTitle,
      children: <Widget>[
        TextField(
          controller: _languageController,
          decoration: InputDecoration(
            labelText: widget.strings.settingsLanguageLabel,
          ),
          onChanged: (String value) {
            _draft = _draft.copyWith(languageCode: value.trim());
          },
        ),
        const SizedBox(height: UiChromeConfig.space12),
        DropdownButtonFormField<ApplicationThemeMode>(
          key: ValueKey<ApplicationThemeMode>(_draft.themeMode),
          initialValue: _draft.themeMode,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.strings.settingsThemeModeLabel,
          ),
          items: <DropdownMenuItem<ApplicationThemeMode>>[
            DropdownMenuItem<ApplicationThemeMode>(
              value: ApplicationThemeMode.system,
              child: Text(widget.strings.settingsThemeModeSystem),
            ),
            DropdownMenuItem<ApplicationThemeMode>(
              value: ApplicationThemeMode.light,
              child: Text(widget.strings.settingsThemeModeLight),
            ),
            DropdownMenuItem<ApplicationThemeMode>(
              value: ApplicationThemeMode.dark,
              child: Text(widget.strings.settingsThemeModeDark),
            ),
          ],
          onChanged: (ApplicationThemeMode? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _draft = _draft.copyWith(themeMode: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsCard() {
    return SettingsCard(
      title: widget.strings.settingsNavNotifications,
      children: <Widget>[
        BronzeSwitchTile(
          title: Text(widget.strings.settingsNotificationsLabel),
          value: _draft.desktopNotificationsEnabled,
          onChanged: (bool value) {
            setState(() {
              _draft = _draft.copyWith(desktopNotificationsEnabled: value);
            });
          },
          seed: widget.strings.settingsNotificationsLabel.hashCode,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildAutomationCard() {
    return SettingsCard(
      title: widget.strings.settingsAutomationTitle,
      children: <Widget>[
        BronzeSwitchTile(
          title: Text(widget.strings.settingsAutopilotLabel),
          value: _draft.autopilotByDefaultEnabled,
          onChanged: (bool value) {
            setState(() {
              _draft = _draft.copyWith(autopilotByDefaultEnabled: value);
            });
          },
          seed: widget.strings.settingsAutopilotLabel.hashCode,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        BronzeSwitchTile(
          title: Text(widget.strings.settingsTelemetryLabel),
          value: _draft.localTelemetryEnabled,
          onChanged: (bool value) {
            setState(() {
              _draft = _draft.copyWith(localTelemetryEnabled: value);
            });
          },
          seed: widget.strings.settingsTelemetryLabel.hashCode,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return SettingsCard(
      title: widget.strings.settingsSecurityTitle,
      children: <Widget>[
        BronzeSwitchTile(
          title: Text(widget.strings.settingsSecretPolicyLabel),
          value: _draft.strictSecretRedactionEnabled,
          onChanged: (bool value) {
            setState(() {
              _draft = _draft.copyWith(strictSecretRedactionEnabled: value);
            });
          },
          seed: widget.strings.settingsSecretPolicyLabel.hashCode,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildStorageCard() {
    return SettingsCard(
      title: widget.strings.settingsNavStorage,
      children: <Widget>[
        _PathInfoRow(
          label: widget.strings.settingsStorageApplicationPathLabel,
          value: widget.settingsRepository.storagePath,
        ),
        const SizedBox(height: UiChromeConfig.space10),
        _PathInfoRow(
          label: widget.strings.settingsStorageProjectRegistryPathLabel,
          value: _projectRegistryPath,
        ),
      ],
    );
  }

  Widget _buildSettingsSections() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Widget> cards = _cardsForSection(widget.selectedSection);
        final bool compact = constraints.maxWidth < 1100;
        if (compact) {
          return SingleChildScrollView(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < cards.length; i++) ...<Widget>[
                  cards[i],
                  if (i != cards.length - 1)
                    const SizedBox(height: UiChromeConfig.space14),
                ],
              ],
            ),
          );
        }

        return Row(
          children: <Widget>[
            for (int i = 0; i < cards.length; i++) ...<Widget>[
              Expanded(child: cards[i]),
              if (i != cards.length - 1)
                const SizedBox(width: UiChromeConfig.space14),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _cardsForSection(DesktopSettingsSection section) {
    switch (section) {
      case DesktopSettingsSection.general:
        return <Widget>[_buildAppearanceCard()];
      case DesktopSettingsSection.notifications:
        return <Widget>[_buildNotificationsCard()];
      case DesktopSettingsSection.automation:
        return <Widget>[_buildAutomationCard()];
      case DesktopSettingsSection.security:
        return <Widget>[_buildSecurityCard()];
      case DesktopSettingsSection.storage:
        return <Widget>[_buildStorageCard()];
    }
  }

  String _resolveProjectRegistryPath() {
    try {
      return const ProjectRegistryPathResolver().resolveStoragePath();
    } on Object {
      return widget.strings.settingsStoragePathUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: UiMotionConfig.shellDuration,
      curve: UiMotionConfig.shellCurve,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            widget.leftSidebarVisible ? widget.topCornerRadius : 0,
          ),
          topRight: Radius.circular(
            widget.rightSidebarVisible ? widget.topCornerRadius : 0,
          ),
        ),
      ),
      child: Padding(
        padding: UiChromeConfig.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BronzeGradientText(
              widget.strings.settingsTitle,
              seed: 21,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: UiChromeConfig.space6),
            Text(
              widget.strings.settingsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.76),
              ),
            ),
            const SizedBox(height: UiChromeConfig.space6),
            Text(
              _sectionSubtitle(widget.selectedSection),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: UiChromeConfig.space20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : _buildSettingsSections(),
            ),
            const SizedBox(height: UiChromeConfig.space16),
            Row(
              children: <Widget>[
                const Spacer(),
                OutlinedButton(
                  onPressed: _saving ? null : _resetSettings,
                  child: Text(widget.strings.settingsResetAction),
                ),
                const SizedBox(width: UiChromeConfig.space10),
                BronzeButton(
                  onPressed: _saving ? null : _saveSettings,
                  label: widget.strings.settingsSaveAction,
                  glow: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sectionSubtitle(DesktopSettingsSection section) {
    switch (section) {
      case DesktopSettingsSection.general:
        return widget.strings.settingsGeneralSectionSubtitle;
      case DesktopSettingsSection.notifications:
        return widget.strings.settingsNotificationsSectionSubtitle;
      case DesktopSettingsSection.automation:
        return widget.strings.settingsAutomationSectionSubtitle;
      case DesktopSettingsSection.security:
        return widget.strings.settingsSecuritySectionSubtitle;
      case DesktopSettingsSection.storage:
        return widget.strings.settingsStorageSectionSubtitle;
    }
  }
}

class _PathInfoRow extends StatelessWidget {
  const _PathInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: UiChromeConfig.space4),
        SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
