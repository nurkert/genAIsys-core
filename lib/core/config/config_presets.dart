// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Named config presets that provide sensible defaults for common use-cases.
///
/// Presets are applied as a middle layer between registry defaults and
/// explicit user YAML values:
///
///   1. Registry defaults (from [ConfigFieldDescriptor.defaultValue])
///   2. Preset values (this file)
///   3. Explicit YAML values (always win)
///
/// Usage in `config.yml`:
/// ```yaml
/// preset: overnight
/// autopilot:
///   max_steps: 200   # overrides the preset's 500
/// ```
const Map<String, Map<String, Object>> configPresets = {
  // ---------------------------------------------------------------------------
  // conservative — safety-first, smaller scope, more review rounds
  // ---------------------------------------------------------------------------
  'conservative': {
    'autopilot.max_task_retries': 2,
    'autopilot.max_failures': 3,
    'review.max_rounds': 5,
    'autopilot.scope_max_files': 30,
    'autopilot.scope_max_additions': 3000,
    'pipeline.forensic_recovery_enabled': true,
    'autopilot.self_heal_enabled': true,
    'autopilot.review_contract_lock_enabled': true,
  },

  // ---------------------------------------------------------------------------
  // aggressive — fast iteration, larger scope, fewer review rounds
  // ---------------------------------------------------------------------------
  'aggressive': {
    'autopilot.max_task_retries': 5,
    'autopilot.max_failures': 10,
    'review.max_rounds': 2,
    'autopilot.scope_max_files': 100,
    'autopilot.scope_max_additions': 10000,
    'autopilot.step_sleep_seconds': 0,
    'autopilot.idle_sleep_seconds': 5,
  },

  // ---------------------------------------------------------------------------
  // overnight — long-running unattended execution
  // ---------------------------------------------------------------------------
  'overnight': {
    'autopilot.max_steps': 500,
    'autopilot.max_wallclock_hours': 8,
    'autopilot.overnight_unattended_enabled': true,
    'autopilot.self_restart': true,
    'autopilot.self_heal_enabled': true,
    'autopilot.review_contract_lock_enabled': true,
    'autopilot.reactivate_blocked': true,
    'autopilot.reactivate_failed': true,
    'autopilot.selection_mode': 'strict_priority',
  },
};

/// All valid preset names.
const Set<String> validPresetNames = {'conservative', 'aggressive', 'overnight'};
