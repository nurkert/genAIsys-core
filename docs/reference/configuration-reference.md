[Home](../README.md) > [Reference](./README.md) > Configuration Reference

# Configuration Reference

Exhaustive reference for all configuration keys in `.genaisys/config.yml`.

All fields are parsed from the [config field registry](../../lib/core/config/config_field_registry.dart) and validated on every read. Invalid config blocks operation ([fail-closed](../glossary.md#fail-closed)). Duration fields are specified in seconds unless noted otherwise.

---

## Contents

- [Providers](#providers)
- [Git](#git)
- [Workflow](#workflow)
- [Autopilot](#autopilot)
- [Review](#review)
- [Policies](#policies)
  - [Diff Budget](#policiesdiff_budget)
  - [Safe-Write](#policiessafe_write)
  - [Quality Gate](#policiesquality_gate)
  - [Timeouts](#policiestimeouts)
- [Pipeline](#pipeline)
- [Reflection](#reflection)
- [Supervisor](#supervisor)
- [Code Health](#code_health)
- [Vision Evaluation](#vision_evaluation)
- [Non-Registry Fields](#non-registry-fields)
- [Presets](#presets)
- [Related Documentation](#related-documentation)

---

## `providers`

Configuration for AI [provider](../glossary.md#provider) backends and the [provider pool](../glossary.md#provider-pool).

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `providers.quota_cooldown_seconds` | duration | `900` | >= 0 | Seconds to wait after a [provider](../glossary.md#provider) exhausts its API [quota](../glossary.md#quota-cooldown) before retrying. |
| `providers.quota_pause_seconds` | duration | `300` | >= 0 | Seconds to pause before falling back to the next provider in the [pool](../glossary.md#provider-pool) after a quota event. |

The following provider keys are parsed by specialized parsers (not the scalar registry):

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `providers.primary` | string | _(none)_ | Primary [provider](../glossary.md#provider) name (`claude-code`, `gemini`, `codex`, `vibe`, `amp`). Promoted to front of pool. |
| `providers.fallback` | string | _(none)_ | Fallback provider used when primary is unavailable. |
| `providers.pool` | list | `[]` | Ordered list of [provider pool](../glossary.md#provider-pool) entries with optional weights and roles. |
| `providers.native` | object | _(none)_ | [Native agent runtime](../glossary.md#native-agent-runtime) configuration (model, API key, endpoint). |
| `providers.codex_cli_config_overrides` | list | `[]` | Extra CLI flags passed to Codex invocations. |
| `providers.claude_code_cli_config_overrides` | list | `[]` | Extra CLI flags passed to Claude Code invocations. |
| `providers.gemini_cli_config_overrides` | list | `[]` | Extra CLI flags passed to Gemini invocations. |
| `providers.vibe_cli_config_overrides` | list | `[]` | Extra CLI flags passed to Vibe invocations. |
| `providers.amp_cli_config_overrides` | list | `[]` | Extra CLI flags passed to AMP invocations. |
| `providers.reasoning_effort_by_category` | map | `{docs: low, refactor: high, security: high, core: medium, default: medium}` | Reasoning effort level per task category. |
| `providers.agent_seconds_by_category` | map | `{docs: 180, refactor: 480, security: 480, core: 360, default: 360}` | Agent timeout in seconds per task category. |
| `providers.context_injection_max_tokens_by_category` | map | `{docs: 2000, refactor: 12000, core: 8000, default: 8000}` | Max context injection tokens per task category. |

---

## `git`

Git integration and branch management.

| Key | Type | Default | Range / Valid Values | Description |
|-----|------|---------|----------------------|-------------|
| `git.base_branch` | string | `main` | | The base branch for merges and diff comparison. |
| `git.feature_prefix` | string | `feat/` | | Prefix for [feature branches](../glossary.md#feature-branch) created per task. |
| `git.auto_delete_remote_merged_branches` | bool | `false` | | Delete remote branches after successful merge. |
| `git.auto_stash` | bool | `false` | | Automatically stash dirty worktree before operations. |
| `git.auto_stash_skip_rejected` | bool | `true` | | Skip auto-stash when context was rejected by [review](../glossary.md#review). |
| `git.auto_stash_skip_rejected_unattended` | bool | `false` | | Override `auto_stash_skip_rejected` in unattended mode (stash rejected context instead of skipping). |
| `git.sync_between_loops` | bool | `false` | | Perform [git sync](../glossary.md#git-sync) between [autopilot](../glossary.md#autopilot) loop iterations. |
| `git.sync_strategy` | string | `fetch_only` | `fetch_only`, `pull_ff` | Strategy for inter-loop git synchronization. |

---

## `workflow`

Controls the delivery pipeline stages (commit, push, merge, review).

| Key | Type | Default | Range / Valid Values | Description |
|-----|------|---------|----------------------|-------------|
| `workflow.require_review` | bool | `true` | | Require [review](../glossary.md#review) approval before task completion. When `false`, tasks skip the review gate. |
| `workflow.auto_commit` | bool | `true` | | Automatically commit agent-produced diffs. |
| `workflow.auto_push` | bool | `true` | | Automatically push committed changes to the remote. |
| `workflow.auto_merge` | bool | `true` | | Automatically merge approved [feature branches](../glossary.md#feature-branch) into the [base branch](../glossary.md#feature-branch). |
| `workflow.merge_strategy` | string | `merge` | `merge`, `rebase_before_merge` | Git merge strategy. `rebase_before_merge` rebases the feature branch onto base before merging. |

---

## `autopilot`

Controls the autonomous execution loop, task selection, retry budgets, safety limits, and self-healing. See [Autopilot](../glossary.md#autopilot).

### Core Loop

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.step_sleep_seconds` | duration | `2` | >= 0 | Seconds to sleep between consecutive [steps](../glossary.md#step). |
| `autopilot.idle_sleep_seconds` | duration | `30` | >= 0 | Seconds to sleep when no task is ready ([idle step](../glossary.md#idle-step)). |
| `autopilot.max_steps` | int | _(null)_ | >= 1 | Maximum number of steps before automatic termination. `null` means unlimited. |
| `autopilot.max_wallclock_hours` | int | `24` | >= 1 | Maximum wall-clock hours before forced termination. |
| `autopilot.max_iterations_safety_limit` | int | `2000` | >= 1 | Hard ceiling on total loop iterations to prevent runaway execution. |
| `autopilot.lock_ttl_seconds` | duration | `600` | >= 1 | Time-to-live for the autopilot [lock](../glossary.md#lock) file. |
| `autopilot.preflight_timeout_seconds` | duration | `30` | >= 1 | Timeout for [preflight](../glossary.md#preflight) checks. |
| `autopilot.manual_override` | bool | `false` | | When `true`, allows manual intervention to override autopilot decisions. |

### Task Selection

| Key | Type | Default | Range / Valid Values | Description |
|-----|------|---------|----------------------|-------------|
| `autopilot.selection_mode` | string | `strict_priority` | `fair`, `fairness`, `priority`, `strict_priority`, `strict-priority` | Task [selection algorithm](../glossary.md#selection-mode). `strict_priority` always picks the highest-[priority](../glossary.md#priority) task. `fair` uses priority-weighted round-robin within a fairness window. |
| `autopilot.fairness_window` | int | `12` | >= 1 | Number of recent steps considered for fairness rotation in `fair` selection mode. |
| `autopilot.priority_weight_p1` | int | `3` | >= 1 | Weight multiplier for P1 tasks in weighted selection. |
| `autopilot.priority_weight_p2` | int | `2` | >= 1 | Weight multiplier for P2 tasks in weighted selection. |
| `autopilot.priority_weight_p3` | int | `1` | >= 1 | Weight multiplier for P3 tasks in weighted selection. |
| `autopilot.min_open` | int | `8` | >= 1 | Minimum open tasks to maintain in the [backlog](../glossary.md#backlog). Triggers planning when count drops below. |
| `autopilot.max_plan_add` | int | `4` | >= 1 | Maximum number of tasks a single planning pass may add to the backlog. |
| `autopilot.subtask_queue_max` | int | `100` | >= 1 | Maximum number of [subtasks](../glossary.md#subtask) queued per task. |

### Retry & Failure Budgets

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.max_failures` | int | `5` | >= 1 | Maximum total failures before [safety halt](../glossary.md#safety-halt). |
| `autopilot.max_task_retries` | int | `3` | >= 1 | Maximum retry [attempts](../glossary.md#attempt) per task before blocking it. |
| `autopilot.no_progress_threshold` | int | `6` | >= 0 | Consecutive no-progress steps before triggering stuck detection. |
| `autopilot.push_failure_threshold` | int | `5` | >= 1 | Consecutive push failures before halting. |
| `autopilot.provider_failure_threshold` | int | `3` | >= 1 | Consecutive [provider](../glossary.md#provider) failures before disabling the provider. |
| `autopilot.approve_budget` | int | `3` | >= 0 | Maximum auto-approvals per run. See [Approve Budget](../glossary.md#approve-budget). |

### Reactivation & Cooldowns

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.reactivate_blocked` | bool | `false` | | Automatically reactivate [blocked](../glossary.md#blocked) tasks after [cooldown](../glossary.md#cooldown). |
| `autopilot.reactivate_failed` | bool | `true` | | Automatically reactivate failed tasks after cooldown. |
| `autopilot.blocked_cooldown_seconds` | duration | `0` | >= 0 | Seconds before a blocked task becomes eligible for reactivation. |
| `autopilot.failed_cooldown_seconds` | duration | `0` | >= 0 | Seconds before a failed task becomes eligible for reactivation. |
| `autopilot.stuck_cooldown_seconds` | duration | `60` | >= 0 | Seconds to wait after stuck detection before resuming. |

### Scope Limits

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.scope_max_files` | int | `60` | >= 0 | Maximum files an agent may modify in a single step. 0 = unlimited. |
| `autopilot.scope_max_additions` | int | `6000` | >= 0 | Maximum lines added per step. 0 = unlimited. |
| `autopilot.scope_max_deletions` | int | `4500` | >= 0 | Maximum lines deleted per step. 0 = unlimited. |
| `autopilot.max_stash_entries` | int | `20` | >= 1 | Maximum git stash entries retained before cleanup. |

### Self-Healing & Self-Restart

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.self_restart` | bool | `true` | | Enable automatic restart after recoverable failures. |
| `autopilot.max_self_restarts` | int | `5` | >= 0 | Maximum number of self-restarts per run. |
| `autopilot.self_heal_enabled` | bool | `true` | | Enable [self-heal](../glossary.md#self-heal) mechanisms for git state, config drift, and stuck locks. |
| `autopilot.self_heal_max_attempts` | int | `3` | >= 0 | Maximum self-heal attempts per incident before escalating. |
| `autopilot.resource_check_enabled` | bool | `true` | | Check system resource availability (memory, disk) before each step. |

### Self-Tune

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.self_tune_enabled` | bool | `true` | | Enable [self-tune](../glossary.md#self-tune) parameter adjustments based on observed performance. |
| `autopilot.self_tune_window` | int | `12` | >= 1 | Number of recent steps analyzed for self-tuning decisions. |
| `autopilot.self_tune_min_samples` | int | `4` | >= 1 | Minimum samples required before self-tune adjusts parameters. |
| `autopilot.self_tune_success_percent` | int | `70` | 0 -- 100 | Target success percentage for self-tune optimization. |

### Release Tagging

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.release_tag_on_ready` | bool | `true` | | Automatically create a git tag when all tasks reach "done" state. |
| `autopilot.release_tag_push` | bool | `true` | | Push release tags to the remote. |
| `autopilot.release_tag_prefix` | string | `v` | | Prefix for release tags (e.g., `v` produces `v1.0.0`). |

### Planning Audit

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.planning_audit_enabled` | bool | `true` | | Enable periodic planning audits that reassess the [backlog](../glossary.md#backlog). |
| `autopilot.planning_audit_cadence_steps` | int | `12` | >= 1 | Steps between planning audit passes. |
| `autopilot.planning_audit_max_add` | int | `4` | >= 1 | Maximum tasks a planning audit may add per pass. |

### Overnight & Review Contract

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.overnight_unattended_enabled` | bool | `false` | | Enable [overnight](../glossary.md#overnight-profile) unattended execution mode. |
| `autopilot.review_contract_lock_enabled` | bool | `true` | | Lock review contracts to prevent concurrent review modification. |

### Sprint Planning

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `autopilot.sprint_planning_enabled` | bool | `false` | | Enable autonomous sprint planning. When `true`, `SprintPlannerService` is invoked after all tasks are done to generate the next sprint instead of stopping. Set automatically to `true` by `genaisys init --from`. |
| `autopilot.max_sprints` | int | `0` | >= 0 | Maximum number of sprints before the autopilot terminates with `max_sprints_reached`. `0` means unlimited. |
| `autopilot.sprint_size` | int | `8` | 1–50 | Number of tasks generated per new sprint by `SprintPlannerService`. |

---

## `hitl`

Human-in-the-Loop gate configuration. When a gate is triggered the autopilot writes `.genaisys/locks/hitl.gate` and polls for `.genaisys/locks/hitl.decision`. Use `genaisys hitl status|approve|reject` to interact from the CLI.

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `hitl.enabled` | bool | `false` | | Master switch. Must be `true` for any gate to activate. |
| `hitl.timeout_minutes` | int | `60` | >= 0 | Minutes to wait before auto-approving. `0` = wait indefinitely. |
| `hitl.gate_after_task_done` | bool | `false` | | Pause after every auto-marked-done task completion. |
| `hitl.gate_before_sprint` | bool | `false` | | Pause before each new sprint is generated by `SprintPlannerService`. |
| `hitl.gate_before_halt` | bool | `false` | | Pause before the autopilot performs a safety halt. Human can approve to halt normally or reject to terminate with `hitl_rejected`. |

**Example:**
```yaml
hitl:
  enabled: true
  timeout_minutes: 60
  gate_before_sprint: true
  gate_before_halt: true
```

---

## `review`

Controls the [review](../glossary.md#review) agent and evidence requirements.

| Key | Type | Default | Range / Valid Values | Description |
|-----|------|---------|----------------------|-------------|
| `review.fresh_context` | bool | `true` | | Instantiate the review [agent](../glossary.md#agent) with [fresh context](../glossary.md#fresh-context) (no carry-over from the coding agent). |
| `review.strictness` | string | `standard` | `strict`, `standard`, `lenient` | Review stringency level. `strict` flags minor issues; `lenient` focuses on correctness only. |
| `review.max_rounds` | int | `3` | >= 1 | Maximum review-revise rounds before blocking the task. See [Review Gate](../glossary.md#review-gate). |
| `review.require_evidence` | bool | `true` | | Require an [evidence bundle](../glossary.md#evidence-bundle) (test results, DoD checklist) for approval. |
| `review.evidence_min_length` | int | `50` | >= 1 | Minimum character length for review evidence text. |

---

## `policies`

Safety constraints enforced by the [orchestrator](../glossary.md#orchestrator). See [Policy](../glossary.md#policy).

| Key | Type | Default | Valid Values | Description |
|-----|------|---------|--------------|-------------|
| `policies.shell_allowlist_profile` | string | `standard` | `minimal`, `standard`, `extended`, `custom` | [Shell allowlist](../glossary.md#shell-allowlist) profile. Determines which shell commands agents may execute. |

The following list-based policies are parsed by specialized parsers:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `policies.shell_allowlist` | list | _(profile-dependent)_ | Custom shell command allowlist (used when profile is `custom`). |
| `policies.safe_write.roots` | list | See below | Allowed write roots for the [Safe-Write](../glossary.md#safe-write) policy. |
| `policies.quality_gate.commands` | list | See below | Quality gate command sequence. |

**Default `safe_write.roots`**: `lib`, `test`, `assets`, `web`, `android`, `ios`, `linux`, `macos`, `windows`, `bin`, `tool`, `scripts`, `docs`, `.genaisys/agent_contexts`, `.github`, `README.md`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`, `.dart_tool`, `CHANGELOG.md`

**Default `quality_gate.commands`**: `dart format --output=none --set-exit-if-changed .`, `dart analyze`, `dart test`

### `policies.diff_budget`

Limits on change size per step. See [Diff Budget](../glossary.md#diff-budget).

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `policies.diff_budget.max_files` | int | `20` | >= 1 | Maximum number of files changed per step. |
| `policies.diff_budget.max_additions` | int | `2000` | >= 1 | Maximum lines added per step. |
| `policies.diff_budget.max_deletions` | int | `1500` | >= 1 | Maximum lines deleted per step. |

### `policies.safe_write`

File-write restriction policy. See [Safe-Write](../glossary.md#safe-write).

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `policies.safe_write.enabled` | bool | `true` | | Enable [Safe-Write](../glossary.md#safe-write) policy enforcement. When disabled, agents may write to any path. |

### `policies.quality_gate`

Verification commands that must pass before a diff can proceed to review. See [Quality Gate](../glossary.md#quality-gate).

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `policies.quality_gate.enabled` | bool | `true` | | Enable the [quality gate](../glossary.md#quality-gate) pipeline. |
| `policies.quality_gate.timeout_seconds` | duration | `900` | >= 1 | Maximum time in seconds for the full quality gate to complete. |
| `policies.quality_gate.adaptive_by_diff` | bool | `true` | | Enable [adaptive diff](../glossary.md#adaptive-diff) mode to adjust checks based on change type. |
| `policies.quality_gate.skip_tests_for_docs_only` | bool | `true` | | Skip test execution for documentation-only changes. |
| `policies.quality_gate.prefer_dart_test_for_lib_dart_only` | bool | `true` | | Use `dart test` instead of `flutter test` when changes touch only `lib/` Dart files. |
| `policies.quality_gate.flake_retry_count` | int | `1` | >= 0 | Number of automatic retries for flaky test failures. |

### `policies.timeouts`

Global timeout configuration.

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `policies.timeouts.agent_seconds` | duration | `900` | >= 1 | Default timeout in seconds for [agent](../glossary.md#agent) invocations. Overridden per category by `providers.agent_seconds_by_category`. |

---

## `pipeline`

Controls the prompt enrichment and intelligence [pipeline](../glossary.md#pipeline) stages.

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `pipeline.context_injection_enabled` | bool | `true` | | Enable [context injection](../glossary.md#context-injection) into agent prompts. |
| `pipeline.context_injection_max_tokens` | int | `8000` | >= 1 | Maximum tokens for injected context. Overridden per category by `providers.context_injection_max_tokens_by_category`. |
| `pipeline.error_pattern_injection_enabled` | bool | `true` | | Inject past error patterns into agent prompts to prevent recurring failures. |
| `pipeline.impact_analysis_enabled` | bool | `true` | | Enable change-impact analysis to scope affected areas before coding. |
| `pipeline.architecture_gate_enabled` | bool | `true` | | Enable architecture boundary checks before accepting diffs. |
| `pipeline.forensic_recovery_enabled` | bool | `true` | | Enable [forensic recovery](../glossary.md#forensic-recovery) analysis for stuck states. |
| `pipeline.error_pattern_learning_enabled` | bool | `true` | | Enable [error pattern learning](../glossary.md#error-pattern-learning) from past failures. |
| `pipeline.impact_context_max_files` | int | `10` | >= 1 | Maximum files included in impact analysis context. |

---

## `reflection`

Periodic meta-analysis of autopilot productivity. See [Reflection](../glossary.md#reflection).

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `reflection.enabled` | bool | `true` | | Enable the [reflection](../glossary.md#reflection) system. |
| `reflection.trigger_mode` | string | `loop_count` | | Trigger mode for reflection passes: `loop_count`, `task_count`, or `hours`. |
| `reflection.trigger_loop_count` | int | `10` | >= 1 | Number of loops between reflection passes (when `trigger_mode` is `loop_count`). |
| `reflection.trigger_task_count` | int | `5` | >= 1 | Number of completed tasks between reflection passes (when `trigger_mode` is `task_count`). |
| `reflection.trigger_hours` | int | `4` | >= 1 | Hours between reflection passes (when `trigger_mode` is `hours`). |
| `reflection.min_samples` | int | `5` | >= 1 | Minimum data samples required before generating reflection insights. |
| `reflection.max_optimization_tasks` | int | `3` | >= 0 | Maximum optimization tasks reflection may create per pass. |
| `reflection.optimization_task_priority` | string | `P2` | | [Priority](../glossary.md#priority) level assigned to reflection-generated optimization tasks. |
| `reflection.analysis_window_lines` | int | `2000` | >= 1 | Maximum run-log lines analyzed per reflection pass. |

---

## `supervisor`

Meta-orchestrator that monitors the autopilot process. See [Supervisor](../glossary.md#supervisor).

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `supervisor.reflection_on_halt` | bool | `true` | | Trigger a [reflection](../glossary.md#reflection) pass when the autopilot halts due to failure. |
| `supervisor.max_interventions_per_hour` | int | `5` | >= 1 | Maximum supervisor interventions (restarts, heals) per hour. |
| `supervisor.check_interval_seconds` | duration | `30` | >= 1 | Seconds between supervisor health checks. |

---

## `code_health`

Automated [code health](../glossary.md#health-check) detection and refactoring task generation.

### Detection

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `code_health.enabled` | bool | `true` | | Enable code health analysis. |
| `code_health.auto_create_tasks` | bool | `true` | | Automatically create refactoring [tasks](../glossary.md#task) for detected issues. |
| `code_health.min_confidence` | double | `0.6` | 0.0 -- 1.0 | Minimum confidence score to report a code health issue. |
| `code_health.block_features` | bool | `false` | | Block new feature tasks when code health score is below threshold. |

### Thresholds

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `code_health.max_refactor_ratio` | double | `0.3` | 0.0 -- 1.0 | Maximum ratio of refactoring tasks to total backlog. |
| `code_health.max_file_lines` | int | `500` | >= 1 | Files exceeding this line count trigger a "large file" finding. |
| `code_health.max_method_lines` | int | `80` | >= 1 | Methods exceeding this line count trigger a "long method" finding. |
| `code_health.max_nesting_depth` | int | `5` | >= 1 | Maximum nesting depth before triggering a complexity finding. |
| `code_health.max_parameter_count` | int | `6` | >= 1 | Maximum method parameters before triggering a finding. |

### Hotspot Analysis

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `code_health.hotspot_threshold` | double | `0.3` | 0.0 -- 1.0 | Churn-frequency threshold for marking a file as a hotspot. |
| `code_health.hotspot_window` | int | `20` | >= 1 | Number of recent commits analyzed for hotspot detection. |
| `code_health.patch_cluster_min` | int | `3` | >= 1 | Minimum co-changed files to form a patch cluster. |

### Reflection Integration

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `code_health.reflection_enabled` | bool | `true` | | Enable LLM-based code health reflection for deeper analysis. |
| `code_health.reflection_cadence` | int | `0` | >= 0 | Steps between code health reflection passes. 0 = only on demand. |
| `code_health.llm_budget_tokens` | int | `4000` | >= 1 | Token budget for LLM-based code health analysis. |

---

## `vision_evaluation`

Periodic evaluation of progress toward the project [vision](../glossary.md#vision).

| Key | Type | Default | Range | Description |
|-----|------|---------|-------|-------------|
| `vision_evaluation.enabled` | bool | `true` | | Enable periodic vision completion evaluation. |
| `vision_evaluation.interval` | int | `10` | >= 1 | Steps between vision evaluation passes. |
| `vision_evaluation.completion_threshold` | double | `0.9` | 0.0 -- 1.0 | Completion fraction at which the project vision is considered achieved. |

---

## Non-Registry Fields

These fields are parsed by specialized section parsers and do not appear in the scalar config field registry.

### `project`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `project.type` | string | _(auto-detected)_ | Project type hint (`dart`, `flutter`, `python`, `typescript`, `go`, `rust`, `java`, etc.). Used for quality gate command selection. |

### `agents`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `agents.<name>.role` | string | _(required)_ | Agent role identifier for profile-based invocation. |

Agent profiles are defined as named objects under the `agents:` section. Each profile can override provider, timeout, and prompt settings.

---

## Presets

[Configuration presets](../glossary.md#config-preset) provide sensible defaults for common use cases. Apply a preset by setting the top-level `preset:` key:

```yaml
preset: overnight
autopilot:
  max_steps: 200   # overrides the preset value
```

Precedence (highest wins):
1. Explicit YAML values
2. Preset values
3. Registry defaults

Available presets: **`conservative`**, **`aggressive`**, **`overnight`**.

See [Presets Reference](presets.md) for full details on each preset.

---

## Related Documentation

- [Configuration Guide](../guide/configuration.md) -- How to configure and validate your setup
- [Presets Reference](presets.md) -- Built-in preset profiles with key overrides
- [CLI Commands Reference](cli.md) -- `config validate`, `config diff`, and other commands
- [Glossary](../glossary.md) -- Definitions of all Genaisys terms
- [State JSON Schema](state-json-schema.md) -- Runtime state file structure
