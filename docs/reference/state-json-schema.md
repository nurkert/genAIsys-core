[Home](../README.md) > [Reference](./README.md) > STATE.json Schema

# STATE.json Schema

Complete schema for `.genaisys/STATE.json` — the runtime state file.

---

## Overview

STATE.json tracks the orchestrator's current state: active task, workflow stage, review status, cycle counters, and supervisor state. It is schema-validated on every read ([fail-closed](../glossary.md#fail-closed)) and written with atomic operations (temp + flush + replace).

STATE.json is a runtime artifact — it is excluded from git via `.genaisys/.gitignore`.

## Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `activeTask` | `string?` | Title of the currently active task |
| `activeTaskId` | `string?` | ID of the currently active task |
| `activeTaskSection` | `string?` | Section containing the active task |
| `workflowStage` | `string` | Current workflow phase: `idle`, `planning`, `coding`, `reviewing`, `delivering` |
| `cycleCount` | `int` | Total cycle counter |
| `lastUpdated` | `string` | ISO 8601 timestamp of last state update |

## Review Fields

| Field | Type | Description |
|-------|------|-------------|
| `reviewStatus` | `string?` | `approved`, `rejected`, or `null` |
| `reviewUpdatedAt` | `string?` | ISO 8601 timestamp of last review action |
| `reviewNote` | `string?` | Note attached to last review decision |

## Error Fields

| Field | Type | Description |
|-------|------|-------------|
| `lastError` | `string?` | Last error message |
| `lastErrorClass` | `string?` | Error classification |
| `lastErrorKind` | `string?` | Specific error type |

## Autopilot Fields

| Field | Type | Description |
|-------|------|-------------|
| `autopilotRunning` | `bool` | Whether an autopilot process is active |
| `autopilotPid` | `int?` | PID of the running autopilot |
| `autopilotStartedAt` | `string?` | ISO 8601 start timestamp |
| `autopilotLastLoopAt` | `string?` | ISO 8601 last loop timestamp |
| `consecutiveFailures` | `int` | Unbroken failure streak |

## Supervisor Fields

| Field | Type | Description |
|-------|------|-------------|
| `supervisorRunning` | `bool` | Whether a supervisor is active |
| `supervisorSessionId` | `string?` | Current session identifier |
| `supervisorProfile` | `string?` | Active profile (pilot/overnight/longrun) |
| `supervisorStartReason` | `string?` | Why the supervisor was started |
| `supervisorLastResumeAction` | `string?` | Last resume policy applied |
| `supervisorLastHaltReason` | `string?` | Why the supervisor last halted |

## Subtask Fields

| Field | Type | Description |
|-------|------|-------------|
| `subtaskQueue` | `List<string>` | Ordered subtask identifiers |
| `currentSubtask` | `string?` | Currently active subtask |
| `subtaskRetryCount` | `int` | Retries for current subtask |

## Health Fields

| Field | Type | Description |
|-------|------|-------------|
| `healthAgent` | `string` | Agent health status |
| `healthAllowlist` | `string` | Allowlist health status |
| `healthGit` | `string` | Git health status |
| `healthReview` | `string` | Review health status |

## Workflow Stage Transitions

```
idle → planning → coding → reviewing → delivering → idle
                     ↑          │
                     └── reject ┘
```

| Stage | Description |
|-------|-------------|
| `idle` | No active work |
| `planning` | Generating spec/plan/subtasks |
| `coding` | Coding agent running |
| `reviewing` | Review agent assessing diff |
| `delivering` | Committing, pushing, merging |

---

## Related Documentation

- [Data Contracts](data-contracts.md) — All `.genaisys/` artifacts
- [State Machine](../concepts/state-machine.md) — Orchestrator phases
- [Task Lifecycle](../concepts/task-lifecycle.md) — Task state transitions
