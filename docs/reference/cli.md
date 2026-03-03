[Home](../README.md) > [Reference](./README.md) > CLI Commands

# CLI Commands Reference

Complete reference for every Genaisys CLI command, flag, output format, and exit code.

---

## Contents

- [General Syntax](#general-syntax)
- [Exit Codes](#exit-codes)
- [Commands](#commands)
- [JSON Contract](#json-contract)
- [Output Sanitization](#output-sanitization)

---

## General Syntax

```
genaisys <command> [path] [options]
```

- `path` is optional. When omitted, the current working directory is used as the project root.
- All commands support `--json` for machine-readable JSON output on stdout (single line).
- `--help` / `-h` / `help` prints the built-in help text.

## Exit Codes

| Code | Name          | Description                                          |
|------|---------------|------------------------------------------------------|
| 0    | success       | Command completed successfully.                      |
| 1    | state_error   | Operation failed due to invalid project state.       |
| 2    | state_error   | State-level error (e.g., no active task).             |
| 64   | usage_error   | Invalid command, missing flag, or bad argument.       |

See [Exit Codes Reference](exit-codes.md) for the complete table.

---

## Commands

### init

Initialize the `.genaisys` directory structure in a project. Detects the project type automatically (Dart/Flutter, Node.js, Python, Rust, Go, Java) and generates a language-appropriate `config.yml`.

**Syntax:**

```
genaisys init [path] [--overwrite] [--from <source>] [--static] [--sprint-size <n>] [--json]
```

**Flags:**

| Flag                  | Description                                                                                  |
|-----------------------|----------------------------------------------------------------------------------------------|
| `--overwrite`         | Overwrite existing `.genaisys` files if present.                                             |
| `--from <source>`     | Path to an input document (PDF or text file) used by the agent-driven 6-stage init pipeline to generate custom VISION.md, ARCHITECTURE.md, TASKS.md, config.yml, and RULES.md artifacts. When omitted, static default templates are used. |
| `--static`            | Force static template init even when `--from` is provided. Skips the orchestration pipeline. |
| `--sprint-size <n>`   | Number of tasks to generate in Sprint 1 (1–50, default: 8). Only applies when `--from` is used. Later sprints use `autopilot.sprint_size` from config.yml. |
| `--json`              | Output machine-readable JSON.                                                                |

**Agent-driven init pipeline (`--from`):**

When `--from <source>` is provided (without `--static`), Genaisys runs a 6-stage agent pipeline:

1. **Vision** — reads input doc → generates VISION.md
2. **Architecture** — reads vision → generates ARCHITECTURE.md
3. **Backlog** — reads vision + architecture → generates TASKS.md
4. **Config** — reads vision + architecture → refines config.yml
5. **Rules** — reads vision + architecture → generates RULES.md
6. **Verification** — reviews all 5 artifacts → APPROVE or REJECT + feedback (max 2 retries)

Supported input formats: plain text (`.txt`, `.md`), PDF (requires `pdftotext` on `PATH`).

**Text output:**

```
Genaisys initialized at: /path/to/project/.genaisys
```

**JSON output:**

```json
{"initialized": true, "genaisys_dir": "/path/to/project/.genaisys"}
```

**Exit codes:** 0 on success, 64 if the path does not exist or is not a directory.

---

### cycle

Advance the core cycle counter in `STATE.json`.

**Syntax:**

```
genaisys cycle [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Cycle updated to 5
```

**JSON output:**

```json
{"cycle_updated": true, "cycle_count": 5}
```

**Exit codes:** 0 on success, 2 if the project is not initialized.

---

### cycle run

Execute a full [task](../glossary.md#task) cycle: activate a task, run the coding agent with the given prompt, perform [review](../glossary.md#review), and update state.

**Syntax:**

```
genaisys cycle run [path] --prompt <text> [--test-summary <text>] [--overwrite] [--json]
```

**Flags:**

| Flag                    | Description                                              |
|-------------------------|----------------------------------------------------------|
| `--prompt <text>`       | **Required.** The prompt to send to the coding agent.    |
| `--test-summary <text>` | Optional test summary context for the agent.             |
| `--overwrite`           | Overwrite existing plan/spec/subtasks artifacts.         |
| `--json`                | Output machine-readable JSON.                            |

**Text output:**

```
Task cycle completed.
Review recorded: true
```

**JSON output:**

```json
{
  "task_cycle_completed": true,
  "review_recorded": true,
  "review_decision": "approve",
  "coding_ok": true
}
```

**Exit codes:** 0 on success, 64 if `--prompt` is missing, 2 on state error.

---

### next

Show the next open task without activating it.

**Syntax:**

```
genaisys next [path] [--section <name>] [--show-ids] [--json]
```

**Flags:**

| Flag               | Description                               |
|--------------------|-------------------------------------------|
| `--section <name>` | Limit results to a specific section.      |
| `--show-ids`       | Include the task ID in text output.       |
| `--json`           | Output machine-readable JSON.             |

**Text output:**

```
[Backlog] P1 CORE - Implement error handler
```

With `--show-ids`:

```
[Backlog] P1 CORE - Implement error handler [id: alpha-3]
```

If no open tasks exist:

```
No open tasks found.
```

**JSON output:**

```json
{
  "id": "alpha-3",
  "title": "Implement error handler",
  "section": "Backlog",
  "priority": "P1",
  "category": "CORE",
  "status": "open"
}
```

**Exit codes:** 0 on success (including when no tasks are found), 2 on state error.

---

### activate

Activate the next open task, or a specific task by ID or title.

**Syntax:**

```
genaisys activate [path] [--id <task-id>] [--title <text>] [--json]
```

**Flags:**

| Flag             | Description                                        |
|------------------|----------------------------------------------------|
| `--id <task-id>` | Activate a specific task by its ID.                |
| `--title <text>` | Activate a specific task by its exact title.       |
| `--json`         | Output machine-readable JSON.                      |

Note: `--id` and `--title` cannot be used together (exit code 64).

**Text output:**

```
Activated: Implement error handler
```

**JSON output:**

```json
{
  "activated": true,
  "task": {
    "id": "alpha-3",
    "title": "Implement error handler",
    "section": "Backlog",
    "priority": "P1",
    "category": "CORE",
    "status": "active"
  }
}
```

**Exit codes:** 0 on success, 64 if both `--id` and `--title` are provided, 2 on state error.

---

### deactivate

Clear the currently active task.

**Syntax:**

```
genaisys deactivate [path] [--keep-review] [--json]
```

**Flags:**

| Flag             | Description                                    |
|------------------|------------------------------------------------|
| `--keep-review`  | Do not clear the review status on deactivation.|
| `--json`         | Output machine-readable JSON.                  |

**Text output:**

```
Active task cleared.
```

**JSON output:**

```json
{
  "deactivated": true,
  "keep_review": false,
  "active_task": "Implement error handler",
  "active_task_id": "alpha-3",
  "review_status": null,
  "review_updated_at": null
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### spec

Manage task spec files for the active task.

**Syntax:**

```
genaisys spec init [path] [--overwrite] [--json]
```

**Flags:**

| Flag          | Description                              |
|---------------|------------------------------------------|
| `--overwrite` | Overwrite existing spec file.            |
| `--json`      | Output machine-readable JSON.            |

**Text output:**

```
Created: /path/to/project/.genaisys/task_specs/alpha-3/spec.md
```

**JSON output:**

```json
{"created": true, "path": "/path/to/project/.genaisys/task_specs/alpha-3/spec.md"}
```

**Exit codes:** 0 on success, 64 if subcommand is missing, 2 on state error.

---

### plan

Manage task planning files for the active task.

**Syntax:**

```
genaisys plan init [path] [--overwrite] [--json]
```

**Flags:**

| Flag          | Description                              |
|---------------|------------------------------------------|
| `--overwrite` | Overwrite existing plan file.            |
| `--json`      | Output machine-readable JSON.            |

**Text output:**

```
Created: /path/to/project/.genaisys/task_specs/alpha-3/plan.md
```

**JSON output:**

```json
{"created": true, "path": "/path/to/project/.genaisys/task_specs/alpha-3/plan.md"}
```

**Exit codes:** 0 on success, 64 if subcommand is missing, 2 on state error.

---

### subtasks

Manage subtask files for the active task.

**Syntax:**

```
genaisys subtasks init [path] [--overwrite] [--json]
```

**Flags:**

| Flag          | Description                               |
|---------------|-------------------------------------------|
| `--overwrite` | Overwrite existing subtasks file.         |
| `--json`      | Output machine-readable JSON.             |

**Text output:**

```
Created: /path/to/project/.genaisys/task_specs/alpha-3/subtasks.md
```

**JSON output:**

```json
{"created": true, "path": "/path/to/project/.genaisys/task_specs/alpha-3/subtasks.md"}
```

**Exit codes:** 0 on success, 64 if subcommand is missing, 2 on state error.

---

### done

Mark the currently active task as done. The review status must be `approved` before a task can be marked done.

**Syntax:**

```
genaisys done [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Marked done: Implement error handler
```

**JSON output:**

```json
{"done": true, "task_title": "Implement error handler"}
```

**Exit codes:** 0 on success, 2 on state error (e.g., no active task or review not approved).

---

### block

Block the currently active task with an optional reason.

**Syntax:**

```
genaisys block [path] [--reason <text>] [--json]
```

**Flags:**

| Flag              | Description                            |
|-------------------|----------------------------------------|
| `--reason <text>` | Blocking reason (stored in state).     |
| `--json`          | Output machine-readable JSON.          |

**Text output:**

```
Blocked: Implement error handler
```

**JSON output:**

```json
{"blocked": true, "task_title": "Implement error handler", "reason": "Missing dependency"}
```

**Exit codes:** 0 on success, 2 on state error.

---

### review

Record [review](../glossary.md#review) decisions for the active task.

**Syntax:**

```
genaisys review approve [path] [--note <text>|--reason <text>] [--json]
genaisys review reject  [path] [--note <text>|--reason <text>] [--json]
genaisys review status  [path] [--json]
genaisys review clear   [path] [--note <text>|--reason <text>] [--json]
```

**Subcommands:**

| Subcommand | Description                              |
|------------|------------------------------------------|
| `approve`  | Set review status to approved.           |
| `reject`   | Set review status to rejected.           |
| `status`   | Show current review status.              |
| `clear`    | Clear the review status.                 |

**Flags:**

| Flag                          | Description                        |
|-------------------------------|------------------------------------|
| `--note <text>` / `--reason <text>` | Attach a note to the decision. |
| `--json`                      | Output machine-readable JSON.      |

**Text output (approve):**

```
Review approved for: Implement error handler
```

**JSON output (approve/reject):**

```json
{
  "review_recorded": true,
  "decision": "approve",
  "task_title": "Implement error handler",
  "note": "LGTM"
}
```

**JSON output (status):**

```json
{"review_status": "approved", "review_updated_at": "2026-02-18T10:00:00Z"}
```

**JSON output (clear):**

```json
{
  "review_cleared": true,
  "review_status": null,
  "review_updated_at": null,
  "note": null
}
```

**Exit codes:** 0 on success, 64 if subcommand is missing or unknown, 2 on state error.

---

### status

Show the current project status including task counts, active task, review status, health checks, and telemetry.

**Syntax:**

```
genaisys status [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Project root: /path/to/project
Tasks total: 25
Tasks open: 12
Tasks blocked: 3
Tasks done: 10
Active task: Implement error handler
Active task id: alpha-3
Review status: approved
Review updated at: 2026-02-18T10:00:00Z
Workflow stage: coding
Cycle count: 42
Last updated: 2026-02-18T10:05:00Z
Health agent: OK
Health allowlist: OK
Health git: OK
Health review: OK
```

**JSON output:**

```json
{
  "project_root": "/path/to/project",
  "tasks_total": 25,
  "tasks_open": 12,
  "tasks_blocked": 3,
  "tasks_done": 10,
  "active_task": "Implement error handler",
  "active_task_id": "alpha-3",
  "review_status": "approved",
  "review_updated_at": "2026-02-18T10:00:00Z",
  "workflow_stage": "coding",
  "cycle_count": 42,
  "last_updated": "2026-02-18T10:05:00Z",
  "last_error": null,
  "last_error_class": null,
  "last_error_kind": null,
  "health": {
    "all_ok": true,
    "agent": {"ok": true, "message": "Agent ok"},
    "allowlist": {"ok": true, "message": "Allowlist ok"},
    "git": {"ok": true, "message": "Git ok"},
    "review": {"ok": true, "message": "Review ok"}
  },
  "telemetry": {
    "error_class": null,
    "error_kind": null,
    "error_message": null,
    "agent_exit_code": null,
    "agent_stderr_excerpt": null,
    "last_error_event": null,
    "recent_events": []
  }
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### tasks

List tasks with status, priority, and category. Supports filtering and sorting.

**Syntax:**

```
genaisys tasks [path] [--open] [--done] [--blocked] [--active] [--show-ids] [--sort-priority] [--section <name>] [--json]
```

**Flags:**

| Flag                 | Description                                   |
|----------------------|-----------------------------------------------|
| `--open`             | Show only open tasks.                         |
| `--done`             | Show only completed tasks.                    |
| `--blocked`          | Show only blocked tasks.                      |
| `--active`           | Show only the active task.                    |
| `--show-ids`         | Include task IDs in text output.              |
| `--sort-priority`    | Sort by priority (P1 first).                  |
| `--section <name>`   | Filter by section title.                      |
| `--json`             | Output machine-readable JSON.                 |

Note: `--open` and `--done` together shows all tasks (open + done).

**Text output:**

```
[Backlog] open P1 CORE - Implement error handler
[Backlog] done P2 QA - Add integration tests
[Backlog] blocked P3 GUI - Sidebar animation
```

**JSON output:**

```json
{
  "tasks": [
    {
      "id": "alpha-3",
      "title": "Implement error handler",
      "section": "Backlog",
      "priority": "P1",
      "category": "CORE",
      "status": "open"
    }
  ]
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### app-settings

Manage global application settings (not project-specific). Settings are stored in a platform-dependent location:

- macOS/Linux: `~/.genaisys/application_settings.json`
- Windows: `%APPDATA%\Genaisys\application_settings.json`

**Syntax:**

```
genaisys app-settings [show] [--json]
genaisys app-settings set [--theme <mode>] [--language <code>] [--notifications <bool>] [--autopilot <bool>] [--telemetry <bool>] [--strict-secrets <bool>] [--json]
genaisys app-settings reset [--json]
```

**Subcommands:**

| Subcommand | Description                                 |
|------------|---------------------------------------------|
| `show`     | Display current settings (default action).  |
| `set`      | Update one or more settings.                |
| `reset`    | Reset all settings to defaults.             |

**Flags for `set`:**

| Flag                      | Description                                       |
|---------------------------|---------------------------------------------------|
| `--theme <mode>`          | Theme mode: `system`, `light`, or `dark`.         |
| `--language <code>`       | Language code (e.g., `en`, `de`).                 |
| `--notifications <bool>`  | Enable/disable desktop notifications.             |
| `--autopilot <bool>`      | Enable/disable [autopilot](../glossary.md#autopilot) by default. |
| `--telemetry <bool>`      | Enable/disable local telemetry.                   |
| `--strict-secrets <bool>` | Enable/disable strict secret redaction.           |
| `--json`                  | Output machine-readable JSON.                     |

Boolean values accept: `true`/`false`, `yes`/`no`, `on`/`off`, `1`/`0`.

**Text output:**

```
Application settings path: /Users/you/.genaisys/application_settings.json
theme_mode: system
language_code: en
desktop_notifications_enabled: true
autopilot_by_default_enabled: false
local_telemetry_enabled: false
strict_secret_redaction_enabled: false
```

**JSON output:**

```json
{
  "storage_path": "/Users/you/.genaisys/application_settings.json",
  "settings": {
    "theme_mode": "system",
    "language_code": "en",
    "desktop_notifications_enabled": true,
    "autopilot_by_default_enabled": false,
    "local_telemetry_enabled": false,
    "strict_secret_redaction_enabled": false
  }
}
```

**Exit codes:** 0 on success, 64 on invalid option or missing value, 1 on read/write failure.

---

### config validate

Validate the project configuration file (`.genaisys/config.yml`) against the schema.

**Syntax:**

```
genaisys config validate [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Config validation: PASS
  [OK] schema: Configuration schema is valid
  [OK] quality_gate: Quality gate commands are valid
Warnings:
  [WARN] shell_allowlist: Custom allowlist has no entries
         Hint: Add shell commands to policies.shell_allowlist
```

**JSON output:**

```json
{
  "ok": true,
  "checks": [
    {"name": "schema", "ok": true, "message": "Configuration schema is valid", "remediation_hint": null}
  ],
  "warnings": [
    {"name": "shell_allowlist", "ok": false, "message": "Custom allowlist has no entries", "remediation_hint": "Add shell commands to policies.shell_allowlist"}
  ]
}
```

**Exit codes:** 0 on success, 64 if the subcommand is missing, 2 on state error.

---

### config diff

Show non-default configuration values and their effects.

**Syntax:**

```
genaisys config diff [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Non-default config values:
  autopilot.max_failures: 10 (default: 5)
    Effect: Increases tolerance for consecutive failures before safety halt.
```

If all values are defaults:

```
All config values are at their defaults.
```

**JSON output:**

```json
{
  "has_diff": true,
  "entries": [
    {
      "field": "autopilot.max_failures",
      "current_value": "10",
      "default_value": "5",
      "effect": "Increases tolerance for consecutive failures before safety halt."
    }
  ]
}
```

**Exit codes:** 0 on success, 64 if the subcommand is missing, 2 on state error.

---

### health

Run all preflight and health checks for the project.

**Syntax:**

```
genaisys health [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Health: ALL CHECKS PASSED
  [OK] project_structure: .genaisys directory exists
  [OK] git_repo: Valid git repository
  [OK] config_valid: Configuration schema valid
  [OK] provider_ready: Provider credentials configured
```

On failure:

```
Health: ISSUES FOUND
  [OK] project_structure: .genaisys directory exists
  [FAIL] provider_ready: No provider credentials found
       error_kind: provider_not_configured
```

**JSON output:**

```json
{
  "ok": true,
  "checks": [
    {"name": "project_structure", "ok": true, "message": ".genaisys directory exists", "error_kind": null},
    {"name": "git_repo", "ok": true, "message": "Valid git repository", "error_kind": null}
  ]
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot step

Execute a single autonomous orchestrator step: sync vision/backlog, activate the next task if needed, run a task cycle with review, and handle post-review actions (deactivation, blocking).

**Syntax:**

```
genaisys autopilot step [path] [--prompt <text>] [--test-summary <text>] [--min-open <n>] [--max-plan-add <n>] [--overwrite] [--json]
```

**Flags:**

| Flag                    | Description                                                        |
|-------------------------|--------------------------------------------------------------------|
| `--prompt <text>`       | Base prompt for the coding step. Default: "Advance the roadmap with one minimal, safe, production-grade step." |
| `--test-summary <text>` | Optional test summary context.                                     |
| `--min-open <n>`        | Minimum open tasks before planner seeds new tasks (default: config value, typically 8). |
| `--max-plan-add <n>`    | Maximum new tasks to add per step (default: config value, typically 4). |
| `--overwrite`           | Overwrite existing plan/spec/subtasks artifacts.                   |
| `--json`                | Output machine-readable JSON.                                      |

**Text output:**

```
Autopilot step completed.
Executed cycle: true
Active task: Implement error handler
Planned tasks added: 0
Review decision: approve
Retry count: 0
Task blocked: false
```

**JSON output:**

```json
{
  "autopilot_step_completed": true,
  "executed_cycle": true,
  "activated_task": false,
  "active_task": "Implement error handler",
  "planned_tasks_added": 0,
  "review_decision": "approve",
  "retry_count": 0,
  "task_blocked": false,
  "deactivated_task": true
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot run

Run a continuous [autopilot](../glossary.md#autopilot) loop executing multiple steps with configurable pauses, failure limits, and stopping conditions.

**Syntax:**

```
genaisys autopilot run [path] [--prompt <text>] [--test-summary <text>] [--min-open <n>] [--max-plan-add <n>] [--step-sleep <s>] [--idle-sleep <s>] [--max-steps <n>] [--stop-when-idle] [--max-failures <n>] [--max-task-retries <n>] [--override-safety] [--overwrite] [--quiet] [--json]
```

**Flags:**

| Flag                      | Description                                                     |
|---------------------------|-----------------------------------------------------------------|
| `--prompt <text>`         | Base prompt for coding steps.                                   |
| `--test-summary <text>`   | Optional test summary context.                                  |
| `--min-open <n>`          | Minimum open tasks before planner seeds.                        |
| `--max-plan-add <n>`      | Maximum new tasks per step.                                     |
| `--step-sleep <s>`        | Pause in seconds after a productive step (default: 2).          |
| `--idle-sleep <s>`        | Pause in seconds after an idle/error step (default: 30).        |
| `--max-steps <n>`         | Hard stop after N steps.                                        |
| `--stop-when-idle`        | Stop when no active cycle is available.                         |
| `--max-failures <n>`      | Stop after N consecutive failures (default: 5).                 |
| `--max-task-retries <n>`  | Stop if a task is rejected more than N times (default: 3).      |
| `--override-safety`       | Override approve and scope budgets for this run.                |
| `--overwrite`             | Overwrite plan/spec/subtasks artifacts.                         |
| `--quiet`                 | Suppress live run-log event output.                             |
| `--json`                  | Output machine-readable JSON (on completion only).              |

**Text output:**

```
Autopilot run stopped.
Total steps: 15
Successful steps: 12
Idle steps: 2
Failed steps: 1
Stopped by max steps: true
Stopped when idle: false
Stopped by safety halt: false
```

**JSON output:**

```json
{
  "autopilot_run_completed": true,
  "total_steps": 15,
  "successful_steps": 12,
  "idle_steps": 2,
  "failed_steps": 1,
  "stopped_by_max_steps": true,
  "stopped_when_idle": false,
  "stopped_by_safety_halt": false
}
```

**Exit codes:** 0 on success, 64 on invalid option, 2 on state error.

---

### autopilot status

Show the status of a running or stopped autopilot process.

**Syntax:**

```
genaisys autopilot status [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Autopilot is RUNNING
PID: 12345
Started at: 2026-02-18T10:00:00Z
Last loop at: 2026-02-18T10:05:00Z
Consecutive failures: 0
Failure trend: stable (recent=0, previous=0, window=900s)
Retry distribution: samples=10, 0=8, 1=2, 2+=0, max=1
Cooldown: inactive
Health agent: OK
Health allowlist: OK
Health git: OK
Health review: OK
```

**JSON output:**

```json
{
  "autopilot_running": true,
  "pid": 12345,
  "started_at": "2026-02-18T10:00:00Z",
  "last_loop_at": "2026-02-18T10:05:00Z",
  "consecutive_failures": 0,
  "last_error": null,
  "last_error_class": null,
  "last_error_kind": null,
  "subtask_queue": [],
  "current_subtask": null,
  "stall_reason": null,
  "stall_detail": null,
  "health": {
    "all_ok": true,
    "agent": {"ok": true, "message": "Agent ok"},
    "allowlist": {"ok": true, "message": "Allowlist ok"},
    "git": {"ok": true, "message": "Git ok"},
    "review": {"ok": true, "message": "Review ok"}
  },
  "telemetry": { "...": "..." },
  "health_summary": {
    "failure_trend": {
      "direction": "stable",
      "recent_failures": 0,
      "previous_failures": 0,
      "window_seconds": 900,
      "sample_size": 10,
      "dominant_error_kind": null
    },
    "retry_distribution": {
      "samples": 10,
      "retry_0": 8,
      "retry_1": 2,
      "retry_2_plus": 0,
      "max_retry": 1
    },
    "cooldown": {
      "active": false,
      "total_seconds": 0,
      "remaining_seconds": 0,
      "until": null,
      "source_event": null,
      "reason": null
    }
  },
  "last_step_summary": {
    "step_id": "run-20260218-1",
    "task_id": "alpha-3",
    "subtask_id": null,
    "decision": "approve",
    "event": "orchestrator_run_step",
    "timestamp": "2026-02-18T10:05:00Z"
  }
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot stop

Stop a running autopilot process gracefully.

**Syntax:**

```
genaisys autopilot stop [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Autopilot stopped.
```

**JSON output:**

```json
{"autopilot_stopped": true}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot follow

Follow a running autopilot process by streaming run-log events and periodic status heartbeats to the terminal. Press Ctrl+C to stop following.

**Syntax:**

```
genaisys autopilot follow [path] [--status-interval <s>]
```

**Flags:**

| Flag                      | Description                                          |
|---------------------------|------------------------------------------------------|
| `--status-interval <s>`   | Status heartbeat interval in seconds (default: 5).   |

Note: `--json` is not supported for this command.

**Exit codes:** 0 on normal exit (Ctrl+C), 1 on status load failure.

---

### autopilot smoke

Run an end-to-end smoke test on a temporary project to verify the autopilot pipeline works correctly.

**Syntax:**

```
genaisys autopilot smoke [--cleanup] [--json]
```

**Flags:**

| Flag        | Description                                         |
|-------------|-----------------------------------------------------|
| `--cleanup` | Delete the temporary smoke-test project after success. |
| `--json`    | Output machine-readable JSON.                       |

**Text output:**

```
Autopilot smoke check OK.
Project: /tmp/genaisys_smoke_123
Task: Smoke check: add marker file
Review decision: approve
Task done: true
Commit count: 2
```

**JSON output:**

```json
{
  "autopilot_smoke_ok": true,
  "project_root": "/tmp/genaisys_smoke_123",
  "task_title": "Smoke check: add marker file",
  "review_decision": "approve",
  "task_done": true,
  "commit_count": 2,
  "failures": []
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot simulate

Run a dry-run autopilot step in an isolated workspace. The simulation runs the full pipeline (task selection, coding, review) but does not affect the original project.

**Syntax:**

```
genaisys autopilot simulate [path] [--prompt <text>] [--test-summary <text>] [--min-open <n>] [--max-plan-add <n>] [--overwrite] [--show-patch] [--keep-workspace] [--json]
```

**Flags:**

| Flag                    | Description                                              |
|-------------------------|----------------------------------------------------------|
| `--prompt <text>`       | Base prompt for the coding step.                         |
| `--test-summary <text>` | Optional test summary context.                           |
| `--min-open <n>`        | Minimum open tasks before planner seeds.                 |
| `--max-plan-add <n>`    | Maximum new tasks per step.                              |
| `--overwrite`           | Overwrite plan/spec/subtasks artifacts.                  |
| `--show-patch`          | Show the full diff patch in text output.                 |
| `--keep-workspace`      | Keep the temporary workspace directory after completion. |
| `--json`                | Output machine-readable JSON.                            |

**Text output:**

```
Autopilot simulation completed.
Task: Add telemetry
Task ID: alpha-2
Review: approve
Diff Stats: 1 files, +3, -1
Diff Summary:
 lib/foo.dart | 4 +++-
```

**JSON output:**

```json
{
  "autopilot_simulation_completed": true,
  "project_root": "/path/to/project",
  "workspace_root": null,
  "has_task": true,
  "activated_task": false,
  "planned_tasks_added": 0,
  "task_title": "Add telemetry",
  "task_id": "alpha-2",
  "subtask": null,
  "review_decision": "approve",
  "diff_summary": " lib/foo.dart | 4 +++-",
  "diff_patch": "diff --git ...",
  "diff_stats": {"files_changed": 1, "additions": 3, "deletions": 1},
  "policy_violation": false,
  "policy_message": null
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot improve

Run the self-improvement pipeline: meta-task generation, evaluation harness, and self-tuning of autopilot settings.

**Syntax:**

```
genaisys autopilot improve [path] [--no-meta] [--no-eval] [--no-tune] [--keep-workspaces] [--json]
```

**Flags:**

| Flag                | Description                                       |
|---------------------|---------------------------------------------------|
| `--no-meta`         | Skip meta-task generation.                        |
| `--no-eval`         | Skip the evaluation harness run.                  |
| `--no-tune`         | Skip self-tuning of autopilot settings.           |
| `--keep-workspaces` | Keep temporary evaluation workspaces.             |
| `--json`            | Output machine-readable JSON.                     |

**Text output:**

```
Autopilot self-improvement completed.
Meta tasks created: 3
Created tasks:
- Optimize review prompt for test tasks
- Reduce format drift in CI
- Add retry guidance for policy violations
Eval run: eval-20260218 (8/10, 80.0%)
Eval output: /path/to/project/.genaisys/evals/runs/eval-20260218
Self-tune: applied (80.0%, 10 samples)
Self-tune reason: Success rate above threshold
```

**JSON output:**

```json
{
  "autopilot_improve_completed": true,
  "meta": {
    "created": 3,
    "skipped": 1,
    "created_titles": ["Optimize review prompt", "Reduce format drift", "Add retry guidance"],
    "skipped_titles": ["Already exists"]
  },
  "eval": {
    "run_id": "eval-20260218",
    "run_at": "2026-02-18T10:00:00Z",
    "success_rate": 80.0,
    "passed": 8,
    "total": 10,
    "output_dir": "/path/to/project/.genaisys/evals/runs/eval-20260218",
    "results": [
      {
        "id": "case-1",
        "title": "Add marker file",
        "passed": true,
        "reason": null,
        "review_decision": "approve",
        "policy_violation": false,
        "policy_message": null,
        "diff_stats": {"files_changed": 1, "additions": 2, "deletions": 0}
      }
    ]
  },
  "self_tune": {
    "applied": true,
    "reason": "Success rate above threshold",
    "success_rate": 80.0,
    "samples": 10,
    "before": {"max_task_retries": 3},
    "after": {"max_task_retries": 4}
  }
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot heal

Run an incident-based self-heal step. Collects an incident bundle, applies recovery actions, and optionally re-runs a task cycle.

**Syntax:**

```
genaisys autopilot heal [path] [--reason <code>] [--detail <text>] [--prompt <text>] [--min-open <n>] [--max-plan-add <n>] [--max-task-retries <n>] [--overwrite] [--json]
```

**Flags:**

| Flag                     | Description                                               |
|--------------------------|-----------------------------------------------------------|
| `--reason <code>`        | Incident reason code (e.g., `stuck`, `run_crash`, `review_rejected`). Default: `unknown`. |
| `--detail <text>`        | Optional incident detail text.                            |
| `--prompt <text>`        | Optional prompt override for the heal step.               |
| `--min-open <n>`         | Minimum open tasks before planner seeds.                  |
| `--max-plan-add <n>`     | Maximum new tasks per step.                               |
| `--max-task-retries <n>` | Retry limit for the heal step.                            |
| `--overwrite`            | Overwrite plan/spec/subtasks artifacts.                   |
| `--json`                 | Output machine-readable JSON.                             |

**Text output:**

```
Autopilot incident heal completed.
Reason: stuck
Detail: No productive steps in recent segments.
Incident bundle: /path/.genaisys/attempts/incident-heal-2026-02-18T15-00-00.000Z.json
Recovered: false
Executed cycle: true
Review decision: (none)
Retry count: 1
Planned tasks added: 0
Task blocked: false
Activated task: false
Deactivated task: false
```

**JSON output:**

```json
{
  "autopilot_heal_completed": true,
  "bundle_path": "/path/.genaisys/attempts/incident-heal-2026-02-18T15-00-00.000Z.json",
  "reason": "stuck",
  "detail": "No productive steps in recent segments.",
  "executed_cycle": true,
  "recovered": false,
  "activated_task": false,
  "deactivated_task": false,
  "task_blocked": false,
  "planned_tasks_added": 0,
  "retry_count": 1,
  "review_decision": null,
  "active_task_id": "alpha-2",
  "active_task": "Fix scheduler loop",
  "subtask_id": null
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot candidate

Run release-candidate gates: check for required files, open P1 blockers, and optionally run test/analysis suites.

**Syntax:**

```
genaisys autopilot candidate [path] [--skip-suites] [--json]
```

**Flags:**

| Flag            | Description                                              |
|-----------------|----------------------------------------------------------|
| `--skip-suites` | Skip analyzer/test suites; check only files and blockers.|
| `--json`        | Output machine-readable JSON.                            |

**Text output (passed):**

```
Autopilot release-candidate gates passed.
Suite commands:
- [PASS] dart analyze (1200ms, exit=0)
- [PASS] dart test (8500ms, exit=0)
```

**Text output (failed):**

```
Autopilot release-candidate gates failed.
Open P1 blockers in release-critical areas:
- [P1] [CORE] Fix critical race condition
```

**JSON output:**

```json
{
  "autopilot_candidate_completed": true,
  "passed": true,
  "skip_suites": false,
  "missing_files": [],
  "missing_done_blockers": [],
  "open_critical_p1_lines": [],
  "commands": [
    {
      "command": "dart analyze",
      "ok": true,
      "exit_code": 0,
      "timed_out": false,
      "duration_ms": 1200,
      "stdout_excerpt": "No issues found!",
      "stderr_excerpt": ""
    }
  ]
}
```

**Exit codes:** 0 if gates pass, 1 if gates fail, 2 on state error.

---

### autopilot pilot

Run a controlled, time-boxed unattended pilot run on a dedicated branch with a full report.

**Syntax:**

```
genaisys autopilot pilot [path] [--duration <2h|30m|120s>] [--max-cycles <n>] [--branch <name>] [--prompt <text>] [--skip-candidate] [--auto-fix-format-drift] [--json]
```

**Flags:**

| Flag                        | Description                                                |
|-----------------------------|------------------------------------------------------------|
| `--duration <time>`         | Time box for the pilot run (default: `2h`). Accepts `Nh`, `Nm`, `Ns`. |
| `--max-cycles <n>`          | Hard cycle limit (default: 120).                           |
| `--branch <name>`           | Target branch name (default: `feat/pilot-<timestamp>`).    |
| `--prompt <text>`           | Prompt override for the pilot run.                         |
| `--skip-candidate`          | Skip release-candidate gates before the run.               |
| `--auto-fix-format-drift`   | Run optional format baselining before candidate gates.     |
| `--json`                    | Output machine-readable JSON.                              |

**Text output:**

```
Autopilot pilot run completed.
Branch: feat/pilot-20260218-120000
Duration seconds: 7200
Max cycles: 120
Command exit code: 0
Timed out: false
Report: /path/.genaisys/logs/pilot_run_report_20260218-120001.md
Total steps: 15
Successful steps: 12
Idle steps: 2
Failed steps: 1
Stopped by max steps: false
Stopped when idle: false
Stopped by safety halt: false
```

**JSON output:**

```json
{
  "autopilot_pilot_completed": true,
  "passed": true,
  "timed_out": false,
  "command_exit_code": 0,
  "branch": "feat/pilot-20260218-120000",
  "duration_seconds": 7200,
  "max_cycles": 120,
  "report_path": "/path/.genaisys/logs/pilot_run_report_20260218-120001.md",
  "run": {
    "total_steps": 15,
    "successful_steps": 12,
    "idle_steps": 2,
    "failed_steps": 1,
    "stopped_by_max_steps": false,
    "stopped_when_idle": false,
    "stopped_by_safety_halt": false
  },
  "error": null
}
```

**Exit codes:** 0 if passed, 1 if failed, 2 on state error.

---

### autopilot cleanup-branches

Delete merged autopilot feature branches (local and optionally remote).

**Syntax:**

```
genaisys autopilot cleanup-branches [path] [--base <branch>] [--remote <name>] [--include-remote] [--dry-run] [--json]
```

**Flags:**

| Flag                 | Description                                            |
|----------------------|--------------------------------------------------------|
| `--base <branch>`    | Base branch to compare against (default: auto-detect). |
| `--remote <name>`    | Remote name (default: `origin`).                       |
| `--include-remote`   | Also delete merged remote branches.                    |
| `--dry-run`          | List branches that would be deleted without deleting.  |
| `--json`             | Output machine-readable JSON.                          |

**Text output:**

```
Autopilot branch cleanup completed.
Base branch: main
Dry run: false
Deleted local branches: 3
- feat/task-alpha-1
- feat/task-alpha-2
- feat/task-alpha-3
```

**JSON output:**

```json
{
  "autopilot_branch_cleanup_completed": true,
  "base_branch": "main",
  "dry_run": false,
  "deleted_local_branches": ["feat/task-alpha-1", "feat/task-alpha-2"],
  "deleted_remote_branches": [],
  "skipped_branches": [],
  "failures": []
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot diagnostics

Display autopilot diagnostic information including error patterns, forensic state, recent events, and [supervisor](../glossary.md#supervisor) status.

**Syntax:**

```
genaisys autopilot diagnostics [path] [--json]
```

**Flags:**

| Flag     | Description                   |
|----------|-------------------------------|
| `--json` | Output machine-readable JSON. |

**Text output:**

```
Autopilot Diagnostics

Error Patterns (top 3):
  quality_gate_failed: 5 occurrences (2 auto-resolved) last seen: 2026-02-18T10:00:00Z
    strategy: Retry with focused test execution
  safe_write_violation: 2 occurrences (0 auto-resolved) last seen: 2026-02-17T15:00:00Z

Forensic State:
  classification: persistentTestFailure
  suggested_action: retryWithGuidance

Recent Events (last 10):
  [2026-02-18T10:05:00Z] orchestrator_run_step: Step completed
  [2026-02-18T10:04:00Z] review_approve: Review approved

Supervisor Status:
  running: true
  session_id: supervisor-20260218
```

**JSON output:**

```json
{
  "error_patterns": [
    {
      "error_kind": "quality_gate_failed",
      "count": 5,
      "last_seen": "2026-02-18T10:00:00Z",
      "auto_resolved_count": 2,
      "resolution_strategy": "Retry with focused test execution"
    }
  ],
  "forensic_state": {"classification": "persistentTestFailure", "suggested_action": "retryWithGuidance"},
  "recent_events": [
    {"timestamp": "2026-02-18T10:05:00Z", "event": "orchestrator_run_step", "message": "Step completed"}
  ],
  "supervisor_status": {"running": true, "session_id": "supervisor-20260218"}
}
```

**Exit codes:** 0 on success, 2 on state error.

---

### autopilot supervisor

Manage the unattended [supervisor](../glossary.md#supervisor) lifecycle. The supervisor wraps `autopilot run` with automatic restart, throughput guardrails, and progress monitoring.

#### autopilot supervisor start

**Syntax:**

```
genaisys autopilot supervisor start [path] [--profile <pilot|overnight|longrun|sprint>] [--prompt <text>] [--reason <text>] [--max-restarts <n>] [--restart-backoff-base <s>] [--restart-backoff-max <s>] [--low-signal-limit <n>] [--throughput-window-minutes <n>] [--throughput-max-steps <n>] [--throughput-max-rejects <n>] [--throughput-max-high-retries <n>] [--json]
```

**Flags:**

| Flag                              | Default       | Description                                          |
|-----------------------------------|---------------|------------------------------------------------------|
| `--profile <name>`                | `overnight`   | Supervisor profile: `pilot`, `overnight`, `longrun`, or `sprint`. The `sprint` profile sets `stopWhenIdle: false` so `SprintPlannerService` controls termination. |
| `--prompt <text>`                 | (auto)        | Optional prompt override for supervisor segments.    |
| `--reason <text>`                 | `manual_start`| Start reason (recorded in run log).                  |
| `--max-restarts <n>`              | 3             | Max consecutive restart attempts before halt.        |
| `--restart-backoff-base <s>`      | 5             | Exponential backoff base in seconds.                 |
| `--restart-backoff-max <s>`       | 90            | Backoff ceiling in seconds.                          |
| `--low-signal-limit <n>`          | 3             | Low-signal segments before progress watchdog halt.   |
| `--throughput-window-minutes <n>` | 30            | Rolling window for throughput accounting.            |
| `--throughput-max-steps <n>`      | 200           | Max steps allowed in window.                         |
| `--throughput-max-rejects <n>`    | 10            | Max rejects/failures in window.                      |
| `--throughput-max-high-retries <n>` | 20          | Max retry-2+ escalations in window.                  |
| `--json`                          |               | Output machine-readable JSON.                        |

**Text output:**

```
Autopilot supervisor started.
Session id: supervisor-20260218-100000
Profile: overnight
Supervisor PID: 12345
Resume action: continue_safe_step
```

**JSON output:**

```json
{
  "autopilot_supervisor_started": true,
  "session_id": "supervisor-20260218-100000",
  "profile": "overnight",
  "supervisor_pid": 12345,
  "resume_action": "continue_safe_step"
}
```

#### autopilot supervisor status

**Syntax:**

```
genaisys autopilot supervisor status [path] [--json]
```

**Text output:**

```
Supervisor is RUNNING
Session id: supervisor-20260218-100000
Profile: overnight
Start reason: manual_start
Worker PID: 12345
Started at: 2026-02-18T10:00:00Z
Restart count: 0
Cooldown until: (none)
Last halt reason: (none)
Last resume action: continue_safe_step
Last exit code: (none)
Low-signal streak: 0
Throughput window started: 2026-02-18T10:00:00Z
Throughput steps: 15
Throughput rejects: 1
Throughput high retries: 0
Autopilot running: true
Autopilot PID: 12346
Autopilot last loop: 2026-02-18T10:05:00Z
Autopilot consecutive failures: 0
Autopilot last error: (none)
```

**JSON output:**

```json
{
  "autopilot_supervisor_running": true,
  "session_id": "supervisor-20260218-100000",
  "profile": "overnight",
  "start_reason": "manual_start",
  "supervisor_pid": 12345,
  "started_at": "2026-02-18T10:00:00Z",
  "restart_count": 0,
  "cooldown_until": null,
  "last_halt_reason": null,
  "last_resume_action": "continue_safe_step",
  "last_exit_code": null,
  "low_signal_streak": 0,
  "throughput": {
    "window_started_at": "2026-02-18T10:00:00Z",
    "steps": 15,
    "rejects": 1,
    "high_retries": 0
  },
  "autopilot": {
    "running": true,
    "pid": 12346,
    "last_loop_at": "2026-02-18T10:05:00Z",
    "consecutive_failures": 0,
    "last_error": null
  }
}
```

#### autopilot supervisor stop

**Syntax:**

```
genaisys autopilot supervisor stop [path] [--reason <text>] [--json]
```

**Flags:**

| Flag              | Default       | Description                            |
|-------------------|---------------|----------------------------------------|
| `--reason <text>` | `manual_stop` | Stop reason (recorded in run log).     |
| `--json`          |               | Output machine-readable JSON.          |

**Text output:**

```
Autopilot supervisor stopped.
Reason: manual_stop
```

**JSON output:**

```json
{
  "autopilot_supervisor_stopped": true,
  "was_running": true,
  "reason": "manual_stop"
}
```

#### autopilot supervisor restart

Takes the same flags as `autopilot supervisor start`. Performs a stop followed by a start atomically.

**Syntax:**

```
genaisys autopilot supervisor restart [path] [--profile <name>] [--prompt <text>] [--reason <text>] [--max-restarts <n>] [...] [--json]
```

**Exit codes for all supervisor subcommands:** 0 on success, 64 if subcommand is missing, 2 on state error.

---

## `hitl` — Human-in-the-Loop Gates

Interact with HITL gates that the autopilot opens at configured checkpoints.

**Usage:**
```
genaisys hitl <subcommand> [path] [--json] [--note <text>]
```

| Subcommand | Description |
|------------|-------------|
| `status` | Show the current pending gate (if any). |
| `approve` | Approve the gate — autopilot continues. |
| `skip` | Alias for `approve`. |
| `reject` | Reject the gate — autopilot terminates cleanly with reason `hitl_rejected`. |

**Examples:**
```bash
genaisys hitl status /project
# HITL gate pending: before_sprint
#   sprint:  2
#   expires: 2026-03-01T15:30:00.000Z
#   →  genaisys hitl approve /project
#   →  genaisys hitl reject  /project

genaisys hitl approve /project --note "Sprint 2 looks good"
genaisys hitl reject  /project --note "I'll fix this manually"
```

**`--json` output:**
```json
{"pending": true, "event": "before_sprint", "sprint_number": 2, "expires_at": "2026-03-01T15:30:00.000Z"}
```

**Exit codes:** 0 on success, 64 on usage error.

---

## JSON Contract

- **Contract version:** v1
- All `--json` outputs write exactly one JSON line to stdout.
- Error responses always follow: `{"error": "<message>", "code": "<error_code>"}`
- Existing field names and types are stable. New fields may be added (additive only).
- Removing, renaming, or changing field types requires a new major version (v2).
- Clients should ignore unknown fields to allow forward compatibility.

## Output Sanitization

All CLI output (stdout and stderr) is routed through a sanitization sink that redacts secrets, tokens, and sensitive patterns before they reach the terminal or piped consumers.

---

## Related Documentation

- [Quickstart](../guide/quickstart.md) -- Get running in minutes
- [Autonomous Execution](../guide/autonomous-execution.md) -- Running the autopilot
- [Exit Codes](exit-codes.md) -- Complete exit code table
- [Configuration Reference](configuration-reference.md) -- All config keys
