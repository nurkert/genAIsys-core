[Home](../README.md) > [Reference](./README.md) > Run Log Schema

# Run Log Schema

Complete schema for `.genaisys/RUN_LOG.jsonl` -- the append-only event log that records every reliability-critical action taken by the [orchestrator](../glossary.md#orchestrator).

---

## Overview

RUN_LOG.jsonl is a newline-delimited JSON ([JSONL](../glossary.md#run-log)) file stored at `.genaisys/RUN_LOG.jsonl`. Every [orchestrator](../glossary.md#orchestrator) action -- step execution, review decisions, preflight checks, error recovery, lock operations -- emits a structured event to this log. It is the primary diagnostic artifact for understanding what happened during an [autopilot](../glossary.md#autopilot) run.

Key properties:

- **Append-only** -- events are never modified or deleted from the active log file.
- **Redacted** -- all events pass through `RedactionService` before persistence; secrets and tokens are replaced with `[REDACTED]` markers.
- **Sequenced** -- each event receives a monotonically increasing `event_id` that survives process restarts by seeding from the last event in the file.
- **Correlated** -- events carry `correlation` and `correlation_id` fields linking them to their task, subtask, step, and attempt.
- **Runtime-only** -- excluded from git via `.genaisys/.gitignore`.

Source: `lib/core/storage/run_log_store.dart`

---

## Common Event Fields

Every event in RUN_LOG.jsonl shares this envelope:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestamp` | `string` | Yes | ISO 8601 UTC timestamp (`2026-02-21T14:30:00.000Z`) |
| `event_id` | `string` | Yes | Unique ID: `evt-<microseconds>-<sequence>` |
| `correlation_id` | `string` | Yes | Derived from correlation fields or falls back to `event_id` |
| `event` | `string` | Yes | Machine-readable event type (see catalog below) |
| `message` | `string` | No | Human-readable description |
| `correlation` | `object` | No | Links to parent entities (see below) |
| `data` | `object` | No | Event-specific payload |
| `redaction` | `object` | No | Present only if secrets were redacted from this event |

### Correlation Object

When present, `correlation` contains one or more of these keys:

| Key | Description |
|-----|-------------|
| `task_id` | Active task identifier |
| `subtask_id` | Current subtask identifier |
| `step_id` | Orchestrator step identifier |
| `attempt_id` | Coding attempt identifier |
| `review_id` | Review cycle identifier |

The `correlation_id` is built by joining available correlation keys in priority order: `step_id`, `attempt_id`, `review_id`, `task_id`, `subtask_id` -- formatted as `step_id:abc|task_id:xyz`.

### Redaction Metadata

When sensitive content is detected and replaced, the `redaction` object contains:

| Key | Type | Description |
|-----|------|-------------|
| `applied` | `bool` | Always `true` when present |
| `replacement_count` | `int` | Number of replacements made |
| `types` | `List<string>` | Categories of redacted content (e.g., `api_key`, `token`) |

---

## Event Type Catalog

Events are organized by lifecycle phase. The `event` field contains the machine-readable event name.

### Initialization

| Event | Description |
|-------|-------------|
| `init` | Project initialized via `genaisys init` |
| `detected_project_type` | Language/framework auto-detected |
| `config_updated` | Configuration changed |
| `config_hot_reload` | Config reloaded during autopilot run |
| `config_hot_reload_failed` | Config reload failed |
| `config_load_failed` | Config file could not be parsed |

### Task Management

| Event | Description |
|-------|-------------|
| `activate_task` | Task activated from backlog |
| `activate_skip_already_done` | Task skipped -- already completed in log |
| `activate_task_policy_blocked` | Task activation blocked by policy |
| `activate_meta_commit_failed` | Meta-commit during activation failed |
| `activate_auto_stash_recovery` | Stash recovery during activation |
| `activate_checkout_force_recovery` | Forced checkout recovery during activation |
| `deactivate_task` | Task deactivated |
| `task_created` | New task added to backlog |
| `task_priority_updated` | Task priority changed |
| `task_section_moved` | Task moved between sections |
| `task_deleted` | Task removed from backlog |
| `task_done` | Task marked as completed |
| `task_already_done` | Task was already completed |
| `task_blocked` | Task blocked from further progress |
| `task_dead_letter` | Task sent to dead-letter queue |

### Planning & Specs

| Event | Description |
|-------|-------------|
| `spec_init` | Spec file initialized |
| `plan_init` | Plan file initialized |
| `subtasks_init` | Subtasks file initialized |
| `spec_generation_start` | AI spec generation started |
| `spec_generated` | AI spec generation completed |
| `plan_generation_start` | AI plan generation started |
| `plan_generated` | AI plan generation completed |
| `subtasks_generation_start` | AI subtask generation started |
| `subtasks_generated` | AI subtask generation completed |
| `subtasks_queue_empty` | No subtasks available |
| `subtasks_queue_updated` | Subtask queue changed |
| `architecture_planning_started` | Architecture planning phase began |
| `architecture_planning_completed` | Architecture planning phase ended |
| `architecture_planning_empty` | Architecture planning produced no output |
| `vision_evaluation_started` | Vision alignment evaluation began |
| `vision_gap_tasks_planned` | Tasks created from vision gap analysis |
| `initial_backlog_generated` | Initial task backlog generated |
| `meta_tasks_generated` | Meta-tasks generated |

### Sprint Planning

| Event | Description |
|-------|-------------|
| `sprint_planning_started` | Sprint planner invoked to generate the next sprint backlog |
| `sprint_planning_complete` | Sprint planner completed; new tasks added to backlog |
| `sprint_max_reached` | `max_sprints` limit reached; autopilot terminates after current sprint |
| `sprint_vision_fulfilled` | Sprint planner determined the project vision is fulfilled; no more work |

### Step Execution

| Event | Description |
|-------|-------------|
| `orchestrator_run_start` | Autopilot run started |
| `orchestrator_run_end` | Autopilot run ended |
| `orchestrator_run_step_start` | Individual step began |
| `orchestrator_run_step` | Step completed (success or issue) |
| `orchestrator_step` | Step-level outcome recorded |
| `orchestrator_step_planned` | Step planning completed |
| `orchestrator_step_idle` | Step found no work to do |
| `task_cycle_start` | Task cycle began |
| `task_cycle_end` | Task cycle completed |
| `cycle` | Generic cycle marker |
| `coding_attempt` | Coding agent invoked |

### Agent Execution

| Event | Description |
|-------|-------------|
| `agent_command` | Agent command recorded |
| `agent_command_start` | Agent process launched |
| `agent_command_heartbeat` | Agent process liveness heartbeat |
| `agent_command_policy_violation` | Agent attempted disallowed action |

### Provider Pool

| Event | Description |
|-------|-------------|
| `unattended_provider_blocked` | Provider blocked due to failures |
| `unattended_provider_failure_increment` | Provider failure counter incremented |
| `unattended_provider_skipped` | Provider skipped (blocked/cooldown) |
| `unattended_provider_unblocked` | Provider removed from blocklist |
| `unattended_provider_exhausted` | All providers exhausted |
| `provider_pool_quota_hit` | Provider hit rate limit |
| `provider_pool_quota_skip` | Provider skipped due to quota |
| `provider_pool_rotated` | Provider pool rotated to next entry |
| `provider_pool_exhausted` | Entire provider pool exhausted |
| `provider_pool_entry_unresolved` | Provider could not be resolved |

### Review & Quality

| Event | Description |
|-------|-------------|
| `review_approve` | Review approved (via `review_$decision` pattern) |
| `review_reject` | Review rejected |
| `review_cleared` | Review status cleared |
| `review_decision_no_active_task` | Review attempted with no active task |
| `review_reject_autostash` | Rejected changes auto-stashed |
| `review_reject_autostash_failed` | Auto-stash after rejection failed |
| `review_reject_discard_failed` | Discard after rejection failed |
| `review_malformed_response` | Review agent returned unparseable response |
| `review_evidence_weak` | Review evidence below threshold |
| `review_contract_lock` | Review contract lock applied |
| `review_advisory_followup_created` | Advisory follow-up task created from review |
| `quality_gate_start` | Quality gate evaluation started |
| `quality_gate_pass` | All quality gate checks passed |
| `quality_gate_fail` | Quality gate check failed |
| `quality_gate_reject` | Quality gate rejected the diff |
| `quality_gate_skip` | Quality gate skipped (configuration) |
| `quality_gate_blocked` | Quality gate blocked by allowlist |
| `quality_gate_command_start` | Individual QG command started |
| `quality_gate_command_end` | Individual QG command completed |
| `quality_gate_command_retry` | QG command retried |
| `quality_gate_command_no_tests` | QG command found no tests |
| `quality_gate_budget_exhausted` | QG time/retry budget consumed |
| `quality_gate_autofix_start` | Auto-fix attempt started |
| `quality_gate_autofix_pass` | Auto-fix succeeded |
| `quality_gate_autofix_fail` | Auto-fix failed |
| `quality_gate_autofix_skip` | Auto-fix skipped |
| `quality_gate_dependency_bootstrap_start` | Dependency bootstrap started |
| `quality_gate_dependency_bootstrap_pass` | Dependency bootstrap succeeded |
| `quality_gate_dependency_bootstrap_error` | Dependency bootstrap failed |

### Delivery & Git

| Event | Description |
|-------|-------------|
| `merge_completed` | Branch merge succeeded |
| `merge_failed` | Branch merge failed |
| `merge_skipped` | Merge skipped (not on task branch or auto_merge disabled) |
| `push_failed` | Git push failed |
| `git_delivery_fetch` | Delivery preflight: fetch succeeded |
| `git_delivery_fetch_failed` | Delivery preflight: fetch failed |
| `git_delivery_pull` | Delivery preflight: pull succeeded |
| `git_delivery_pull_failed` | Delivery preflight: pull failed |
| `git_delivery_branch_deleted` | Task branch deleted after merge |
| `git_delivery_branch_delete_failed` | Branch deletion failed |
| `git_delivery_remote_branch_deleted` | Remote branch deleted |
| `git_delivery_remote_branch_delete_failed` | Remote branch deletion failed |
| `git_delivery_remote_branch_delete_skipped` | Remote branch deletion skipped |
| `delivery_preflight_passed` | Delivery preflight checks passed |
| `delivery_preflight_failed` | Delivery preflight checks failed |
| `delivery_preflight_skipped` | Delivery preflight skipped |
| `delivery_preflight_no_remote_warning` | No remote configured |
| `delivery_preflight_upstream_skipped` | Upstream check skipped |
| `diff_budget_commit_check_skipped` | Diff budget check skipped |
| `consecutive_push_failures_blocked` | Push blocked after consecutive failures |
| `task_cycle_delivery_resume_start` | Interrupted delivery resumed |
| `task_cycle_delivery_resume_end` | Delivery resume completed |
| `git_branch_cleanup` | Stale branches cleaned up |

### Merge Conflicts

| Event | Description |
|-------|-------------|
| `merge_conflict_detected` | Merge conflict detected |
| `merge_conflict_resolved` | Merge conflict auto-resolved |
| `merge_conflict_resolution_attempt_start` | Resolution attempt started |
| `merge_conflict_resolution_attempt_failed` | Resolution attempt failed |
| `merge_conflict_resolution_attempt_unresolved` | Resolution could not resolve all conflicts |
| `merge_conflict_abort` | Merge aborted |
| `merge_conflict_abort_failed` | Merge abort failed |
| `merge_conflict_manual` | Manual conflict resolution required |

### Release Tags

| Event | Description |
|-------|-------------|
| `release_tag_created` | Release tag created |
| `release_tag_pushed` | Release tag pushed to remote |
| `release_tag_skip` | Release tag skipped (various reasons) |
| `release_tag_failed` | Release tag creation failed |
| `release_tag_push_skip` | Tag push skipped |
| `release_candidate_built` | Release candidate assembled |
| `release_candidate_promoted` | Release candidate promoted to stable |
| `release_candidate_promotion_blocked` | Promotion blocked |

### Orchestrator Run Control

| Event | Description |
|-------|-------------|
| `orchestrator_run_safety_halt` | Run halted for safety reasons |
| `orchestrator_run_stop_requested` | Stop signal received |
| `orchestrator_run_stuck` | Run loop detected as stuck |
| `orchestrator_run_self_restart` | Run loop self-restarted |
| `orchestrator_run_unattended_blocked` | Unattended mode blocked |
| `wallclock_timeout` | Wall-clock time limit reached |
| `orchestrator_run_step_outcome` | Step outcome finalized (success, no_diff, or rejected) |
| `orchestrator_run_stopped` | Autopilot run stopped cleanly (stop signal processed) |

### Human-in-the-Loop (HITL) Gates

| Event | Description |
|-------|-------------|
| `hitl_gate_opened` | HITL gate opened; autopilot suspended pending human decision |
| `hitl_gate_resolved` | HITL gate resolved — human submitted approve or reject decision |
| `hitl_gate_timeout` | HITL gate timed out; decision auto-approved per `hitl.timeout_minutes` |

### Error Handling

| Event | Description |
|-------|-------------|
| `orchestrator_run_error` | Generic run error |
| `orchestrator_run_transient_error` | Transient error (will retry) |
| `orchestrator_run_permanent_error` | Permanent error (will not retry) |
| `orchestrator_run_provider_pause` | Provider paused due to quota/error |
| `orchestrator_run_policy_violation` | Policy violation detected |
| `orchestrator_run_progress_failure` | Progress failure (no_diff, reject) |
| `task_cycle_no_diff` | Coding agent produced no diff |
| `policy_error` | Policy evaluation error |
| `policy_violation_rollback` | Policy violation rolled back |
| `policy_rollback_failed` | Rollback after violation failed |
| `policy_rollback_incomplete` | Partial rollback |
| `policy_rollback_escalation_failed` | Escalated rollback failed |
| `architecture_gate_reject` | Architecture gate rejected changes |
| `architecture_gate_discard_failed` | Architecture discard failed |
| `review_agent_crash` | Review agent process crashed |
| `reject_cleanup_failed` | Both stash and discard failed during review-reject cleanup; `StateError` thrown |

### Git State Management

| Event | Description |
|-------|-------------|
| `git_auto_stash` | Auto-stash created before step |
| `git_auto_stash_restore` | Auto-stash restored after step |
| `git_auto_stash_restore_failed` | Stash restore failed |
| `git_auto_stash_skip_rejected` | Stash skipped for rejected context |
| `git_auto_stash_rejected_context` | Rejected context stashed |
| `git_step_error_autostash` | Error-path stash created |
| `git_step_error_autostash_incomplete` | Error-path stash incomplete |
| `git_forensic_stash_created` | Forensic stash created for diagnosis |
| `git_auto_stash_restore_recovery` | Stash restore recovery attempted |
| `git_auto_stash_restore_recovery_failed` | Stash restore recovery failed |
| `git_sync_between_loops` | Git sync between loop iterations |
| `stash_rotation_failed` | Stash rotation failed |
| `exit_checkout_base` | Checkout to base branch on exit |
| `exit_checkout_skipped` | Exit checkout skipped |
| `exit_checkout_failed` | Exit checkout failed |

### Locking

| Event | Description |
|-------|-------------|
| `orchestrator_run_lock_recovered` | Lock recovered from dead process |
| `orchestrator_run_unlock` | Lock released |
| `lock_corrupt_recovery` | Corrupted lock file recovered |
| `stale_stop_signal` | Stale stop signal file cleaned up |
| `lock_heartbeat_failure_warning` | Lock heartbeat failed 3+ consecutive times; reliability warning emitted |

### Supervisor

| Event | Description |
|-------|-------------|
| `autopilot_supervisor_start` | Supervisor started |
| `autopilot_supervisor_stop` | Supervisor stopped |
| `autopilot_supervisor_halt` | Supervisor halted (various reasons) |
| `autopilot_supervisor_worker_start` | Worker process launched |
| `autopilot_supervisor_worker_end` | Worker process completed |
| `autopilot_supervisor_worker_skip` | Worker launch skipped |
| `autopilot_supervisor_start_blocked` | Supervisor start blocked |
| `autopilot_supervisor_preflight_failed` | Supervisor preflight failed |
| `autopilot_supervisor_segment_error` | Supervisor segment error |
| `autopilot_supervisor_restart` | Supervisor restarted worker |
| `autopilot_supervisor_auto_heal` | Auto-heal invoked |
| `autopilot_supervisor_resume` | Supervisor resumed |
| `autopilot_supervisor_resume_failed` | Supervisor resume failed |
| `autopilot_supervisor_stale_recovered` | Stale supervisor lock recovered |
| `supervisor_reflection_on_halt` | Reflection triggered on halt |
| `supervisor_reflection_failed` | Supervisor reflection failed |

### Self-Healing & Recovery

| Event | Description |
|-------|-------------|
| `orchestrator_run_self_heal_attempt` | Self-heal attempt started |
| `orchestrator_run_self_heal_failed` | Self-heal attempt failed |
| `auto_heal_repair_failed` | Auto-heal repair failed |
| `incident_heal_start` | Incident heal use case started |
| `incident_heal_end` | Incident heal use case completed |
| `state_repair` | State repair executed |
| `orphaned_subtask_removed` | Orphaned subtask cleaned up |
| `active_task_stale_cleared` | Stale active task cleared |
| `cleared_orphaned_review_status` | Orphaned review status cleared |
| `cleared_stale_workflow_stage` | Stale workflow stage reset |
| `cleared_expired_cooldowns` | Expired cooldowns removed |

### Forensic Recovery

| Event | Description |
|-------|-------------|
| `forensic_diagnosis` | Forensic diagnosis completed |
| `forensic_recovery_attempt` | Forensic recovery attempted |
| `forensic_recovery_exhausted` | Recovery retries exhausted |
| `forensic_skip_already_completed` | Recovery skipped -- task already done |
| `forensic_recovery_state_write_failed` | Recovery state write failed |
| `forensic_retry_guidance_skipped_unattended` | Guidance skipped in unattended mode |
| `task_cycle_stale_active_task_recovered` | Stale active task recovered in cycle |

### Progress Tracking

| Event | Description |
|-------|-------------|
| `orchestrator_run_progress_failure_release` | Progress failure counter released |
| `orchestrator_run_progress_failure_release_failed` | Counter release failed |
| `orchestrator_run_task_blocked_continue` | Blocked task, continuing to next |
| `orchestrator_run_task_block_failed` | Task block operation failed |
| `subtask_scheduler_selection` | Subtask selected by scheduler |
| `subtask_scheduler_demote_verification` | Verification subtask demoted |
| `subtask_spec_not_found` | Subtask spec file missing |
| `subtask_queue_overflow` | Subtask queue exceeded limit |
| `subtask_requeued_after_timeout` | Subtask requeued after timeout |
| `subtask_auto_refined_long_run` | Subtask refined after long run |
| `subtask_auto_refine_skipped` | Subtask refinement skipped |
| `retry_key_fallback` | Retry key computed with fallback |

### Preflight

| Event | Description |
|-------|-------------|
| `preflight_failed` | Preflight check failed |
| `preflight_crash` | Preflight check threw exception |
| `preflight_repair_triggered` | Preflight triggered state repair |

### Audit & Observability

| Event | Description |
|-------|-------------|
| `audit_recorded` | Audit trail bundle captured |
| `audit_failed` | Audit trail capture failed |
| `audit_diff_bundle_failed` | Review bundle build failed during audit |
| `audit_completed` | Audit agent completed |
| `orchestrator_run_planning_audit` | Planning audit recorded |
| `orchestrator_run_planning_audit_failed` | Planning audit failed |
| `code_health_evaluation` | Code health evaluation completed |
| `code_health_evaluation_failed` | Code health evaluation failed |
| `trend_analysis` | Trend analysis completed |
| `retrospective_analysis` | Retrospective analysis recorded |
| `prompt_effectiveness_analysis` | Prompt effectiveness evaluated |
| `run_log_insight_analysis` | Run log insight analysis completed |
| `readiness_gate_evaluation` | Readiness gate evaluated |
| `planning_audit_cadence` | Planning audit cadence check |

### Reflection & Self-Improvement

| Event | Description |
|-------|-------------|
| `reflection_triggered` | Productivity reflection triggered |
| `reflection_skipped` | Reflection skipped |
| `reflection_complete` | Reflection completed |
| `reflection_failed` | Reflection failed |
| `self_improve_start` | Self-improvement cycle started |
| `self_improve_complete` | Self-improvement cycle completed |
| `self_tune_applied` | Self-tuning adjustment applied |
| `self_tune_reasoning_effort` | Reasoning effort auto-tuned |
| `self_tune_skipped` | Self-tuning skipped |
| `insight_driven_tasks` | Tasks created from insights |
| `strategic_planning_suggestions` | Strategic planning suggestions generated |
| `vision_drift_detected` | Vision drift detected |

### Task Lifecycle Helpers

| Event | Description |
|-------|-------------|
| `done_evidence_warning` | Evidence warning during done |
| `done_force_skip_evidence` | Evidence check force-skipped |
| `done_state_discard_fallback` | Done state cleanup fell back to discard |
| `done_state_cleanup_commit_failed` | Done cleanup commit failed |
| `block_state_discard_fallback` | Block state cleanup fell back to discard |
| `block_state_cleanup_commit_failed` | Block cleanup commit failed |
| `task_block_context_stashed` | Blocked task context stashed |
| `task_block_context_stash_failed` | Block context stash failed |
| `task_block_meta_commit` | Block meta-commit created |
| `task_block_meta_commit_failed` | Block meta-commit failed |
| `persist_step_cleanup_failed` | Post-step cleanup persistence failed |

### Miscellaneous

| Event | Description |
|-------|-------------|
| `resource_warning` | System resource warning (e.g., low disk) |
| `canary_validation_passed` | Canary validation passed |
| `canary_validation_failed` | Canary validation failed |
| `canary_validation_cycle` | Canary validation cycle recorded |
| `policy_simulation` | Policy simulation completed |
| `eval_run_start` | Eval harness run started |
| `eval_run_complete` | Eval harness run completed |
| `runtime_switch_start` | Runtime switch initiated |
| `runtime_switch_complete` | Runtime switch completed |
| `runtime_rollback` | Runtime switch rolled back |
| `spec_required_files_disk_fallback` | Spec required files fell back to disk |
| `workflow_transition` | Workflow stage transition |
| `draft_spec_skipped` | Draft spec generation skipped |
| `draft_spec_generated` | Draft spec generated |
| `draft_plan_skipped` | Draft plan generation skipped |
| `draft_plan_generated` | Draft plan generated |
| `draft_subtasks_skipped` | Draft subtasks generation skipped |
| `draft_subtasks_generated` | Draft subtasks generated |

---

## Error Classification

Events carrying error information include `error_class` and `error_kind` fields in their `data` object. These provide machine-readable failure categorization used for retry logic, blocking decisions, and trend analysis.

Source: `lib/core/errors/failure_reason_mapper.dart`

### Error Classes

| Class | Description | Typical Events |
|-------|-------------|----------------|
| `activation` | Task activation failures | `activate_auto_stash_recovery`, `activate_checkout_force_recovery` |
| `architecture` | Architecture gate violations | `architecture_gate_reject` |
| `audit` | Audit trail failures | `audit_diff_bundle_failed` |
| `code_health` | Code health evaluation errors | `code_health_evaluation_failed` |
| `config` | Configuration parse/load errors | `config_load_failed`, `config_hot_reload_failed` |
| `delivery` | Git delivery failures | `push_failed`, `merge_failed`, `delivery_preflight_failed` |
| `git` | Low-level git errors | `merge_failed`, `stash_rotation_failed` |
| `hitl` | Human-in-the-Loop gate events | `hitl_gate_opened`, `hitl_gate_resolved`, `hitl_gate_timeout` |
| `locking` | Lock contention/recovery | `orchestrator_run_lock_recovered`, `lock_corrupt_recovery` |
| `pipeline` | Orchestration flow errors | `orchestrator_run_stuck`, `wallclock_timeout` |
| `planning` | Planning phase errors | `architecture_planning_empty` |
| `policy` | Policy violations | `agent_command_policy_violation`, `policy_violation_rollback` |
| `preflight` | Preflight check failures | `preflight_failed`, `preflight_crash` |
| `process` | Agent process crashes/signals | (signal-based exits: SIGKILL, SIGSEGV, etc.) |
| `provider` | Provider quota/availability | `orchestrator_run_provider_pause`, `provider_pool_exhausted` |
| `quality_gate` | Test/analyze failures | `quality_gate_fail`, `quality_gate_reject` |
| `resource` | System resource constraints | `resource_warning` |
| `review` | Review decision failures | `review_reject`, `review_malformed_response` |
| `scheduler` | Subtask scheduling errors | `subtask_spec_not_found` |
| `state` | State corruption/write errors | `orchestrator_run_planning_audit_failed` |
| `state_repair` | State repair operations | `state_repair`, `orphaned_subtask_removed` |
| `transient` | Transient provider errors | `unattended_provider_failure_increment` |

### Error Kinds

Error kinds provide specific failure reasons within a class. Examples:

| Kind | Class | Description |
|------|-------|-------------|
| `no_diff` | `review` | Coding agent produced no changes |
| `review_rejected` | `review` | Review agent rejected the diff |
| `quality_gate_failed` | `quality_gate` | Tests or analysis failed |
| `analyze_failed` | `quality_gate` | Static analysis failed |
| `test_failed` | `quality_gate` | Test suite failed |
| `provider_quota` | `provider` | Provider rate limit hit |
| `agent_unavailable` | `provider` | Agent CLI not found (exit 126/127) |
| `timeout` | `pipeline` | Operation timed out |
| `stuck` | `pipeline` | Orchestrator detected stuck state |
| `approve_budget` | `pipeline` | Approve budget exhausted |
| `scope_budget` | `pipeline` | Scope budget exhausted |
| `preflight_failed` | `preflight` | Preflight check failed |
| `lock_held` | `locking` | Lock already held by live process |
| `lock_recovered` | `locking` | Lock recovered from dead process |
| `policy_violation` | `policy` | Policy violation detected |
| `safe_write_scope` | `policy` | Safe-write scope violation |
| `diff_budget` | `policy` | Diff budget exceeded |
| `git_dirty` | `delivery` | Uncommitted changes in worktree |
| `merge_conflict` | `delivery` | Merge conflict encountered |
| `push_failed` | `delivery` | Git push failed |
| `agent_crash_abort` | `process` | Agent crashed (SIGABRT) |
| `agent_killed` | `process` | Agent killed (SIGKILL) |
| `agent_crash_segv` | `process` | Agent segfault (SIGSEGV) |
| `max_iterations_safety_limit` | `pipeline` | Safety iteration limit reached |
| `wallclock_timeout` | `pipeline` | Wall-clock timeout |
| `dead_letter` | `pipeline` | Task moved to dead-letter queue |
| `forensic_recovery_exhausted` | `pipeline` | Forensic recovery retries consumed |
| `orphaned_subtask` | `state_repair` | Orphaned subtask found and removed |
| `orphaned_review` | `state_repair` | Orphaned review status cleared |
| `hitl_timeout` | `hitl` | HITL gate timed out; gate was auto-approved |
| `hitl_rejected` | `hitl` | Human explicitly rejected the HITL gate |
| `sprint_max_reached` | `pipeline` | Maximum sprint count was reached |
| `reject_cleanup_failed` | `delivery` | Stash and discard both failed during reject cleanup |

---

## Log Rotation

When the active log file exceeds the size threshold, it is rotated to an archive directory before the new event is written.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `maxBytes` | 2 MB | Maximum file size before rotation |
| `maxArchives` | 8 | Maximum archived log files retained |
| Archive directory | `.genaisys/logs/run_log_archive/` | Location of rotated logs |

**Rotation behavior:**

1. Before appending, check if `currentSize + newEventSize > maxBytes`.
2. If exceeded, rename the active file to `RUN_LOG-<ISO8601_timestamp>.jsonl` in the archive directory.
3. Prune archives exceeding `maxArchives` (oldest first by modification time).
4. A fresh `RUN_LOG.jsonl` is created implicitly by the next append.

Rotation is best-effort -- if it fails, the event is still appended to the current file.

Source: `lib/core/storage/run_log_store.dart`, lines 226-314

---

## Example Events

### Step Start

```json
{
  "timestamp": "2026-02-21T10:00:00.000000Z",
  "event_id": "evt-1740132000000000-1",
  "correlation_id": "step_id:step-001|task_id:task-42",
  "event": "orchestrator_run_step_start",
  "message": "Starting step 1",
  "correlation": {
    "task_id": "task-42",
    "step_id": "step-001"
  },
  "data": {
    "step_id": "step-001",
    "task_id": "task-42",
    "subtask_id": "implement-login"
  }
}
```

### Preflight Failure

```json
{
  "timestamp": "2026-02-21T10:01:00.000000Z",
  "event_id": "evt-1740132060000000-2",
  "correlation_id": "step_id:step-002|task_id:task-42",
  "event": "preflight_failed",
  "message": "Git repo has uncommitted changes",
  "correlation": {
    "task_id": "task-42",
    "step_id": "step-002"
  },
  "data": {
    "step_id": "step-002",
    "task_id": "task-42",
    "error_class": "preflight",
    "error_kind": "git_dirty"
  }
}
```

### Review Decision

```json
{
  "timestamp": "2026-02-21T10:05:00.000000Z",
  "event_id": "evt-1740132300000000-5",
  "correlation_id": "step_id:step-001|task_id:task-42",
  "event": "review_approve",
  "message": "Review approved",
  "correlation": {
    "task_id": "task-42",
    "step_id": "step-001"
  },
  "data": {
    "decision": "approve",
    "task_id": "task-42"
  }
}
```

### Safety Halt with Error Classification

```json
{
  "timestamp": "2026-02-21T10:10:00.000000Z",
  "event_id": "evt-1740132600000000-8",
  "correlation_id": "step_id:step-003|task_id:task-42",
  "event": "orchestrator_run_safety_halt",
  "message": "Halted: max task retries exceeded",
  "correlation": {
    "task_id": "task-42",
    "step_id": "step-003"
  },
  "data": {
    "step_id": "step-003",
    "task_id": "task-42",
    "error_class": "pipeline",
    "error_kind": "max_task_retries",
    "consecutive_failures": 5
  }
}
```

### Lock Recovery

```json
{
  "timestamp": "2026-02-21T10:15:00.000000Z",
  "event_id": "evt-1740132900000000-10",
  "correlation_id": "evt-1740132900000000-10",
  "event": "orchestrator_run_lock_recovered",
  "message": "Lock recovered from dead process",
  "data": {
    "error_class": "locking",
    "error_kind": "lock_recovered",
    "recovery_reason": "pid_not_alive",
    "previous_pid": 12345,
    "current_pid": 67890
  }
}
```

### HITL Gate

```json
{
  "timestamp": "2026-03-02T09:00:00.000000Z",
  "event_id": "evt-1740906000000000-12",
  "correlation_id": "step_id:step-007|task_id:task-42",
  "event": "hitl_gate_opened",
  "message": "HITL gate opened: before_sprint",
  "correlation": {
    "task_id": "task-42",
    "step_id": "step-007"
  },
  "data": {
    "event": "before_sprint",
    "task_id": "task-42",
    "sprint_number": 2,
    "error_class": "hitl"
  }
}
```

---

## Related Documentation

- [Troubleshooting](../guide/troubleshooting.md) -- Diagnosing issues using the run log
- [STATE.json Schema](state-json-schema.md) -- Runtime state fields and transitions
- [Data Contracts](data-contracts.md) -- All `.genaisys/` artifacts and schemas
- [Glossary: Run Log](../glossary.md#run-log) -- Term definition
- [Glossary: Audit Trail](../glossary.md#audit-trail) -- Reliability event logging
