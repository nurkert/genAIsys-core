// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../models/workflow_stage.dart';
import 'schema_validator_base.dart';

/// Validates `.genaisys/STATE.json` schema.
class StateSchemaValidator extends SchemaValidatorBase {
  void validate(String path) {
    const artifact = '.genaisys/STATE.json';
    final payload = readRequiredFile(path, artifact: artifact);

    final decoded = decodeJson(payload, artifact: artifact);
    final root = asObjectMap(decoded, artifact: artifact, field: r'$');

    const allowedKeys = {
      'version',
      'active_task_id',
      'active_task_title',
      'cycle_count',
      'last_updated',
      'review_status',
      'review_updated_at',
      'workflow_stage',
      'task_retry_counts',
      'task_cooldown_until',
      'autopilot_running',
      'last_loop_at',
      'consecutive_failures',
      'last_error',
      'last_error_class',
      'last_error_kind',
      'current_mode',
      'supervisor_running',
      'supervisor_session_id',
      'supervisor_pid',
      'supervisor_started_at',
      'supervisor_profile',
      'supervisor_start_reason',
      'supervisor_restart_count',
      'supervisor_cooldown_until',
      'supervisor_last_halt_reason',
      'supervisor_last_resume_action',
      'supervisor_last_exit_code',
      'supervisor_low_signal_streak',
      'supervisor_throughput_window_started_at',
      'supervisor_throughput_steps',
      'supervisor_throughput_rejects',
      'supervisor_throughput_high_retries',
      'subtask_queue',
      'current_subtask',
      'subtask_refinement_done',
      'feasibility_check_done',
      'subtask_split_attempts',
      // Reflection tracking.
      'last_reflection_at',
      'reflection_count',
      'reflection_tasks_created',
      'supervisor_reflection_count',
      'supervisor_last_reflection_at',
      // Forensic recovery tracking.
      'forensic_recovery_attempted',
      'forensic_guidance',
      // Retry key tracking.
      'active_task_retry_key',
      // Advisory note accumulation and diff-delta review (Wave 2).
      'accumulated_advisory_notes',
      'last_reject_commit_sha',
      // Merge-limbo protection (Wave 3).
      'merge_in_progress',
      // Integrity metadata.
      '_checksum',
    };
    assertOnlyAllowedKeys(
      root,
      allowed: allowedKeys,
      artifact: artifact,
      field: r'$',
    );

    requiredString(
      root,
      key: 'last_updated',
      artifact: artifact,
      iso8601: true,
    );
    optionalString(root, key: 'active_task_id', artifact: artifact);
    optionalString(root, key: 'active_task_title', artifact: artifact);
    optionalString(
      root,
      key: 'review_status',
      artifact: artifact,
      allowed: {'approved', 'rejected'},
    );
    optionalString(
      root,
      key: 'review_updated_at',
      artifact: artifact,
      iso8601: true,
    );
    optionalString(
      root,
      key: 'last_loop_at',
      artifact: artifact,
      iso8601: true,
    );
    optionalString(root, key: 'last_error', artifact: artifact);
    optionalMachineToken(root, key: 'last_error_class', artifact: artifact);
    optionalMachineToken(root, key: 'last_error_kind', artifact: artifact);
    optionalString(root, key: 'current_mode', artifact: artifact);
    optionalString(
      root,
      key: 'supervisor_session_id',
      artifact: artifact,
      parent: r'$',
    );
    optionalString(
      root,
      key: 'supervisor_started_at',
      artifact: artifact,
      parent: r'$',
      iso8601: true,
    );
    optionalString(
      root,
      key: 'supervisor_profile',
      artifact: artifact,
      parent: r'$',
      allowed: {'pilot', 'overnight', 'longrun'},
    );
    optionalString(
      root,
      key: 'supervisor_start_reason',
      artifact: artifact,
      parent: r'$',
    );
    optionalString(
      root,
      key: 'supervisor_cooldown_until',
      artifact: artifact,
      parent: r'$',
      iso8601: true,
    );
    optionalString(
      root,
      key: 'supervisor_last_halt_reason',
      artifact: artifact,
      parent: r'$',
    );
    optionalString(
      root,
      key: 'supervisor_last_resume_action',
      artifact: artifact,
      parent: r'$',
    );
    optionalString(root, key: 'current_subtask', artifact: artifact);

    optionalInt(root, key: 'version', artifact: artifact, minimum: 1);
    optionalInt(root, key: 'cycle_count', artifact: artifact, minimum: 0);
    optionalInt(
      root,
      key: 'consecutive_failures',
      artifact: artifact,
      minimum: 0,
    );
    optionalInt(root, key: 'supervisor_pid', artifact: artifact, minimum: 1);
    optionalInt(
      root,
      key: 'supervisor_restart_count',
      artifact: artifact,
      minimum: 0,
    );
    optionalInt(
      root,
      key: 'supervisor_last_exit_code',
      artifact: artifact,
      minimum: 0,
    );
    optionalInt(
      root,
      key: 'supervisor_low_signal_streak',
      artifact: artifact,
      minimum: 0,
    );
    optionalInt(
      root,
      key: 'supervisor_throughput_steps',
      artifact: artifact,
      minimum: 0,
    );
    optionalInt(
      root,
      key: 'supervisor_throughput_rejects',
      artifact: artifact,
      minimum: 0,
    );
    optionalInt(
      root,
      key: 'supervisor_throughput_high_retries',
      artifact: artifact,
      minimum: 0,
    );
    optionalString(
      root,
      key: 'supervisor_throughput_window_started_at',
      artifact: artifact,
      parent: r'$',
      iso8601: true,
    );

    optionalBool(root, key: 'autopilot_running', artifact: artifact);
    optionalBool(root, key: 'supervisor_running', artifact: artifact);
    optionalBool(root, key: 'forensic_recovery_attempted', artifact: artifact);
    optionalString(root, key: 'forensic_guidance', artifact: artifact);
    optionalString(root, key: 'active_task_retry_key', artifact: artifact);

    final workflowStage = root['workflow_stage'];
    if (workflowStage != null) {
      if (workflowStage is! String) {
        throw SchemaValidatorBase.schemaError(
          artifact: artifact,
          field: 'workflow_stage',
          message: 'expected string but found ${workflowStage.runtimeType}.',
        );
      }
      final normalized = workflowStage.trim().toLowerCase();
      final allowed = WorkflowStage.values.map((stage) => stage.name).toSet();
      if (!allowed.contains(normalized)) {
        throw SchemaValidatorBase.schemaError(
          artifact: artifact,
          field: 'workflow_stage',
          message:
              'unsupported value "$workflowStage"; allowed: ${allowed.join(', ')}.',
        );
      }
    }

    final retries = root['task_retry_counts'];
    if (retries != null) {
      final map = asObjectMap(
        retries,
        artifact: artifact,
        field: 'task_retry_counts',
      );
      for (final entry in map.entries) {
        if (entry.key.trim().isEmpty) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'task_retry_counts',
            message: 'keys must not be empty.',
          );
        }
        if (entry.value is! int) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'task_retry_counts.${entry.key}',
            message: 'expected integer but found ${entry.value.runtimeType}.',
          );
        }
        if ((entry.value as int) < 0) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'task_retry_counts.${entry.key}',
            message: 'must be >= 0.',
          );
        }
      }
    }

    final cooldowns = root['task_cooldown_until'];
    if (cooldowns != null) {
      final map = asObjectMap(
        cooldowns,
        artifact: artifact,
        field: 'task_cooldown_until',
      );
      for (final entry in map.entries) {
        if (entry.key.trim().isEmpty) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'task_cooldown_until',
            message: 'keys must not be empty.',
          );
        }
        if (entry.value is! String) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'task_cooldown_until.${entry.key}',
            message:
                'expected ISO-8601 string but found ${entry.value.runtimeType}.',
          );
        }
      }
    }

    final subtasks = root['subtask_queue'];
    if (subtasks != null) {
      final list = asList(
        subtasks,
        artifact: artifact,
        field: 'subtask_queue',
      );
      for (var i = 0; i < list.length; i += 1) {
        final value = list[i];
        if (value is! String || value.trim().isEmpty) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'subtask_queue[$i]',
            message: 'expected non-empty string.',
          );
        }
      }
    }
  }
}
