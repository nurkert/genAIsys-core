[Home](../README.md) > [Concepts](./README.md) > Task Lifecycle

# Task Lifecycle

How [tasks](../glossary.md#task) move through the Genaisys orchestration pipeline from backlog to completion.

---

## Task States

| State | Marker | Description |
|-------|--------|-------------|
| Open | `- [ ]` | Available for activation |
| Active | (in STATE.json) | Currently being worked on |
| Blocked | `- [b]` | Cannot proceed, requires intervention |
| Done | `- [x]` | Completed and delivered |

## State Transitions

```
                    ┌──────────┐
                    │   Open   │
                    └────┬─────┘
                         │ activate
                         ▼
                    ┌──────────┐
              ┌────►│  Active  │◄────┐
              │     └────┬─────┘     │
              │          │           │
              │    ┌─────┴─────┐     │
              │    ▼           ▼     │
         ┌─────────┐    ┌──────────┐ │
         │ Blocked │    │ Review   │ │
         └─────────┘    └────┬─────┘ │
                             │       │
                       ┌─────┴─────┐ │
                       ▼           ▼ │
                 ┌──────────┐  reject
                 │   Done   │  (retry)
                 └──────────┘
```

### Key Transitions

- **Open → Active**: The orchestrator selects a task based on the configured selection mode, creates a feature branch, and sets it as active in STATE.json.
- **Active → Review**: After the coding agent produces a diff and the quality gate passes, the review agent assesses the changes.
- **Review → Done**: On approval, changes are committed, merged to the base branch, and the task is marked done in TASKS.md.
- **Review → Active (retry)**: On rejection, the task receives feedback and re-enters the coding phase. A retry counter is incremented.
- **Active → Blocked**: When retry budget is exhausted, forensic analysis fails, or manual blocking is requested.
- **Blocked → Open**: Manual unblocking or automatic reactivation (if `reactivate_blocked` is enabled).

## Task Format

Tasks are defined in `.genaisys/TASKS.md` using checkbox Markdown:

```markdown
## Section Name

- [ ] [P1] [CORE] Task title here
- [x] [P2] [QA] Completed task
- [b] [P3] [GUI] Blocked task (reason: missing dependency)
```

### Priority Levels

| Priority | Weight (default) | Description |
|----------|-----------------|-------------|
| P1 | 3 | Critical — must be done first |
| P2 | 2 | Important — standard work |
| P3 | 1 | Nice-to-have — lower urgency |

### Categories

`CORE`, `QA`, `SEC`, `GUI`, `DOCS`, `UI`, `INTERACTION`, and custom categories.

## Selection Modes

| Mode | Config Value | Behavior |
|------|-------------|----------|
| Strict Priority | `strict_priority` | Always picks highest P first |
| Fair | `fair` | Priority-weighted with fairness window |
| Round Robin | `round_robin` | Cycles through tasks regardless of priority |

The **fair** mode uses configurable weights (`priority_weight_p1/p2/p3`) and a fairness window (`fairness_window`) to balance urgency with preventing starvation of lower-priority tasks.

## Retry Budget

Each task has a retry budget controlled by `autopilot.max_task_retries` (default: 3).

When a review rejects a task:
1. The retry counter increments
2. Rejection feedback is injected into the next coding prompt
3. The task re-enters the coding phase

When the retry budget is exhausted:
1. **Forensic analysis** classifies the failure pattern
2. Based on classification: redecompose, regenerate spec, retry with guidance, or block
3. If blocked, the task is marked `- [b]` with a reason

## Cooldowns

After a task is blocked or fails, a cooldown period prevents immediate reactivation:

| Config Key | Default | Description |
|-----------|---------|-------------|
| `blocked_cooldown_seconds` | 0 | Wait time before blocked tasks become eligible |
| `failed_cooldown_seconds` | 0 | Wait time before failed tasks become eligible |

## Reactivation

| Config Key | Default | Description |
|-----------|---------|-------------|
| `reactivate_blocked` | false | Automatically unblock tasks after cooldown |
| `reactivate_failed` | true | Automatically retry failed tasks after cooldown |

---

## Related Documentation

- [Orchestration Lifecycle](orchestration-lifecycle.md) — The grand delivery cycle
- [State Machine](state-machine.md) — Orchestrator loop phases
- [Task Management](../guide/task-management.md) — How to manage the backlog
- [Subtask Decomposition](subtask-decomposition.md) — Breaking tasks into subtasks
- [STATE.json Schema](../reference/state-json-schema.md) — Active task fields
