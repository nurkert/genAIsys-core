[Home](../README.md) > [Reference](./README.md) > Data Contracts

# Data Contracts

Complete catalog of all artifacts stored in `.genaisys/` -- the [single source of truth](../glossary.md#data-contracts) for project state, task history, configuration, and observability.

---

## Overview

Every Genaisys-managed project contains a `.genaisys/` directory at the project root. This directory holds all orchestration artifacts: runtime state, task definitions, configuration, event logs, audit evidence, and lock files. The directory is created during `genaisys init` and maintained automatically by the [orchestrator](../glossary.md#orchestrator).

Source: `lib/core/project_layout.dart`, `lib/core/project_initializer.dart`

---

## Directory Structure

```
.genaisys/
  .gitignore              # Controls which artifacts are tracked vs runtime-only
  VISION.md               # Project vision document
  RULES.md                # Project rules and constraints
  TASKS.md                # Task backlog (markdown checklist)
  ARCHITECTURE.md         # Project architecture reference
  config.yml              # Orchestrator configuration
  STATE.json              # Runtime state (gitignored)
  RUN_LOG.jsonl           # Event log (gitignored)
  health_ledger.jsonl     # Delivery health snapshots (gitignored)
  health.json             # Health summary (gitignored)
  benchmarks.json         # Eval benchmarks
  agent_contexts/         # Per-agent context files
    coding.md
    review.md
    spec.md
    plan.md
    subtasks.md
  task_specs/             # Per-task spec/plan/subtasks (gitignored)
  attempts/               # Coding attempt artifacts (gitignored)
  workspaces/             # Workspace artifacts (gitignored)
  locks/                  # Process lock files (gitignored)
    autopilot.lock
    autopilot.stop
    autopilot_supervisor.lock
    autopilot_supervisor.stop
    heartbeat
    hitl.gate               # HITL gate context (created when gate opens)
    hitl.decision           # HITL decision (created when human responds)
  audit/                  # Audit trail bundles (gitignored)
    <task-slug>/
      <timestamp>_review/
        summary.json
        diff_summary.txt
        diff_patch.diff
        spec.md
        config_snapshot.yml
        state_snapshot.json
        attempt_snapshot.txt
        run_log_excerpt.jsonl
      <timestamp>_outcome/
        ...
    health_trend_snapshots.json
    unattended_provider_blocklist.json
    provider_pool_state.json
    runtime_switch_state.json
    error_patterns.json
    exit_summary.json
  evals/                  # Evaluation harness data (gitignored)
    runs/
    summary.json
  logs/                   # Archived logs (gitignored)
    run_log_archive/
  releases/               # Release management (gitignored)
    candidates/
    stable/
```

---

## Artifact Catalog

### Git-Tracked Artifacts

These files are committed to the repository and shared across team members.

| Artifact | Format | Description |
|----------|--------|-------------|
| `.gitignore` | text | Controls which artifacts are runtime-only |
| `VISION.md` | Markdown | Long-term project goals, constraints, success criteria |
| `RULES.md` | Markdown | Project-specific rules and coding standards |
| `TASKS.md` | Markdown | Task backlog as a prioritized checkbox list |
| `ARCHITECTURE.md` | Markdown | Project architecture reference |
| `config.yml` | YAML | Orchestrator configuration (providers, policies, gates) |
| `benchmarks.json` | JSON | Evaluation benchmarks |
| `agent_contexts/*.md` | Markdown | Context templates for each agent role |

### Runtime-Only Artifacts (Gitignored)

These files are generated at runtime and excluded from version control.

| Artifact | Format | Description |
|----------|--------|-------------|
| `STATE.json` | JSON | Current orchestrator state |
| `RUN_LOG.jsonl` | JSONL | Append-only event log |
| `health_ledger.jsonl` | JSONL | Delivery health snapshots |
| `health.json` | JSON | Current health summary |
| `task_specs/` | directory | Per-task SPEC.md, PLAN.md, SUBTASKS.md |
| `attempts/` | directory | Coding attempt outputs |
| `workspaces/` | directory | Workspace-specific artifacts |
| `locks/` | directory | Process lock and signal files |
| `audit/` | directory | Audit trail evidence bundles |
| `evals/` | directory | Eval harness runs and summaries |
| `logs/` | directory | Archived log files |
| `releases/` | directory | Release candidates and stable releases |

---

## Detailed Artifact Reference

### VISION.md

**Purpose:** Defines the project's long-term goals, constraints, and success criteria. Used by the [orchestrator](../glossary.md#orchestrator) for vision alignment evaluation and strategic planning.

**Created:** During `genaisys init`.
**Updated:** Manually by the user, or by the orchestrator during vision gap analysis.
**Schema:** Freeform Markdown with conventional sections: Goals, Constraints, Success Criteria.

### RULES.md

**Purpose:** Project-specific rules, coding standards, and constraints that agents must follow. Injected into agent prompts as context.

**Created:** During `genaisys init`.
**Updated:** Manually or during [self-improvement](../glossary.md#self-improvement) cycles.
**Schema:** Freeform Markdown.

### TASKS.md

**Purpose:** The [backlog](../glossary.md#backlog) of tasks organized as a prioritized markdown checklist. Each task is a checkbox line with optional priority (`[P1]`, `[P2]`, `[P3]`) and category (`[CORE]`, `[SEC]`, `[QA]`, `[UI]`, `[DOCS]`, `[ARCH]`, `[AGENT]`, `[REFACTOR]`) tags.

**Created:** During `genaisys init`.
**Updated:** By `genaisys task add`, by the orchestrator when completing tasks (checkbox toggled), or manually.
**Schema:** Markdown with `## Section` headers and `- [ ] Task title [P1] [CORE]` lines.

Source: `lib/core/storage/task_store.dart`

**Example:**
```markdown
## Backlog

- [ ] [P1] [CORE] Implement authentication module
- [ ] [P2] [UI] Add dark mode support
- [x] [P1] [SEC] Fix token validation

## Done

- [x] Initial project setup
```

### config.yml

**Purpose:** Central configuration for the orchestrator: provider selection, quality gate commands, safety policies, autopilot budgets, and feature toggles.

**Created:** During `genaisys init` (with auto-detected [quality gate profile](../glossary.md#quality-gate)).
**Updated:** By `genaisys config set`, manually, or via hot-reload during autopilot runs.
**Schema:** YAML, validated against `ConfigFieldRegistry`. See [Presets](presets.md).

### STATE.json

**Purpose:** Runtime state tracking: active task, workflow stage, review status, cycle counters, autopilot/supervisor state, health indicators, and retry tracking.

**Created:** During `genaisys init` with default values.
**Updated:** After every state-changing operation (activate, review, cycle, etc.).
**Schema:** JSON with CRC32 checksum integrity verification. Schema-validated on every read ([fail-closed](../glossary.md#fail-closed)). See [STATE.json Schema](state-json-schema.md).

**Write mechanism:** Atomic file write (temp file + flush + rename) via `AtomicFileWrite`. The `_checksum` field embeds a CRC32 of the payload for corruption detection.

Source: `lib/core/storage/state_store.dart`, `lib/core/storage/atomic_file_write.dart`

### RUN_LOG.jsonl

**Purpose:** Append-only event log recording every reliability-critical action taken by the orchestrator. Primary diagnostic artifact.

**Created:** During `genaisys init` (empty file).
**Updated:** Continuously during orchestrator operation (one JSON object per line).
**Rotated:** When file exceeds 2 MB, rotated to `.genaisys/logs/run_log_archive/`.
**Schema:** JSONL with structured envelope (timestamp, event_id, correlation, event, data). See [Run Log Schema](run-log-schema.md).

Source: `lib/core/storage/run_log_store.dart`

### health_ledger.jsonl

**Purpose:** Append-only ledger of delivery health snapshots. Each entry records per-file metrics (churn, complexity indicators) at delivery time. Used for code health evaluation, [hotspot](../glossary.md#hotspot) detection, and trend analysis.

**Created:** On first delivery health evaluation.
**Updated:** After each delivery.
**Schema:** JSONL with `DeliveryHealthEntry` objects.

Source: `lib/core/storage/health_ledger_store.dart`

### health.json

**Purpose:** Current aggregated health summary snapshot.

**Created:** On first health evaluation.
**Updated:** Periodically during autopilot runs.

### task_specs/ Directory

**Purpose:** Per-task specification artifacts generated during the [planning](../glossary.md#planning) phase.

**Contents per task:**

| File | Description |
|------|-------------|
| `SPEC.md` | Task specification with requirements and acceptance criteria |
| `PLAN.md` | Implementation plan with ordered steps |
| `SUBTASKS.md` | Breakdown into atomic subtasks |

**Created:** During task activation and planning phase.
**Updated:** During subtask refinement or re-planning.
**Deleted:** Cleaned up when task is completed or blocked.

### attempts/ Directory

**Purpose:** Stores output from individual coding [attempts](../glossary.md#attempt). Each attempt produces a text file with the agent's output, diff, and metadata.

**Created:** After each coding agent invocation.
**Updated:** Overwritten per attempt.

### locks/ Directory

**Purpose:** Process coordination files ensuring only one autopilot/supervisor runs at a time.

| File | Description | Lifecycle |
|------|-------------|-----------|
| `autopilot.lock` | Autopilot process lock | Created on start, deleted on clean exit, recovered if PID dead |
| `autopilot.stop` | Graceful stop signal | Created by `genaisys stop`, consumed by running autopilot |
| `autopilot_supervisor.lock` | Supervisor process lock | Same as autopilot.lock |
| `autopilot_supervisor.stop` | Supervisor stop signal | Same as autopilot.stop |
| `heartbeat` | Liveness heartbeat | Updated every ~5 seconds during autopilot operation |
| `hitl.gate` | HITL gate context | Written when a gate opens; deleted when gate resolves or times out |
| `hitl.decision` | HITL human decision | Written by `genaisys hitl approve/reject`; consumed by polling autopilot |

**HITL gate file format** (`hitl.gate`):

```
version=1
event=<gate_event>
step_id=<step_id>
task_id=<task_id>
task_title=<title>
sprint_number=<n>
created_at=<ISO8601>
expires_at=<ISO8601>
```

**HITL decision file format** (`hitl.decision`):

```
version=1
decision=approve|reject
decided_at=<ISO8601>
note=<optional human note>
```

**Lock format:** JSON with `pid`, `started_at`, `last_heartbeat` fields.
**Recovery:** Lock status combines metadata with PID liveness checks. A dead PID lock is recovered immediately with `recovery_reason: pid_not_alive` in the run log.

Source: `lib/core/services/orchestrator/orchestrator_run_locking.dart`

### audit/ Directory

**Purpose:** Structured evidence bundles for every [review](../glossary.md#review) decision and task outcome. Provides forensic traceability.

**Structure:** `audit/<task-slug>/<timestamp>_<kind>/` where kind is `review` or `outcome`.

**Bundle contents:**

| File | Description |
|------|-------------|
| `summary.json` | Structured summary with decision, diff stats, git metadata, DoD checklist |
| `diff_summary.txt` | Human-readable diff summary |
| `diff_patch.diff` | Full unified diff |
| `spec.md` | Task spec at time of review |
| `config_snapshot.yml` | Config at time of review |
| `state_snapshot.json` | State at time of review |
| `attempt_snapshot.txt` | Latest coding attempt output |
| `run_log_excerpt.jsonl` | Last 20 run log events |

Source: `lib/core/services/audit_trail_service.dart`

**Additional audit files:**

| File | Description |
|------|-------------|
| `health_trend_snapshots.json` | Historical health trend data |
| `unattended_provider_blocklist.json` | Providers blocked due to repeated failures |
| `provider_pool_state.json` | Current provider pool rotation state |
| `runtime_switch_state.json` | Runtime switch tracking |
| `error_patterns.json` | Error pattern registry for recurring failures |
| `exit_summary.json` | Autopilot exit summary |

### evals/ Directory

**Purpose:** Evaluation harness data for measuring orchestrator effectiveness.

| Artifact | Description |
|----------|-------------|
| `runs/` | Individual eval run results |
| `summary.json` | Aggregated eval summary |

**Created:** During `genaisys eval` runs.

### releases/ Directory

**Purpose:** Release management artifacts.

| Subdirectory | Description |
|--------------|-------------|
| `candidates/` | Release candidate bundles awaiting promotion |
| `stable/` | Promoted stable release records |

### agent_contexts/ Directory

**Purpose:** Template context files injected into agent prompts for each role.

| File | Role |
|------|------|
| `coding.md` | Coding agent context |
| `review.md` | Review agent context |
| `spec.md` | Spec generation context |
| `plan.md` | Plan generation context |
| `subtasks.md` | Subtask generation context |

**Created:** During `genaisys init`.
**Updated:** Manually or during self-improvement cycles.

---

## Gitignore Policy

The `.genaisys/.gitignore` file controls which artifacts are tracked in version control versus treated as runtime-only. This separation is critical for preventing race conditions during git operations (especially autopilot lock heartbeat writes).

**Gitignored (runtime-only):**

```
RUN_LOG.jsonl
STATE.json
health_ledger.jsonl
attempts/
logs/
task_specs/
workspaces/
locks/
audit/
evals/
```

**Tracked (committed):**

- `.gitignore` itself
- `VISION.md`, `RULES.md`, `TASKS.md`, `ARCHITECTURE.md`
- `config.yml`
- `benchmarks.json`
- `agent_contexts/*.md`

**Rationale:** Runtime artifacts change frequently (STATE.json on every cycle, locks every 5 seconds) and would create constant merge conflicts and dirty worktree issues during autopilot operation. Tracked artifacts represent project intent and configuration that should be versioned.

Source: `lib/core/templates/default_files.dart`, lines 10-21

---

## Schema Validation

Genaisys validates artifact schemas at read time using a [fail-closed](../glossary.md#fail-closed) approach:

| Artifact | Validator | Behavior on Invalid |
|----------|-----------|---------------------|
| `STATE.json` | `StateSchemaValidator` | Returns `ProjectState.initial()` (safe default) |
| `config.yml` | `ConfigFieldRegistry` | Rejects unknown keys, enforces types and ranges |
| `TASKS.md` | `TaskStore` parser | Skips unparseable lines |
| `RUN_LOG.jsonl` | Per-line JSON decode | Skips malformed lines |
| `health_ledger.jsonl` | Per-line JSON decode | Skips malformed entries |

**STATE.json integrity:** Each write embeds a CRC32 checksum (`_checksum` field). On read, the checksum is verified. If it does not match, the state is treated as corrupt and reset to initial values, with a `state_corruption` event logged.

**Atomic writes:** STATE.json and config.yml use `AtomicFileWrite` -- write to temp file, flush, then rename -- to prevent partial writes from corrupting the file.

Source: `lib/core/services/schema_validation/state_schema_validator.dart`, `lib/core/storage/state_store.dart`

---

## File Lifecycle Summary

| Phase | Artifacts Created/Updated |
|-------|---------------------------|
| `init` | All tracked artifacts, empty STATE.json and RUN_LOG.jsonl |
| `activate` | STATE.json (active task), task_specs/ (SPEC.md, PLAN.md, SUBTASKS.md) |
| `cycle` / `step` | STATE.json, RUN_LOG.jsonl, attempts/, health_ledger.jsonl |
| `review` | STATE.json (review status), audit/ (evidence bundle) |
| `done` | STATE.json (clear active task), TASKS.md (toggle checkbox), audit/ (outcome) |
| `autopilot start` | locks/autopilot.lock, locks/heartbeat |
| `autopilot stop` | locks/autopilot.stop (signal), then lock cleanup |
| `supervisor start` | locks/autopilot_supervisor.lock |
| `config set` | config.yml |
| `task add` | TASKS.md |

---

## Related Documentation

- [STATE.json Schema](state-json-schema.md) -- Full runtime state field reference
- [Run Log Schema](run-log-schema.md) -- Event type catalog and error classification
- [Presets](presets.md) -- Configuration preset reference
- [Glossary: Data Contracts](../glossary.md#data-contracts) -- Term definition
- [Glossary: Single Source of Truth](../glossary.md#single-source-of-truth) -- Design principle
