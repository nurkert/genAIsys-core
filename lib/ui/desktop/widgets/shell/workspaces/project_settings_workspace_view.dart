// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/config/project_config.dart';
import '../../../controllers/project_workspace_controller.dart';
import '../../../localization/desktop_localization.dart';
import '../../../localization/desktop_strings.dart';
import '../../../theme/ui_chrome_config.dart';
import '../../common/bronze_button.dart';
import '../../common/bronze_switch.dart';
import '../../common/settings_card.dart';
import 'workspace_header.dart';

class ProjectSettingsWorkspaceView extends StatefulWidget {
  const ProjectSettingsWorkspaceView({super.key, required this.controller});

  final ProjectWorkspaceController controller;

  @override
  State<ProjectSettingsWorkspaceView> createState() =>
      _ProjectSettingsWorkspaceViewState();
}

class _ProjectSettingsWorkspaceViewState
    extends State<ProjectSettingsWorkspaceView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _gitBaseBranchController =
      TextEditingController();
  final TextEditingController _gitFeaturePrefixController =
      TextEditingController();
  final TextEditingController _shellAllowlistController =
      TextEditingController();
  final TextEditingController _safeWriteRootsController =
      TextEditingController();

  final TextEditingController _diffMaxFilesController = TextEditingController();
  final TextEditingController _diffMaxAdditionsController =
      TextEditingController();
  final TextEditingController _diffMaxDeletionsController =
      TextEditingController();

  final TextEditingController _autoMinOpenController = TextEditingController();
  final TextEditingController _autoMaxPlanController = TextEditingController();
  final TextEditingController _autoMaxStepsController = TextEditingController();
  final TextEditingController _autoMaxFailuresController =
      TextEditingController();
  final TextEditingController _autoMaxRetriesController =
      TextEditingController();
  final TextEditingController _autoStepSleepController =
      TextEditingController();
  final TextEditingController _autoIdleSleepController =
      TextEditingController();
  final TextEditingController _autoLockTtlController = TextEditingController();
  final TextEditingController _autoFairnessWindowController =
      TextEditingController();
  final TextEditingController _autoWeightP1Controller = TextEditingController();
  final TextEditingController _autoWeightP2Controller = TextEditingController();
  final TextEditingController _autoWeightP3Controller = TextEditingController();
  final TextEditingController _autoBlockedCooldownController =
      TextEditingController();
  final TextEditingController _autoFailedCooldownController =
      TextEditingController();
  final TextEditingController _autoNoProgressController =
      TextEditingController();
  final TextEditingController _autoStuckCooldownController =
      TextEditingController();
  final TextEditingController _autoScopeMaxFilesController =
      TextEditingController();
  final TextEditingController _autoScopeMaxAdditionsController =
      TextEditingController();
  final TextEditingController _autoScopeMaxDeletionsController =
      TextEditingController();
  final TextEditingController _autoApproveBudgetController =
      TextEditingController();
  final TextEditingController _autoSelfTuneWindowController =
      TextEditingController();
  final TextEditingController _autoSelfTuneMinSamplesController =
      TextEditingController();
  final TextEditingController _autoSelfTuneSuccessController =
      TextEditingController();

  bool _safeWriteEnabled = true;
  bool _gitAutoStash = false;
  bool _autoReactivateBlocked = false;
  bool _autoReactivateFailed = true;
  bool _autoSelfRestart = true;
  bool _autoManualOverride = false;
  bool _autoOvernightUnattendedEnabled = false;
  bool _autoSelfTuneEnabled = true;
  String _selectionMode = 'fair';
  String _shellAllowlistProfile = ProjectConfig.defaultShellAllowlistProfile;
  List<String> _customAllowlistDraft = const <String>[];

  String? _lastDraftSignature;

  @override
  void dispose() {
    _gitBaseBranchController.dispose();
    _gitFeaturePrefixController.dispose();
    _shellAllowlistController.dispose();
    _safeWriteRootsController.dispose();
    _diffMaxFilesController.dispose();
    _diffMaxAdditionsController.dispose();
    _diffMaxDeletionsController.dispose();
    _autoMinOpenController.dispose();
    _autoMaxPlanController.dispose();
    _autoMaxStepsController.dispose();
    _autoMaxFailuresController.dispose();
    _autoMaxRetriesController.dispose();
    _autoStepSleepController.dispose();
    _autoIdleSleepController.dispose();
    _autoLockTtlController.dispose();
    _autoFairnessWindowController.dispose();
    _autoWeightP1Controller.dispose();
    _autoWeightP2Controller.dispose();
    _autoWeightP3Controller.dispose();
    _autoBlockedCooldownController.dispose();
    _autoFailedCooldownController.dispose();
    _autoNoProgressController.dispose();
    _autoStuckCooldownController.dispose();
    _autoScopeMaxFilesController.dispose();
    _autoScopeMaxAdditionsController.dispose();
    _autoScopeMaxDeletionsController.dispose();
    _autoApproveBudgetController.dispose();
    _autoSelfTuneWindowController.dispose();
    _autoSelfTuneMinSamplesController.dispose();
    _autoSelfTuneSuccessController.dispose();
    super.dispose();
  }

  void _syncDraft(ProjectSettingsDraft draft) {
    final String signature = _signatureFor(draft);
    if (_lastDraftSignature == signature) {
      return;
    }

    _gitBaseBranchController.text = draft.gitBaseBranch;
    _gitFeaturePrefixController.text = draft.gitFeaturePrefix;
    _gitAutoStash = draft.gitAutoStash;

    _safeWriteEnabled = draft.safeWriteEnabled;
    _safeWriteRootsController.text = draft.safeWriteRoots.join('\n');

    _shellAllowlistProfile = draft.shellAllowlistProfile;
    _shellAllowlistController.text = draft.shellAllowlist.join('\n');
    _customAllowlistDraft = draft.shellAllowlistProfile == 'custom'
        ? draft.shellAllowlist
        : const <String>[];

    _diffMaxFilesController.text = draft.diffBudgetMaxFiles.toString();
    _diffMaxAdditionsController.text = draft.diffBudgetMaxAdditions.toString();
    _diffMaxDeletionsController.text = draft.diffBudgetMaxDeletions.toString();

    _autoMinOpenController.text = draft.autopilotMinOpenTasks.toString();
    _autoMaxPlanController.text = draft.autopilotMaxPlanAdd.toString();
    _autoMaxStepsController.text = draft.autopilotMaxSteps?.toString() ?? '';
    _autoMaxFailuresController.text = draft.autopilotMaxFailures.toString();
    _autoMaxRetriesController.text = draft.autopilotMaxTaskRetries.toString();
    _autoStepSleepController.text = draft.autopilotStepSleepSeconds.toString();
    _autoIdleSleepController.text = draft.autopilotIdleSleepSeconds.toString();
    _autoLockTtlController.text = draft.autopilotLockTtlSeconds.toString();
    _autoFairnessWindowController.text = draft.autopilotFairnessWindow
        .toString();
    _autoWeightP1Controller.text = draft.autopilotPriorityWeightP1.toString();
    _autoWeightP2Controller.text = draft.autopilotPriorityWeightP2.toString();
    _autoWeightP3Controller.text = draft.autopilotPriorityWeightP3.toString();
    _autoBlockedCooldownController.text = draft.autopilotBlockedCooldownSeconds
        .toString();
    _autoFailedCooldownController.text = draft.autopilotFailedCooldownSeconds
        .toString();
    _autoNoProgressController.text = draft.autopilotNoProgressThreshold
        .toString();
    _autoStuckCooldownController.text = draft.autopilotStuckCooldownSeconds
        .toString();
    _autoScopeMaxFilesController.text = draft.autopilotScopeMaxFiles.toString();
    _autoScopeMaxAdditionsController.text = draft.autopilotScopeMaxAdditions
        .toString();
    _autoScopeMaxDeletionsController.text = draft.autopilotScopeMaxDeletions
        .toString();
    _autoApproveBudgetController.text = draft.autopilotApproveBudget.toString();
    _autoSelfTuneWindowController.text = draft.autopilotSelfTuneWindow
        .toString();
    _autoSelfTuneMinSamplesController.text = draft.autopilotSelfTuneMinSamples
        .toString();
    _autoSelfTuneSuccessController.text = draft.autopilotSelfTuneSuccessPercent
        .toString();

    final String mode = draft.autopilotSelectionMode.trim().toLowerCase();
    _selectionMode = mode == 'priority' ? 'priority' : 'fair';
    _autoReactivateBlocked = draft.autopilotReactivateBlocked;
    _autoReactivateFailed = draft.autopilotReactivateFailed;
    _autoSelfRestart = draft.autopilotSelfRestart;
    _autoManualOverride = draft.autopilotManualOverride;
    _autoOvernightUnattendedEnabled = draft.autopilotOvernightUnattendedEnabled;
    _autoSelfTuneEnabled = draft.autopilotSelfTuneEnabled;
    _lastDraftSignature = signature;
  }

  String _signatureFor(ProjectSettingsDraft draft) {
    return <String>[
      draft.gitBaseBranch,
      draft.gitFeaturePrefix,
      draft.gitAutoStash.toString(),
      draft.safeWriteEnabled.toString(),
      draft.safeWriteRoots.join(','),
      draft.shellAllowlistProfile,
      draft.shellAllowlist.join(','),
      draft.diffBudgetMaxFiles.toString(),
      draft.diffBudgetMaxAdditions.toString(),
      draft.diffBudgetMaxDeletions.toString(),
      draft.autopilotMinOpenTasks.toString(),
      draft.autopilotMaxPlanAdd.toString(),
      draft.autopilotStepSleepSeconds.toString(),
      draft.autopilotIdleSleepSeconds.toString(),
      draft.autopilotMaxSteps?.toString() ?? '',
      draft.autopilotMaxFailures.toString(),
      draft.autopilotMaxTaskRetries.toString(),
      draft.autopilotSelectionMode,
      draft.autopilotFairnessWindow.toString(),
      draft.autopilotPriorityWeightP1.toString(),
      draft.autopilotPriorityWeightP2.toString(),
      draft.autopilotPriorityWeightP3.toString(),
      draft.autopilotReactivateBlocked.toString(),
      draft.autopilotReactivateFailed.toString(),
      draft.autopilotBlockedCooldownSeconds.toString(),
      draft.autopilotFailedCooldownSeconds.toString(),
      draft.autopilotLockTtlSeconds.toString(),
      draft.autopilotNoProgressThreshold.toString(),
      draft.autopilotStuckCooldownSeconds.toString(),
      draft.autopilotSelfRestart.toString(),
      draft.autopilotScopeMaxFiles.toString(),
      draft.autopilotScopeMaxAdditions.toString(),
      draft.autopilotScopeMaxDeletions.toString(),
      draft.autopilotApproveBudget.toString(),
      draft.autopilotManualOverride.toString(),
      draft.autopilotOvernightUnattendedEnabled.toString(),
      draft.autopilotSelfTuneEnabled.toString(),
      draft.autopilotSelfTuneWindow.toString(),
      draft.autopilotSelfTuneMinSamples.toString(),
      draft.autopilotSelfTuneSuccessPercent.toString(),
    ].join('|');
  }

  List<String> _parseLines(TextEditingController controller) {
    return controller.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
  }

  void _updateAllowlistForProfile(String profile) {
    if (profile == 'custom') {
      if (_customAllowlistDraft.isNotEmpty) {
        _shellAllowlistController.text = _customAllowlistDraft.join('\n');
      }
      return;
    }
    _customAllowlistDraft = _parseLines(_shellAllowlistController);
    final allowlist = ProjectConfig.resolveShellAllowlist(
      profile: profile,
      customAllowlist: const <String>[],
    );
    _shellAllowlistController.text = allowlist.join('\n');
  }

  String? _validatePositiveInt(String? value, DesktopStrings strings) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return strings.settingsValidationRequired;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return strings.settingsValidationNumberRequired;
    }
    if (parsed < 1) {
      return strings.settingsValidationMinOne;
    }
    return null;
  }

  String? _validateNonNegativeInt(String? value, DesktopStrings strings) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return strings.settingsValidationRequired;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return strings.settingsValidationNumberRequired;
    }
    if (parsed < 0) {
      return strings.settingsValidationNonNegative;
    }
    return null;
  }

  String? _validateOptionalPositiveInt(String? value, DesktopStrings strings) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return strings.settingsValidationNumberRequired;
    }
    if (parsed < 1) {
      return strings.settingsValidationMinOne;
    }
    return null;
  }

  String? _validatePercent(String? value, DesktopStrings strings) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return strings.settingsValidationRequired;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return strings.settingsValidationNumberRequired;
    }
    if (parsed < 0 || parsed > 100) {
      return strings.settingsValidationPercentRange;
    }
    return null;
  }

  Future<void> _save(DesktopStrings strings) async {
    if (widget.controller.isActionInProgress || widget.controller.isLoading) {
      return;
    }

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final ProjectSettingsDraft draft = ProjectSettingsDraft(
      gitBaseBranch: _gitBaseBranchController.text.trim(),
      gitFeaturePrefix: _gitFeaturePrefixController.text.trim(),
      gitAutoStash: _gitAutoStash,
      safeWriteEnabled: _safeWriteEnabled,
      safeWriteRoots: _parseLines(_safeWriteRootsController),
      shellAllowlist: _parseLines(_shellAllowlistController),
      shellAllowlistProfile: _shellAllowlistProfile,
      diffBudgetMaxFiles: int.parse(_diffMaxFilesController.text.trim()),
      diffBudgetMaxAdditions: int.parse(
        _diffMaxAdditionsController.text.trim(),
      ),
      diffBudgetMaxDeletions: int.parse(
        _diffMaxDeletionsController.text.trim(),
      ),
      autopilotMinOpenTasks: int.parse(_autoMinOpenController.text.trim()),
      autopilotMaxPlanAdd: int.parse(_autoMaxPlanController.text.trim()),
      autopilotStepSleepSeconds: int.parse(
        _autoStepSleepController.text.trim(),
      ),
      autopilotIdleSleepSeconds: int.parse(
        _autoIdleSleepController.text.trim(),
      ),
      autopilotMaxSteps: _autoMaxStepsController.text.trim().isEmpty
          ? null
          : int.parse(_autoMaxStepsController.text.trim()),
      autopilotMaxFailures: int.parse(_autoMaxFailuresController.text.trim()),
      autopilotMaxTaskRetries: int.parse(_autoMaxRetriesController.text.trim()),
      autopilotSelectionMode: _selectionMode,
      autopilotFairnessWindow: int.parse(
        _autoFairnessWindowController.text.trim(),
      ),
      autopilotPriorityWeightP1: int.parse(_autoWeightP1Controller.text.trim()),
      autopilotPriorityWeightP2: int.parse(_autoWeightP2Controller.text.trim()),
      autopilotPriorityWeightP3: int.parse(_autoWeightP3Controller.text.trim()),
      autopilotReactivateBlocked: _autoReactivateBlocked,
      autopilotReactivateFailed: _autoReactivateFailed,
      autopilotBlockedCooldownSeconds: int.parse(
        _autoBlockedCooldownController.text.trim(),
      ),
      autopilotFailedCooldownSeconds: int.parse(
        _autoFailedCooldownController.text.trim(),
      ),
      autopilotLockTtlSeconds: int.parse(_autoLockTtlController.text.trim()),
      autopilotNoProgressThreshold: int.parse(
        _autoNoProgressController.text.trim(),
      ),
      autopilotStuckCooldownSeconds: int.parse(
        _autoStuckCooldownController.text.trim(),
      ),
      autopilotSelfRestart: _autoSelfRestart,
      autopilotScopeMaxFiles: int.parse(
        _autoScopeMaxFilesController.text.trim(),
      ),
      autopilotScopeMaxAdditions: int.parse(
        _autoScopeMaxAdditionsController.text.trim(),
      ),
      autopilotScopeMaxDeletions: int.parse(
        _autoScopeMaxDeletionsController.text.trim(),
      ),
      autopilotApproveBudget: int.parse(
        _autoApproveBudgetController.text.trim(),
      ),
      autopilotManualOverride: _autoManualOverride,
      autopilotOvernightUnattendedEnabled: _autoOvernightUnattendedEnabled,
      autopilotSelfTuneEnabled: _autoSelfTuneEnabled,
      autopilotSelfTuneWindow: int.parse(
        _autoSelfTuneWindowController.text.trim(),
      ),
      autopilotSelfTuneMinSamples: int.parse(
        _autoSelfTuneMinSamplesController.text.trim(),
      ),
      autopilotSelfTuneSuccessPercent: int.parse(
        _autoSelfTuneSuccessController.text.trim(),
      ),
    );

    await widget.controller.saveSettings(draft);
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: validator,
      enabled: enabled,
    );
  }

  Widget _twoCol(Widget left, Widget right) {
    return Row(
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: UiChromeConfig.space12),
        Expanded(child: right),
      ],
    );
  }

  Widget _switchTitle(String label, {String? description}) {
    if (description == null) {
      return Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    final Color subdued = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: subdued),
        ),
      ],
    );
  }

  Widget _buildSettingsForm(DesktopStrings strings) {
    final List<Widget> leftCards = <Widget>[
      SettingsCard(
        title: strings.projectSettingsAutopilotBasicsTitle,
        description: strings.projectSettingsAutopilotBasicsSubtitle,
        children: <Widget>[
          _twoCol(
            _numberField(
              controller: _autoMinOpenController,
              label: strings.projectSettingsAutopilotMinOpenTasksLabel,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
            _numberField(
              controller: _autoMaxPlanController,
              label: strings.projectSettingsAutopilotMaxPlanAddLabel,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _twoCol(
            _numberField(
              controller: _autoMaxStepsController,
              label: strings.projectSettingsAutopilotMaxStepsLabel,
              validator: (String? value) =>
                  _validateOptionalPositiveInt(value, strings),
            ),
            _numberField(
              controller: _autoMaxFailuresController,
              label: strings.projectSettingsAutopilotMaxFailuresLabel,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _twoCol(
            _numberField(
              controller: _autoMaxRetriesController,
              label: strings.projectSettingsAutopilotMaxRetriesLabel,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
            _numberField(
              controller: _autoNoProgressController,
              label: strings.projectSettingsAutopilotNoProgressThresholdLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
          ),
        ],
      ),
      const SizedBox(height: UiChromeConfig.space14),
      SettingsCard(
        title: strings.projectSettingsAutopilotTimingTitle,
        description: strings.projectSettingsAutopilotTimingSubtitle,
        children: <Widget>[
          _twoCol(
            _numberField(
              controller: _autoStepSleepController,
              label: strings.projectSettingsAutopilotStepSleepLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
            _numberField(
              controller: _autoIdleSleepController,
              label: strings.projectSettingsAutopilotIdleSleepLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _twoCol(
            _numberField(
              controller: _autoLockTtlController,
              label: strings.projectSettingsAutopilotLockTtlLabel,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
            _numberField(
              controller: _autoStuckCooldownController,
              label: strings.projectSettingsAutopilotStuckCooldownLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          BronzeSwitchTile(
            title: _switchTitle(
              strings.projectSettingsAutopilotSelfRestartLabel,
              description: strings.projectSettingsAutopilotSelfRestartSubtitle,
            ),
            value: _autoSelfRestart,
            onChanged: (bool value) {
              setState(() => _autoSelfRestart = value);
            },
            seed: strings.projectSettingsAutopilotSelfRestartLabel.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      const SizedBox(height: UiChromeConfig.space14),
      SettingsCard(
        title: strings.projectSettingsAutopilotSafetyTitle,
        description: strings.projectSettingsAutopilotSafetySubtitle,
        children: <Widget>[
          _twoCol(
            _numberField(
              controller: _autoScopeMaxFilesController,
              label: strings.projectSettingsAutopilotScopeMaxFilesLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
            _numberField(
              controller: _autoApproveBudgetController,
              label: strings.projectSettingsAutopilotApproveBudgetLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _twoCol(
            _numberField(
              controller: _autoScopeMaxAdditionsController,
              label: strings.projectSettingsAutopilotScopeMaxAdditionsLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
            _numberField(
              controller: _autoScopeMaxDeletionsController,
              label: strings.projectSettingsAutopilotScopeMaxDeletionsLabel,
              validator: (String? value) =>
                  _validateNonNegativeInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          BronzeSwitchTile(
            title: _switchTitle(
              strings.projectSettingsAutopilotManualOverrideLabel,
              description:
                  strings.projectSettingsAutopilotManualOverrideSubtitle,
            ),
            value: _autoManualOverride,
            onChanged: (bool value) {
              setState(() => _autoManualOverride = value);
            },
            seed: strings.projectSettingsAutopilotManualOverrideLabel.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
          BronzeSwitchTile(
            title: _switchTitle(
              strings.projectSettingsAutopilotOvernightLabel,
              description: strings.projectSettingsAutopilotOvernightSubtitle,
            ),
            value: _autoOvernightUnattendedEnabled,
            onChanged: (bool value) {
              setState(() => _autoOvernightUnattendedEnabled = value);
            },
            seed: strings.projectSettingsAutopilotOvernightLabel.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      const SizedBox(height: UiChromeConfig.space14),
      SettingsCard(
        title: strings.projectSettingsAutopilotSelfTuneTitle,
        description: strings.projectSettingsAutopilotSelfTuneSubtitle,
        children: <Widget>[
          BronzeSwitchTile(
            title: _switchTitle(
              strings.projectSettingsAutopilotSelfTuneEnabledLabel,
              description:
                  strings.projectSettingsAutopilotSelfTuneEnabledSubtitle,
            ),
            value: _autoSelfTuneEnabled,
            onChanged: (bool value) {
              setState(() => _autoSelfTuneEnabled = value);
            },
            seed: strings.projectSettingsAutopilotSelfTuneEnabledLabel.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _twoCol(
            _numberField(
              controller: _autoSelfTuneWindowController,
              label: strings.projectSettingsAutopilotSelfTuneWindowLabel,
              validator: (String? value) => _autoSelfTuneEnabled
                  ? _validatePositiveInt(value, strings)
                  : null,
              enabled: _autoSelfTuneEnabled,
            ),
            _numberField(
              controller: _autoSelfTuneMinSamplesController,
              label: strings.projectSettingsAutopilotSelfTuneMinSamplesLabel,
              validator: (String? value) => _autoSelfTuneEnabled
                  ? _validatePositiveInt(value, strings)
                  : null,
              enabled: _autoSelfTuneEnabled,
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _numberField(
            controller: _autoSelfTuneSuccessController,
            label: strings.projectSettingsAutopilotSelfTuneSuccessLabel,
            validator: (String? value) =>
                _autoSelfTuneEnabled ? _validatePercent(value, strings) : null,
            enabled: _autoSelfTuneEnabled,
          ),
        ],
      ),
      const SizedBox(height: UiChromeConfig.space14),
      SettingsCard(
        title: strings.projectSettingsAutopilotSelectionTitle,
        description: strings.projectSettingsAutopilotSelectionSubtitle,
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_selectionMode),
            initialValue: _selectionMode,
            decoration: InputDecoration(
              labelText: strings.projectSettingsAutopilotSelectionModeLabel,
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'fair',
                child: Text(strings.projectSettingsAutopilotSelectionModeFair),
              ),
              DropdownMenuItem<String>(
                value: 'priority',
                child: Text(
                  strings.projectSettingsAutopilotSelectionModePriority,
                ),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _selectionMode = value);
            },
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _numberField(
            controller: _autoFairnessWindowController,
            label: strings.projectSettingsAutopilotFairnessWindowLabel,
            validator: (String? value) =>
                _validateNonNegativeInt(value, strings),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _twoCol(
            _numberField(
              controller: _autoWeightP1Controller,
              label: strings.projectSettingsAutopilotWeightP1Label,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
            _numberField(
              controller: _autoWeightP2Controller,
              label: strings.projectSettingsAutopilotWeightP2Label,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _numberField(
            controller: _autoWeightP3Controller,
            label: strings.projectSettingsAutopilotWeightP3Label,
            validator: (String? value) => _validatePositiveInt(value, strings),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          BronzeSwitchTile(
            title: _switchTitle(
              strings.projectSettingsAutopilotReactivateBlocked,
            ),
            value: _autoReactivateBlocked,
            onChanged: (bool value) {
              setState(() => _autoReactivateBlocked = value);
            },
            seed: strings.projectSettingsAutopilotReactivateBlocked.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
          _numberField(
            controller: _autoBlockedCooldownController,
            label: strings.projectSettingsAutopilotBlockedCooldownLabel,
            validator: (String? value) =>
                _validateNonNegativeInt(value, strings),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          BronzeSwitchTile(
            title: _switchTitle(
              strings.projectSettingsAutopilotReactivateFailed,
            ),
            value: _autoReactivateFailed,
            onChanged: (bool value) {
              setState(() => _autoReactivateFailed = value);
            },
            seed: strings.projectSettingsAutopilotReactivateFailed.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
          _numberField(
            controller: _autoFailedCooldownController,
            label: strings.projectSettingsAutopilotFailedCooldownLabel,
            validator: (String? value) =>
                _validateNonNegativeInt(value, strings),
          ),
        ],
      ),
    ];

    final List<Widget> rightCards = <Widget>[
      SettingsCard(
        title: strings.projectSettingsPoliciesTitle,
        description: strings.projectSettingsPoliciesSubtitle,
        children: <Widget>[
          BronzeSwitchTile(
            title: _switchTitle(strings.projectSettingsSafeWriteEnabledLabel),
            value: _safeWriteEnabled,
            onChanged: (bool value) {
              setState(() => _safeWriteEnabled = value);
            },
            seed: strings.projectSettingsSafeWriteEnabledLabel.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: UiChromeConfig.space10),
          TextFormField(
            controller: _safeWriteRootsController,
            decoration: InputDecoration(
              labelText: strings.projectSettingsSafeWriteRootsLabel,
            ),
            maxLines: 4,
            enabled: _safeWriteEnabled,
            validator: (String? value) {
              if (!_safeWriteEnabled) {
                return null;
              }
              if ((value ?? '').trim().isEmpty) {
                return strings.settingsValidationRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: UiChromeConfig.space10),
          _twoCol(
            _numberField(
              controller: _diffMaxFilesController,
              label: strings.projectSettingsDiffMaxFilesLabel,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
            _numberField(
              controller: _diffMaxAdditionsController,
              label: strings.projectSettingsDiffMaxAdditionsLabel,
              validator: (String? value) =>
                  _validatePositiveInt(value, strings),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          _numberField(
            controller: _diffMaxDeletionsController,
            label: strings.projectSettingsDiffMaxDeletionsLabel,
            validator: (String? value) => _validatePositiveInt(value, strings),
          ),
          const SizedBox(height: UiChromeConfig.space12),
          DropdownButtonFormField<String>(
            initialValue: _shellAllowlistProfile,
            decoration: InputDecoration(
              labelText: strings.projectSettingsShellAllowlistProfileLabel,
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'minimal',
                child: Text(
                  strings.projectSettingsShellAllowlistProfileMinimal,
                ),
              ),
              DropdownMenuItem<String>(
                value: 'standard',
                child: Text(
                  strings.projectSettingsShellAllowlistProfileStandard,
                ),
              ),
              DropdownMenuItem<String>(
                value: 'extended',
                child: Text(
                  strings.projectSettingsShellAllowlistProfileExtended,
                ),
              ),
              DropdownMenuItem<String>(
                value: 'custom',
                child: Text(strings.projectSettingsShellAllowlistProfileCustom),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _shellAllowlistProfile = value;
                _updateAllowlistForProfile(value);
              });
            },
          ),
          const SizedBox(height: UiChromeConfig.space12),
          TextFormField(
            controller: _shellAllowlistController,
            decoration: InputDecoration(
              labelText: _shellAllowlistProfile == 'custom'
                  ? strings.projectSettingsShellAllowlistCustomLabel
                  : strings.projectSettingsShellAllowlistPreviewLabel,
            ),
            maxLines: 4,
            readOnly: _shellAllowlistProfile != 'custom',
            validator: (String? value) {
              if (_shellAllowlistProfile != 'custom') {
                return null;
              }
              if ((value ?? '').trim().isEmpty) {
                return strings.settingsValidationRequired;
              }
              return null;
            },
          ),
        ],
      ),
      const SizedBox(height: UiChromeConfig.space14),
      SettingsCard(
        title: strings.projectSettingsGitTitle,
        description: strings.projectSettingsGitSubtitle,
        children: <Widget>[
          TextFormField(
            controller: _gitBaseBranchController,
            decoration: InputDecoration(
              labelText: strings.projectSettingsGitBaseBranchLabel,
            ),
            validator: (String? value) {
              if ((value ?? '').trim().isEmpty) {
                return strings.settingsValidationRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: UiChromeConfig.space12),
          TextFormField(
            controller: _gitFeaturePrefixController,
            decoration: InputDecoration(
              labelText: strings.projectSettingsGitFeaturePrefixLabel,
            ),
            validator: (String? value) {
              if ((value ?? '').trim().isEmpty) {
                return strings.settingsValidationRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: UiChromeConfig.space12),
          BronzeSwitchTile(
            title: _switchTitle(
              strings.projectSettingsGitAutoStashLabel,
              description: strings.projectSettingsGitAutoStashSubtitle,
            ),
            value: _gitAutoStash,
            onChanged: (bool value) {
              setState(() => _gitAutoStash = value);
            },
            seed: strings.projectSettingsGitAutoStashLabel.hashCode,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 1100;
        if (compact) {
          return SingleChildScrollView(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < leftCards.length; i++) ...<Widget>[
                  leftCards[i],
                ],
                const SizedBox(height: UiChromeConfig.space14),
                for (int i = 0; i < rightCards.length; i++) ...<Widget>[
                  rightCards[i],
                ],
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[for (final Widget card in leftCards) card],
                ),
              ),
              const SizedBox(width: UiChromeConfig.space14),
              Expanded(
                child: Column(
                  children: <Widget>[
                    for (final Widget card in rightCards) card,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final ProjectSettingsDraft? draft = widget.controller.settingsDraft;
        if (draft != null) {
          _syncDraft(draft);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            WorkspaceHeader(
              title: strings.projectSettingsTitle,
              subtitle: strings.projectSettingsSubtitle,
              seed: 91,
            ),
            const SizedBox(height: UiChromeConfig.space12),
            Expanded(
              child: draft == null
                  ? Center(
                      child: widget.controller.isLoading
                          ? const CircularProgressIndicator.adaptive()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(strings.projectSettingsUnavailableLabel),
                                const SizedBox(height: UiChromeConfig.space10),
                                OutlinedButton(
                                  onPressed: () => unawaited(
                                    widget.controller.refresh(
                                      includeConfig: true,
                                    ),
                                  ),
                                  child: Text(
                                    strings.projectSettingsRetryAction,
                                  ),
                                ),
                              ],
                            ),
                    )
                  : Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: _buildSettingsForm(strings),
                    ),
            ),
            const SizedBox(height: UiChromeConfig.space14),
            Align(
              alignment: Alignment.centerRight,
              child: BronzeButton(
                label: strings.projectSettingsSaveAction,
                onPressed: widget.controller.isActionInProgress
                    ? null
                    : () => unawaited(_save(strings)),
                glow: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
