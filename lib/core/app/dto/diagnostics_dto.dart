// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

// DTOs for Phase 4 CLI diagnostic handlers.

// ---------------------------------------------------------------------------
// config validate
// ---------------------------------------------------------------------------

class ConfigValidationCheckDto {
  const ConfigValidationCheckDto({
    required this.name,
    required this.ok,
    required this.message,
    this.remediationHint,
  });

  final String name;
  final bool ok;
  final String message;
  final String? remediationHint;
}

class ConfigValidationDto {
  const ConfigValidationDto({
    required this.ok,
    required this.checks,
    required this.warnings,
  });

  final bool ok;
  final List<ConfigValidationCheckDto> checks;
  final List<ConfigValidationCheckDto> warnings;
}

// ---------------------------------------------------------------------------
// health report
// ---------------------------------------------------------------------------

class HealthReportCheckDto {
  const HealthReportCheckDto({
    required this.name,
    required this.ok,
    required this.message,
    this.errorKind,
  });

  final String name;
  final bool ok;
  final String message;
  final String? errorKind;
}

class HealthReportDto {
  const HealthReportDto({required this.ok, required this.checks});

  final bool ok;
  final List<HealthReportCheckDto> checks;
}

// ---------------------------------------------------------------------------
// autopilot dry-run
// ---------------------------------------------------------------------------

class AutopilotDryRunDto {
  const AutopilotDryRunDto({
    required this.preflightOk,
    required this.preflightMessage,
    this.selectedTaskTitle,
    this.selectedTaskId,
    this.subtask,
    required this.specGenerated,
    this.specPreview,
    required this.plannedTasksAdded,
  });

  final bool preflightOk;
  final String preflightMessage;
  final String? selectedTaskTitle;
  final String? selectedTaskId;
  final String? subtask;
  final bool specGenerated;
  final String? specPreview;
  final int plannedTasksAdded;
}

// ---------------------------------------------------------------------------
// autopilot diagnostics
// ---------------------------------------------------------------------------

class ErrorPatternDto {
  const ErrorPatternDto({
    required this.errorKind,
    required this.count,
    required this.lastSeen,
    required this.autoResolvedCount,
    this.resolutionStrategy,
  });

  final String errorKind;
  final int count;
  final String lastSeen;
  final int autoResolvedCount;
  final String? resolutionStrategy;
}

class AutopilotDiagnosticsDto {
  const AutopilotDiagnosticsDto({
    required this.errorPatterns,
    required this.forensicState,
    required this.recentEvents,
    required this.supervisorStatus,
  });

  final List<ErrorPatternDto> errorPatterns;
  final Map<String, Object?> forensicState;
  final List<Map<String, Object?>> recentEvents;
  final Map<String, Object?> supervisorStatus;
}

// ---------------------------------------------------------------------------
// config diff
// ---------------------------------------------------------------------------

class ConfigDiffEntryDto {
  const ConfigDiffEntryDto({
    required this.field,
    required this.currentValue,
    required this.defaultValue,
    required this.effect,
  });

  final String field;
  final String currentValue;
  final String defaultValue;
  final String effect;
}

class ConfigDiffDto {
  const ConfigDiffDto({required this.hasDiff, required this.entries});

  final bool hasDiff;
  final List<ConfigDiffEntryDto> entries;
}
