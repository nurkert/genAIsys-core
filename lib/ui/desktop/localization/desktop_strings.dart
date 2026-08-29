// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/foundation.dart';

@immutable
class DesktopStatCopy {
  const DesktopStatCopy({
    required this.title,
    required this.value,
    required this.delta,
  });

  final String title;
  final String value;
  final String delta;
}

@immutable
class DesktopActivityCopy {
  const DesktopActivityCopy({
    required this.avatar,
    required this.title,
    required this.subtitle,
  });

  final String avatar;
  final String title;
  final String subtitle;
}

@immutable
class DesktopStrings {
  const DesktopStrings({
    required this.appTitle,
    required this.brandName,
    required this.tooltipShowLeftSidebar,
    required this.tooltipHideLeftSidebar,
    required this.tooltipShowRightSidebar,
    required this.tooltipHideRightSidebar,
    required this.menuFile,
    required this.menuApp,
    required this.menuView,
    required this.menuExit,
    required this.menuSettings,
    required this.menuToggleLeftSidebar,
    required this.menuToggleRightSidebar,
    required this.menuSettingsShortcutMac,
    required this.menuSettingsShortcutDesktop,
    required this.defaultProjectWindowName,
    required this.dashboardTitle,
    required this.dashboardSubtitle,
    required this.newProject,
    required this.teamActivity,
    required this.quickCreate,
    required this.projectName,
    required this.owner,
    required this.description,
    required this.reset,
    required this.create,
    required this.inspector,
    required this.timeline,
    required this.quickFilters,
    required this.runAction,
    required this.revenueMomentum,
    required this.automationReadiness,
    required this.targetLabel,
    required this.projectHubTitle,
    required this.projectHubSubtitle,
    required this.recentProjectsTitle,
    required this.openProjectAction,
    required this.createProjectAction,
    required this.deleteProjectAction,
    required this.generalSettingsAction,
    required this.noProjectsLabel,
    required this.projectNameInputLabel,
    required this.projectNameInputHint,
    required this.projectPathInputLabel,
    required this.projectPathInputHint,
    required this.projectPathValidationError,
    required this.projectSaveFailedLabel,
    required this.openProjectFailedLabel,
    required this.projectDeleteFailedLabel,
    required this.deleteProjectConfirmationPrefix,
    required this.cancelAction,
    required this.lastOpenedProjectBadge,
    required this.neverOpenedLabel,
    required this.settingsWindowName,
    required this.settingsTitle,
    required this.settingsSubtitle,
    required this.settingsSidebarTitle,
    required this.settingsNavGeneral,
    required this.settingsNavNotifications,
    required this.settingsNavAutomation,
    required this.settingsNavSecurity,
    required this.settingsNavStorage,
    required this.settingsGeneralSectionSubtitle,
    required this.settingsNotificationsSectionSubtitle,
    required this.settingsAutomationSectionSubtitle,
    required this.settingsSecuritySectionSubtitle,
    required this.settingsStorageSectionSubtitle,
    required this.settingsStorageApplicationPathLabel,
    required this.settingsStorageProjectRegistryPathLabel,
    required this.settingsStoragePathUnavailable,
    required this.settingsAppearanceTitle,
    required this.settingsAutomationTitle,
    required this.settingsSecurityTitle,
    required this.settingsLanguageLabel,
    required this.settingsThemeModeLabel,
    required this.settingsThemeModeSystem,
    required this.settingsThemeModeLight,
    required this.settingsThemeModeDark,
    required this.settingsNotificationsLabel,
    required this.settingsAutopilotLabel,
    required this.settingsTelemetryLabel,
    required this.settingsSecretPolicyLabel,
    required this.settingsResetAction,
    required this.settingsSaveAction,
    required this.settingsValidationRequired,
    required this.settingsValidationNumberRequired,
    required this.settingsValidationMinOne,
    required this.settingsValidationNonNegative,
    required this.settingsValidationPercentRange,
    required this.chatTitle,
    required this.chatSubtitle,
    required this.chatInputPlaceholder,
    required this.chatSendAction,
    required this.chatAssistantName,
    required this.chatUserDisplayName,
    required this.chatWelcomeMessage,
    required this.chatUserSeedMessage,
    required this.chatAssistantSeedReply,
    required this.chatAssistantAcknowledgeReply,
    required this.chatNoProjectRootAttachedMessage,
    required this.chatConnectedProjectRootPrefix,
    required this.backlogTitle,
    required this.backlogSubtitle,
    required this.backlogBlockedColumn,
    required this.backlogTodoColumn,
    required this.backlogWorkingColumn,
    required this.backlogDoneColumn,
    required this.backlogTaskDetailsTitle,
    required this.backlogNoTaskSelectedLabel,
    required this.backlogTaskTitleLabel,
    required this.backlogPriorityLabel,
    required this.backlogAgentLabel,
    required this.backlogSubtasksLabel,
    required this.backlogPriorityP1,
    required this.backlogPriorityP2,
    required this.backlogPriorityP3,
    required this.backlogSearchPlaceholder,
    required this.backlogDeleteConfirmTitle,
    required this.backlogDeleteConfirmMessage,
    required this.confirmAction,
    required this.dashboardSectionTitle,
    required this.reportsTitle,
    required this.reportsSubtitle,
    required this.reportsDeliveryHealthTitle,
    required this.reportsQualityGateTitle,
    required this.reportsAgentUtilizationTitle,
    required this.reportsRunLogTitle,
    required this.reportsRunLogSearchHint,
    required this.reportsRunLogFilterLabel,
    required this.reportsRunLogFilterAll,
    required this.reportsRunLogFilterErrors,
    required this.reportsRunLogRefreshTooltip,
    required this.reportsRunLogLoadOlderAction,
    required this.reportsRunLogEmptyLabel,
    required this.reportsRunLogCopyJsonAction,
    required this.reportsRunLogCopiedToast,
    required this.reportsPolicyViolationsLabel,
    required this.autopilotTitle,
    required this.autopilotSubtitle,
    required this.autopilotPlayAction,
    required this.autopilotPauseAction,
    required this.autopilotStateLabel,
    required this.autopilotStatusRunning,
    required this.autopilotStatusPaused,
    required this.autopilotCurrentTaskLabel,
    required this.autopilotCurrentSubtaskLabel,
    required this.autopilotLoopStageLabel,
    required this.autopilotCycleLabel,
    required this.autopilotRetriesLabel,
    required this.autopilotStagePlanning,
    required this.autopilotStageSpecing,
    required this.autopilotStageCoding,
    required this.autopilotStageTesting,
    required this.autopilotStageReview,
    required this.autopilotTimelineTitle,
    required this.autopilotTabLive,
    required this.autopilotTabTimeline,
    required this.autopilotTabDetails,
    required this.autopilotTaskActionsLabel,
    required this.autopilotReviewActionsLabel,
    required this.autopilotRunStepAction,
    required this.autopilotStopAction,
    required this.autopilotActivateNextAction,
    required this.autopilotMarkDoneAction,
    required this.autopilotBlockActiveAction,
    required this.autopilotDeactivateAction,
    required this.autopilotApproveAction,
    required this.autopilotRejectAction,
    required this.autopilotClearReviewAction,
    required this.autopilotRuntimeSummaryTitle,
    required this.autopilotHealthChecksTitle,
    required this.autopilotLoopConfigTitle,
    required this.autopilotLastErrorTitle,
    required this.projectSettingsTitle,
    required this.projectSettingsSubtitle,
    required this.projectSettingsUnavailableLabel,
    required this.projectSettingsRetryAction,
    required this.projectSettingsPoliciesTitle,
    required this.projectSettingsPoliciesSubtitle,
    required this.projectSettingsSafeWriteEnabledLabel,
    required this.projectSettingsSafeWriteRootsLabel,
    required this.projectSettingsDiffMaxFilesLabel,
    required this.projectSettingsDiffMaxAdditionsLabel,
    required this.projectSettingsDiffMaxDeletionsLabel,
    required this.projectSettingsShellAllowlistProfileLabel,
    required this.projectSettingsShellAllowlistProfileMinimal,
    required this.projectSettingsShellAllowlistProfileStandard,
    required this.projectSettingsShellAllowlistProfileExtended,
    required this.projectSettingsShellAllowlistProfileCustom,
    required this.projectSettingsShellAllowlistCustomLabel,
    required this.projectSettingsShellAllowlistPreviewLabel,
    required this.projectSettingsGitTitle,
    required this.projectSettingsGitSubtitle,
    required this.projectSettingsGitBaseBranchLabel,
    required this.projectSettingsGitFeaturePrefixLabel,
    required this.projectSettingsGitAutoStashLabel,
    required this.projectSettingsGitAutoStashSubtitle,
    required this.projectSettingsAutopilotBasicsTitle,
    required this.projectSettingsAutopilotBasicsSubtitle,
    required this.projectSettingsAutopilotMinOpenTasksLabel,
    required this.projectSettingsAutopilotMaxPlanAddLabel,
    required this.projectSettingsAutopilotMaxStepsLabel,
    required this.projectSettingsAutopilotMaxFailuresLabel,
    required this.projectSettingsAutopilotMaxRetriesLabel,
    required this.projectSettingsAutopilotNoProgressThresholdLabel,
    required this.projectSettingsAutopilotTimingTitle,
    required this.projectSettingsAutopilotTimingSubtitle,
    required this.projectSettingsAutopilotStepSleepLabel,
    required this.projectSettingsAutopilotIdleSleepLabel,
    required this.projectSettingsAutopilotLockTtlLabel,
    required this.projectSettingsAutopilotStuckCooldownLabel,
    required this.projectSettingsAutopilotSelfRestartLabel,
    required this.projectSettingsAutopilotSelfRestartSubtitle,
    required this.projectSettingsAutopilotSafetyTitle,
    required this.projectSettingsAutopilotSafetySubtitle,
    required this.projectSettingsAutopilotScopeMaxFilesLabel,
    required this.projectSettingsAutopilotApproveBudgetLabel,
    required this.projectSettingsAutopilotScopeMaxAdditionsLabel,
    required this.projectSettingsAutopilotScopeMaxDeletionsLabel,
    required this.projectSettingsAutopilotManualOverrideLabel,
    required this.projectSettingsAutopilotManualOverrideSubtitle,
    required this.projectSettingsAutopilotOvernightLabel,
    required this.projectSettingsAutopilotOvernightSubtitle,
    required this.projectSettingsAutopilotSelfTuneTitle,
    required this.projectSettingsAutopilotSelfTuneSubtitle,
    required this.projectSettingsAutopilotSelfTuneEnabledLabel,
    required this.projectSettingsAutopilotSelfTuneEnabledSubtitle,
    required this.projectSettingsAutopilotSelfTuneWindowLabel,
    required this.projectSettingsAutopilotSelfTuneMinSamplesLabel,
    required this.projectSettingsAutopilotSelfTuneSuccessLabel,
    required this.projectSettingsAutopilotSelectionTitle,
    required this.projectSettingsAutopilotSelectionSubtitle,
    required this.projectSettingsAutopilotSelectionModeLabel,
    required this.projectSettingsAutopilotSelectionModeFair,
    required this.projectSettingsAutopilotSelectionModePriority,
    required this.projectSettingsAutopilotFairnessWindowLabel,
    required this.projectSettingsAutopilotWeightP1Label,
    required this.projectSettingsAutopilotWeightP2Label,
    required this.projectSettingsAutopilotWeightP3Label,
    required this.projectSettingsAutopilotReactivateBlocked,
    required this.projectSettingsAutopilotBlockedCooldownLabel,
    required this.projectSettingsAutopilotReactivateFailed,
    required this.projectSettingsAutopilotFailedCooldownLabel,
    required this.projectSettingsSaveAction,
    required this.agentCodexLabel,
    required this.agentGeminiLabel,
    required this.agentReviewerLabel,
    required this.hubSearchPlaceholder,
    required this.hubNavProjects,
    required this.hubNavChat,
    required this.hubChatTitle,
    required this.hubNavSettings,
    required this.hubNavLearn,
    required this.hubNewActionShort,
    required this.hubOpenActionShort,
    required this.hubCloneRepositoryAction,
    required this.hubOpenExistingProjectAction,
    required this.hubLearnPlaceholder,
    required this.hubSettingsPlaceholder,
    required this.hubCloneUrlLabel,
    required this.hubCloneUrlHint,
    required this.hubCloneTargetLabel,
    required this.hubCloneTargetHint,
    required this.hubCloneAction,
    required this.hubLastOpenedPrefix,
    required this.navLabels,
    required this.statCards,
    required this.activities,
    required this.timelineEntries,
    required this.quickFilterLabels,
  });

  final String appTitle;
  final String brandName;
  final String tooltipShowLeftSidebar;
  final String tooltipHideLeftSidebar;
  final String tooltipShowRightSidebar;
  final String tooltipHideRightSidebar;
  final String menuFile;
  final String menuApp;
  final String menuView;
  final String menuExit;
  final String menuSettings;
  final String menuToggleLeftSidebar;
  final String menuToggleRightSidebar;
  final String menuSettingsShortcutMac;
  final String menuSettingsShortcutDesktop;
  final String defaultProjectWindowName;
  final String dashboardTitle;
  final String dashboardSubtitle;
  final String newProject;
  final String teamActivity;
  final String quickCreate;
  final String projectName;
  final String owner;
  final String description;
  final String reset;
  final String create;
  final String inspector;
  final String timeline;
  final String quickFilters;
  final String runAction;
  final String revenueMomentum;
  final String automationReadiness;
  final String targetLabel;
  final String projectHubTitle;
  final String projectHubSubtitle;
  final String recentProjectsTitle;
  final String openProjectAction;
  final String createProjectAction;
  final String deleteProjectAction;
  final String generalSettingsAction;
  final String noProjectsLabel;
  final String projectNameInputLabel;
  final String projectNameInputHint;
  final String projectPathInputLabel;
  final String projectPathInputHint;
  final String projectPathValidationError;
  final String projectSaveFailedLabel;
  final String openProjectFailedLabel;
  final String projectDeleteFailedLabel;
  final String deleteProjectConfirmationPrefix;
  final String cancelAction;
  final String lastOpenedProjectBadge;
  final String neverOpenedLabel;
  final String settingsWindowName;
  final String settingsTitle;
  final String settingsSubtitle;
  final String settingsSidebarTitle;
  final String settingsNavGeneral;
  final String settingsNavNotifications;
  final String settingsNavAutomation;
  final String settingsNavSecurity;
  final String settingsNavStorage;
  final String settingsGeneralSectionSubtitle;
  final String settingsNotificationsSectionSubtitle;
  final String settingsAutomationSectionSubtitle;
  final String settingsSecuritySectionSubtitle;
  final String settingsStorageSectionSubtitle;
  final String settingsStorageApplicationPathLabel;
  final String settingsStorageProjectRegistryPathLabel;
  final String settingsStoragePathUnavailable;
  final String settingsAppearanceTitle;
  final String settingsAutomationTitle;
  final String settingsSecurityTitle;
  final String settingsLanguageLabel;
  final String settingsThemeModeLabel;
  final String settingsThemeModeSystem;
  final String settingsThemeModeLight;
  final String settingsThemeModeDark;
  final String settingsNotificationsLabel;
  final String settingsAutopilotLabel;
  final String settingsTelemetryLabel;
  final String settingsSecretPolicyLabel;
  final String settingsResetAction;
  final String settingsSaveAction;
  final String settingsValidationRequired;
  final String settingsValidationNumberRequired;
  final String settingsValidationMinOne;
  final String settingsValidationNonNegative;
  final String settingsValidationPercentRange;
  final String chatTitle;
  final String chatSubtitle;
  final String chatInputPlaceholder;
  final String chatSendAction;
  final String chatAssistantName;
  final String chatUserDisplayName;
  final String chatWelcomeMessage;
  final String chatUserSeedMessage;
  final String chatAssistantSeedReply;
  final String chatAssistantAcknowledgeReply;
  final String chatNoProjectRootAttachedMessage;
  final String chatConnectedProjectRootPrefix;
  final String backlogTitle;
  final String backlogSubtitle;
  final String backlogBlockedColumn;
  final String backlogTodoColumn;
  final String backlogWorkingColumn;
  final String backlogDoneColumn;
  final String backlogTaskDetailsTitle;
  final String backlogNoTaskSelectedLabel;
  final String backlogTaskTitleLabel;
  final String backlogPriorityLabel;
  final String backlogAgentLabel;
  final String backlogSubtasksLabel;
  final String backlogPriorityP1;
  final String backlogPriorityP2;
  final String backlogPriorityP3;
  final String backlogSearchPlaceholder;
  final String backlogDeleteConfirmTitle;
  final String backlogDeleteConfirmMessage;
  final String confirmAction;
  final String dashboardSectionTitle;
  final String reportsTitle;
  final String reportsSubtitle;
  final String reportsDeliveryHealthTitle;
  final String reportsQualityGateTitle;
  final String reportsAgentUtilizationTitle;
  final String reportsRunLogTitle;
  final String reportsRunLogSearchHint;
  final String reportsRunLogFilterLabel;
  final String reportsRunLogFilterAll;
  final String reportsRunLogFilterErrors;
  final String reportsRunLogRefreshTooltip;
  final String reportsRunLogLoadOlderAction;
  final String reportsRunLogEmptyLabel;
  final String reportsRunLogCopyJsonAction;
  final String reportsRunLogCopiedToast;
  final String reportsPolicyViolationsLabel;
  final String autopilotTitle;
  final String autopilotSubtitle;
  final String autopilotPlayAction;
  final String autopilotPauseAction;
  final String autopilotStateLabel;
  final String autopilotStatusRunning;
  final String autopilotStatusPaused;
  final String autopilotCurrentTaskLabel;
  final String autopilotCurrentSubtaskLabel;
  final String autopilotLoopStageLabel;
  final String autopilotCycleLabel;
  final String autopilotRetriesLabel;
  final String autopilotStagePlanning;
  final String autopilotStageSpecing;
  final String autopilotStageCoding;
  final String autopilotStageTesting;
  final String autopilotStageReview;
  final String autopilotTimelineTitle;
  final String autopilotTabLive;
  final String autopilotTabTimeline;
  final String autopilotTabDetails;
  final String autopilotTaskActionsLabel;
  final String autopilotReviewActionsLabel;
  final String autopilotRunStepAction;
  final String autopilotStopAction;
  final String autopilotActivateNextAction;
  final String autopilotMarkDoneAction;
  final String autopilotBlockActiveAction;
  final String autopilotDeactivateAction;
  final String autopilotApproveAction;
  final String autopilotRejectAction;
  final String autopilotClearReviewAction;
  final String autopilotRuntimeSummaryTitle;
  final String autopilotHealthChecksTitle;
  final String autopilotLoopConfigTitle;
  final String autopilotLastErrorTitle;
  final String projectSettingsTitle;
  final String projectSettingsSubtitle;
  final String projectSettingsUnavailableLabel;
  final String projectSettingsRetryAction;
  final String projectSettingsPoliciesTitle;
  final String projectSettingsPoliciesSubtitle;
  final String projectSettingsSafeWriteEnabledLabel;
  final String projectSettingsSafeWriteRootsLabel;
  final String projectSettingsDiffMaxFilesLabel;
  final String projectSettingsDiffMaxAdditionsLabel;
  final String projectSettingsDiffMaxDeletionsLabel;
  final String projectSettingsShellAllowlistProfileLabel;
  final String projectSettingsShellAllowlistProfileMinimal;
  final String projectSettingsShellAllowlistProfileStandard;
  final String projectSettingsShellAllowlistProfileExtended;
  final String projectSettingsShellAllowlistProfileCustom;
  final String projectSettingsShellAllowlistCustomLabel;
  final String projectSettingsShellAllowlistPreviewLabel;
  final String projectSettingsGitTitle;
  final String projectSettingsGitSubtitle;
  final String projectSettingsGitBaseBranchLabel;
  final String projectSettingsGitFeaturePrefixLabel;
  final String projectSettingsGitAutoStashLabel;
  final String projectSettingsGitAutoStashSubtitle;
  final String projectSettingsAutopilotBasicsTitle;
  final String projectSettingsAutopilotBasicsSubtitle;
  final String projectSettingsAutopilotMinOpenTasksLabel;
  final String projectSettingsAutopilotMaxPlanAddLabel;
  final String projectSettingsAutopilotMaxStepsLabel;
  final String projectSettingsAutopilotMaxFailuresLabel;
  final String projectSettingsAutopilotMaxRetriesLabel;
  final String projectSettingsAutopilotNoProgressThresholdLabel;
  final String projectSettingsAutopilotTimingTitle;
  final String projectSettingsAutopilotTimingSubtitle;
  final String projectSettingsAutopilotStepSleepLabel;
  final String projectSettingsAutopilotIdleSleepLabel;
  final String projectSettingsAutopilotLockTtlLabel;
  final String projectSettingsAutopilotStuckCooldownLabel;
  final String projectSettingsAutopilotSelfRestartLabel;
  final String projectSettingsAutopilotSelfRestartSubtitle;
  final String projectSettingsAutopilotSafetyTitle;
  final String projectSettingsAutopilotSafetySubtitle;
  final String projectSettingsAutopilotScopeMaxFilesLabel;
  final String projectSettingsAutopilotApproveBudgetLabel;
  final String projectSettingsAutopilotScopeMaxAdditionsLabel;
  final String projectSettingsAutopilotScopeMaxDeletionsLabel;
  final String projectSettingsAutopilotManualOverrideLabel;
  final String projectSettingsAutopilotManualOverrideSubtitle;
  final String projectSettingsAutopilotOvernightLabel;
  final String projectSettingsAutopilotOvernightSubtitle;
  final String projectSettingsAutopilotSelfTuneTitle;
  final String projectSettingsAutopilotSelfTuneSubtitle;
  final String projectSettingsAutopilotSelfTuneEnabledLabel;
  final String projectSettingsAutopilotSelfTuneEnabledSubtitle;
  final String projectSettingsAutopilotSelfTuneWindowLabel;
  final String projectSettingsAutopilotSelfTuneMinSamplesLabel;
  final String projectSettingsAutopilotSelfTuneSuccessLabel;
  final String projectSettingsAutopilotSelectionTitle;
  final String projectSettingsAutopilotSelectionSubtitle;
  final String projectSettingsAutopilotSelectionModeLabel;
  final String projectSettingsAutopilotSelectionModeFair;
  final String projectSettingsAutopilotSelectionModePriority;
  final String projectSettingsAutopilotFairnessWindowLabel;
  final String projectSettingsAutopilotWeightP1Label;
  final String projectSettingsAutopilotWeightP2Label;
  final String projectSettingsAutopilotWeightP3Label;
  final String projectSettingsAutopilotReactivateBlocked;
  final String projectSettingsAutopilotBlockedCooldownLabel;
  final String projectSettingsAutopilotReactivateFailed;
  final String projectSettingsAutopilotFailedCooldownLabel;
  final String projectSettingsSaveAction;
  final String agentCodexLabel;
  final String agentGeminiLabel;
  final String agentReviewerLabel;
  final String hubSearchPlaceholder;
  final String hubNavProjects;
  final String hubNavChat;
  final String hubChatTitle;
  final String hubNavSettings;
  final String hubNavLearn;
  final String hubNewActionShort;
  final String hubOpenActionShort;
  final String hubCloneRepositoryAction;
  final String hubOpenExistingProjectAction;
  final String hubLearnPlaceholder;
  final String hubSettingsPlaceholder;
  final String hubCloneUrlLabel;
  final String hubCloneUrlHint;
  final String hubCloneTargetLabel;
  final String hubCloneTargetHint;
  final String hubCloneAction;
  final String hubLastOpenedPrefix;
  final List<String> navLabels;
  final List<DesktopStatCopy> statCards;
  final List<DesktopActivityCopy> activities;
  final List<String> timelineEntries;
  final List<String> quickFilterLabels;

  static const DesktopStrings english = DesktopStrings(
    appTitle: 'Genaisys',
    brandName: 'Genaisys',
    tooltipShowLeftSidebar: 'Show left sidebar',
    tooltipHideLeftSidebar: 'Hide left sidebar',
    tooltipShowRightSidebar: 'Show right sidebar',
    tooltipHideRightSidebar: 'Hide right sidebar',
    menuFile: 'File',
    menuApp: 'Genaisys',
    menuView: 'View',
    menuExit: 'Quit',
    menuSettings: 'Settings',
    menuToggleLeftSidebar: 'Toggle Left Sidebar',
    menuToggleRightSidebar: 'Toggle Right Sidebar',
    menuSettingsShortcutMac: 'Cmd+,',
    menuSettingsShortcutDesktop: 'Ctrl+,',
    defaultProjectWindowName: 'Genaisys Project',
    dashboardTitle: 'Executive Dashboard',
    dashboardSubtitle: 'Clean desktop shell with restrained metallic accents.',
    newProject: 'New Project',
    teamActivity: 'Team Activity',
    quickCreate: 'Quick Create',
    projectName: 'Project name',
    owner: 'Owner',
    description: 'Description',
    reset: 'Reset',
    create: 'Create',
    inspector: 'Inspector',
    timeline: 'Timeline',
    quickFilters: 'Quick Filters',
    runAction: 'Run Action',
    revenueMomentum: 'Task Completion Trend',
    automationReadiness: 'Task Status',
    targetLabel: 'Done',
    projectHubTitle: 'Project Hub',
    projectHubSubtitle:
        'Choose a project window, create a new project, or open global settings.',
    recentProjectsTitle: 'Recent Projects',
    openProjectAction: 'Open Project',
    createProjectAction: 'New Project',
    deleteProjectAction: 'Delete Project',
    generalSettingsAction: 'Application Settings',
    noProjectsLabel: 'No projects available.',
    projectNameInputLabel: 'Project Name',
    projectNameInputHint: 'My Workspace',
    projectPathInputLabel: 'Project Path',
    projectPathInputHint: '/Users/name/Workspaces/my_workspace',
    projectPathValidationError: 'Project path is required.',
    projectSaveFailedLabel: 'Failed to save project',
    openProjectFailedLabel: 'Failed to open project window',
    projectDeleteFailedLabel: 'Failed to delete project',
    deleteProjectConfirmationPrefix: 'Delete project',
    cancelAction: 'Cancel',
    lastOpenedProjectBadge: 'Last Opened',
    neverOpenedLabel: 'Never opened',
    settingsWindowName: 'Application Settings',
    settingsTitle: 'Application Settings',
    settingsSubtitle:
        'Configure global desktop behavior, automation defaults, and security posture.',
    settingsSidebarTitle: 'Preferences',
    settingsNavGeneral: 'General',
    settingsNavNotifications: 'Notifications',
    settingsNavAutomation: 'Automation',
    settingsNavSecurity: 'Security',
    settingsNavStorage: 'Storage',
    settingsGeneralSectionSubtitle:
        'Language and baseline desktop behavior for the entire app.',
    settingsNotificationsSectionSubtitle:
        'Configure global notification behavior for desktop events.',
    settingsAutomationSectionSubtitle:
        'Default unattended behavior and diagnostic signal collection.',
    settingsSecuritySectionSubtitle:
        'Global safeguards that protect secrets and sensitive output.',
    settingsStorageSectionSubtitle:
        'Inspect where global settings and project registry data are stored.',
    settingsStorageApplicationPathLabel: 'Application Settings File',
    settingsStorageProjectRegistryPathLabel: 'Project Registry File',
    settingsStoragePathUnavailable: '(storage path unavailable)',
    settingsAppearanceTitle: 'Appearance',
    settingsAutomationTitle: 'Automation',
    settingsSecurityTitle: 'Security',
    settingsLanguageLabel: 'Language (future localization-ready)',
    settingsThemeModeLabel: 'Theme mode',
    settingsThemeModeSystem: 'System',
    settingsThemeModeLight: 'Light',
    settingsThemeModeDark: 'Dark',
    settingsNotificationsLabel: 'Desktop notifications',
    settingsAutopilotLabel: 'Enable unattended autopilot by default',
    settingsTelemetryLabel: 'Store local diagnostic telemetry',
    settingsSecretPolicyLabel: 'Strict secret redaction policy',
    settingsResetAction: 'Reset',
    settingsSaveAction: 'Save Changes',
    settingsValidationRequired: 'Required',
    settingsValidationNumberRequired: 'Number required',
    settingsValidationMinOne: 'Must be >= 1',
    settingsValidationNonNegative: 'Must be >= 0',
    settingsValidationPercentRange: 'Must be 0..100',
    chatTitle: 'Project Chat',
    chatSubtitle:
        'Coordinate implementation details, ask questions, and track execution decisions.',
    chatInputPlaceholder: 'Ask the workspace assistant...',
    chatSendAction: 'Send',
    chatAssistantName: 'Genaisys Assistant',
    chatUserDisplayName: 'You',
    chatWelcomeMessage:
        'I am ready. I can help break down tasks, explain run status, and draft implementation steps.',
    chatUserSeedMessage:
        'Please summarize what changed in the shell architecture today.',
    chatAssistantSeedReply:
        'Topbar behavior is now platform-aware, and global app settings are shared between UI and CLI.',
    chatAssistantAcknowledgeReply:
        'Acknowledged. I captured your note and mapped it to the active task context.',
    chatNoProjectRootAttachedMessage: 'No project root is attached yet.',
    chatConnectedProjectRootPrefix: 'Connected project root:',
    backlogTitle: 'Backlog Board',
    backlogSubtitle:
        'Organize work by delivery state. Drag tasks between columns.',
    backlogBlockedColumn: 'Blocked',
    backlogTodoColumn: 'Todo',
    backlogWorkingColumn: 'Working',
    backlogDoneColumn: 'Done',
    backlogTaskDetailsTitle: 'Task Details',
    backlogNoTaskSelectedLabel:
        'Select a task to edit title, description, priority, assignment, and subtasks.',
    backlogTaskTitleLabel: 'Title',
    backlogPriorityLabel: 'Priority',
    backlogAgentLabel: 'Assigned Agent',
    backlogSubtasksLabel: 'Subtasks',
    backlogPriorityP1: 'P1 - Critical',
    backlogPriorityP2: 'P2 - Important',
    backlogPriorityP3: 'P3 - Nice to Have',
    backlogSearchPlaceholder: 'Search tasks…',
    backlogDeleteConfirmTitle: 'Delete Task',
    backlogDeleteConfirmMessage:
        'Are you sure you want to permanently delete this task? This action cannot be undone.',
    confirmAction: 'Delete',
    dashboardSectionTitle: 'Dashboard',
    reportsTitle: 'Reports',
    reportsSubtitle:
        'Inspect execution traces and review runtime health signals.',
    reportsDeliveryHealthTitle: 'Delivery Health',
    reportsQualityGateTitle: 'Quality Gates',
    reportsAgentUtilizationTitle: 'Agent Utilization',
    reportsRunLogTitle: 'Run Log',
    reportsRunLogSearchHint: 'Search events, messages, or IDs...',
    reportsRunLogFilterLabel: 'Filter',
    reportsRunLogFilterAll: 'All events',
    reportsRunLogFilterErrors: 'Errors only',
    reportsRunLogRefreshTooltip: 'Refresh logs',
    reportsRunLogLoadOlderAction: 'Load older',
    reportsRunLogEmptyLabel: 'No log entries found.',
    reportsRunLogCopyJsonAction: 'Copy JSON',
    reportsRunLogCopiedToast: 'Copied.',
    reportsPolicyViolationsLabel: 'Policy Violations',
    autopilotTitle: 'Autopilot Control',
    autopilotSubtitle:
        'Start or pause unattended execution and inspect the current loop state in real time.',
    autopilotPlayAction: 'Play',
    autopilotPauseAction: 'Pause',
    autopilotStateLabel: 'State',
    autopilotStatusRunning: 'Running',
    autopilotStatusPaused: 'Paused',
    autopilotCurrentTaskLabel: 'Current Task',
    autopilotCurrentSubtaskLabel: 'Current Subtask',
    autopilotLoopStageLabel: 'Loop Stage',
    autopilotCycleLabel: 'Cycle',
    autopilotRetriesLabel: 'Retries',
    autopilotStagePlanning: 'Planning',
    autopilotStageSpecing: 'Specing',
    autopilotStageCoding: 'Coding',
    autopilotStageTesting: 'Testing',
    autopilotStageReview: 'Review',
    autopilotTimelineTitle: 'Stage Timeline',
    autopilotTabLive: 'Live',
    autopilotTabTimeline: 'Timeline',
    autopilotTabDetails: 'Details',
    autopilotTaskActionsLabel: 'Task Actions',
    autopilotReviewActionsLabel: 'Review Actions',
    autopilotRunStepAction: 'Run Step',
    autopilotStopAction: 'Stop',
    autopilotActivateNextAction: 'Activate Next',
    autopilotMarkDoneAction: 'Mark Done',
    autopilotBlockActiveAction: 'Block Active',
    autopilotDeactivateAction: 'Deactivate',
    autopilotApproveAction: 'Approve',
    autopilotRejectAction: 'Reject',
    autopilotClearReviewAction: 'Clear Review',
    autopilotRuntimeSummaryTitle: 'Runtime Summary',
    autopilotHealthChecksTitle: 'Health Checks',
    autopilotLoopConfigTitle: 'Loop Config',
    autopilotLastErrorTitle: 'Last Error',
    projectSettingsTitle: 'Project Settings',
    projectSettingsSubtitle:
        'Configure defaults and delivery guardrails for this project workspace.',
    projectSettingsUnavailableLabel: 'Project config is unavailable.',
    projectSettingsRetryAction: 'Retry',
    projectSettingsPoliciesTitle: 'Policies',
    projectSettingsPoliciesSubtitle: 'Safe-write, allowlist, and diff budgets.',
    projectSettingsSafeWriteEnabledLabel: 'Safe-write policy enabled',
    projectSettingsSafeWriteRootsLabel: 'Safe-write roots (one path per line)',
    projectSettingsDiffMaxFilesLabel: 'Diff max files',
    projectSettingsDiffMaxAdditionsLabel: 'Diff max additions',
    projectSettingsDiffMaxDeletionsLabel: 'Diff max deletions',
    projectSettingsShellAllowlistProfileLabel: 'Shell allowlist profile',
    projectSettingsShellAllowlistProfileMinimal: 'Minimal',
    projectSettingsShellAllowlistProfileStandard: 'Standard',
    projectSettingsShellAllowlistProfileExtended: 'Extended',
    projectSettingsShellAllowlistProfileCustom: 'Custom',
    projectSettingsShellAllowlistCustomLabel:
        'Shell allowlist (one command per line)',
    projectSettingsShellAllowlistPreviewLabel:
        'Shell allowlist (profile preview)',
    projectSettingsGitTitle: 'Git Settings',
    projectSettingsGitSubtitle: 'Branch names and delivery stash behavior.',
    projectSettingsGitBaseBranchLabel: 'Base branch',
    projectSettingsGitFeaturePrefixLabel: 'Feature branch prefix',
    projectSettingsGitAutoStashLabel: 'Auto-stash when repo is dirty',
    projectSettingsGitAutoStashSubtitle:
        'Stash local changes automatically before running delivery actions.',
    projectSettingsAutopilotBasicsTitle: 'Autopilot Basics',
    projectSettingsAutopilotBasicsSubtitle:
        'Core limits for the unattended loop.',
    projectSettingsAutopilotMinOpenTasksLabel: 'Min open tasks',
    projectSettingsAutopilotMaxPlanAddLabel: 'Max plan add',
    projectSettingsAutopilotMaxStepsLabel: 'Max steps (optional)',
    projectSettingsAutopilotMaxFailuresLabel: 'Max failures',
    projectSettingsAutopilotMaxRetriesLabel: 'Max task retries',
    projectSettingsAutopilotNoProgressThresholdLabel: 'No-progress threshold',
    projectSettingsAutopilotTimingTitle: 'Autopilot Timing',
    projectSettingsAutopilotTimingSubtitle:
        'Sleep, cooldown, and lock TTL in seconds.',
    projectSettingsAutopilotStepSleepLabel: 'Step sleep (s)',
    projectSettingsAutopilotIdleSleepLabel: 'Idle sleep (s)',
    projectSettingsAutopilotLockTtlLabel: 'Lock TTL (s)',
    projectSettingsAutopilotStuckCooldownLabel: 'Stuck cooldown (s)',
    projectSettingsAutopilotSelfRestartLabel: 'Self-restart when stuck',
    projectSettingsAutopilotSelfRestartSubtitle:
        'Automatically restart the autopilot after stuck detection.',
    projectSettingsAutopilotSafetyTitle: 'Autopilot Safety',
    projectSettingsAutopilotSafetySubtitle:
        'Scope and approval budgets per run.',
    projectSettingsAutopilotScopeMaxFilesLabel: 'Scope max files',
    projectSettingsAutopilotApproveBudgetLabel: 'Approve budget',
    projectSettingsAutopilotScopeMaxAdditionsLabel: 'Scope max additions',
    projectSettingsAutopilotScopeMaxDeletionsLabel: 'Scope max deletions',
    projectSettingsAutopilotManualOverrideLabel: 'Manual override',
    projectSettingsAutopilotManualOverrideSubtitle:
        'Ignore scope and approval budgets until disabled.',
    projectSettingsAutopilotOvernightLabel: 'Overnight unattended enabled',
    projectSettingsAutopilotOvernightSubtitle:
        'Allows unlimited unattended autopilot runs.',
    projectSettingsAutopilotSelfTuneTitle: 'Autopilot Self-Tune',
    projectSettingsAutopilotSelfTuneSubtitle:
        'Adaptive tuning based on success rate.',
    projectSettingsAutopilotSelfTuneEnabledLabel: 'Self-tune enabled',
    projectSettingsAutopilotSelfTuneEnabledSubtitle:
        'Adjust sleep, planning, and retries automatically.',
    projectSettingsAutopilotSelfTuneWindowLabel: 'Self-tune window',
    projectSettingsAutopilotSelfTuneMinSamplesLabel: 'Min samples',
    projectSettingsAutopilotSelfTuneSuccessLabel: 'Target success %',
    projectSettingsAutopilotSelectionTitle: 'Autopilot Selection',
    projectSettingsAutopilotSelectionSubtitle: 'Scheduling mode and weights.',
    projectSettingsAutopilotSelectionModeLabel: 'Selection mode',
    projectSettingsAutopilotSelectionModeFair: 'Fair',
    projectSettingsAutopilotSelectionModePriority: 'Priority',
    projectSettingsAutopilotFairnessWindowLabel: 'Fairness window',
    projectSettingsAutopilotWeightP1Label: 'Weight P1',
    projectSettingsAutopilotWeightP2Label: 'Weight P2',
    projectSettingsAutopilotWeightP3Label: 'Weight P3',
    projectSettingsAutopilotReactivateBlocked: 'Reactivate blocked tasks',
    projectSettingsAutopilotBlockedCooldownLabel: 'Blocked cooldown (s)',
    projectSettingsAutopilotReactivateFailed: 'Reactivate failed tasks',
    projectSettingsAutopilotFailedCooldownLabel: 'Failed cooldown (s)',
    projectSettingsSaveAction: 'Save Project Settings',
    agentCodexLabel: 'Codex',
    agentGeminiLabel: 'Gemini',
    agentReviewerLabel: 'Reviewer',
    hubSearchPlaceholder: 'Search projects...',
    hubNavProjects: 'Projects',
    hubNavChat: 'Chat',
    hubChatTitle: 'Genaisys Chat',
    hubNavSettings: 'Settings',
    hubNavLearn: 'Learn',
    hubNewActionShort: 'New',
    hubOpenActionShort: 'Open',
    hubCloneRepositoryAction: 'Clone Repository',
    hubOpenExistingProjectAction: 'Open Project',
    hubLearnPlaceholder: 'Learn section coming soon.',
    hubSettingsPlaceholder: 'Hub settings coming soon.',
    hubCloneUrlLabel: 'Repository URL',
    hubCloneUrlHint: 'https://github.com/user/repo.git',
    hubCloneTargetLabel: 'Target Directory',
    hubCloneTargetHint: '/Users/name/Workspaces',
    hubCloneAction: 'Clone',
    hubLastOpenedPrefix: 'Last Opened:',
    navLabels: <String>[
      'Chat',
      'Autopilot',
      'Backlog',
      'Dashboard',
      'Reports',
      'Project Settings',
    ],
    statCards: <DesktopStatCopy>[
      DesktopStatCopy(title: 'Revenue', value: 'EUR 184,200', delta: '+14.2%'),
      DesktopStatCopy(title: 'Users', value: '24,831', delta: '+8.1%'),
      DesktopStatCopy(title: 'Performance', value: '99.96%', delta: '+0.7%'),
    ],
    activities: <DesktopActivityCopy>[
      DesktopActivityCopy(
        avatar: 'AL',
        title: 'Alice L.',
        subtitle: 'Review completed - Payment refactor',
      ),
      DesktopActivityCopy(
        avatar: 'MK',
        title: 'Max K.',
        subtitle: 'Release candidate created',
      ),
      DesktopActivityCopy(
        avatar: 'SJ',
        title: 'Sara J.',
        subtitle: 'UI audit comments integrated',
      ),
      DesktopActivityCopy(
        avatar: 'DT',
        title: 'David T.',
        subtitle: 'Policy tests green',
      ),
      DesktopActivityCopy(
        avatar: 'NB',
        title: 'Nina B.',
        subtitle: 'Performance benchmarks updated',
      ),
    ],
    timelineEntries: <String>[
      '09:40 Deployment prepared',
      '10:12 Review approved',
      '10:31 Release tag created',
    ],
    quickFilterLabels: <String>['Silver Tier', 'Gold Accounts', 'Bronze Queue'],
  );
}
