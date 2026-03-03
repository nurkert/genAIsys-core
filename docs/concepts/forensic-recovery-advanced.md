[Home](../README.md) > [Concepts](./README.md) > Forensic Recovery (Advanced)

# Forensic Recovery (Advanced)

Forensic recovery is the last line of defense before a task is permanently blocked. It activates when a task exhausts its retry budget and uses a two-pass analysis system to classify the failure and decide the least-disruptive recovery path.

---

## Overview

When `retryCount` exceeds `autopilot.max_task_retries`, `TaskForensicsService` runs before the task is blocked:

```
retryCount > max_task_retries
        │
        ▼
   Pass 1: Pattern Classification
   (zero-token, deterministic)
        │
        ├─► Clear classification → apply action
        │
        └─► Ambiguous / unknown
                │
                ▼
           Pass 2: Forced Narrowing
           (LLM-assisted, structured)
                │
                └─► block (final fallback)
```

---

## Pass 1 — Pattern Classification

The first pass is **zero-cost** — it uses no LLM tokens and makes no external calls. It inspects the accumulated reject evidence (error kinds, review notes, required file counts) against a fixed rule table:

| Classification | Trigger Pattern | Default Action |
|---------------|----------------|----------------|
| `policyConflict` | Error kinds include `diff_budget_exceeded`, `safe_write_violation`, or `policy_violation` | `block` |
| `persistentTestFailure` | Error kinds include `quality_gate`, `test_failure`, or `analyze_failed` | `retryWithGuidance` |
| `specTooLarge` | Required file count > 5, or review notes contain scope/size keywords | `redecompose` |
| `specIncorrect` | Review notes mention "wrong file", "missing file", or "incorrect spec" | `regenerateSpec` |
| `codingApproachWrong` | Review notes mention "wrong approach" or "different strategy" | `retryWithGuidance` |
| `unknown` | No clear pattern identified | `block` |

If a classification is matched, the action is applied immediately without entering Pass 2.

---

## Pass 2 — Forced Narrowing

When Pass 1 yields `unknown` or when the classification is ambiguous, the system enters **Forced Narrowing** — a structured LLM call that receives:

- The full reject history (all rejection notes from all attempts)
- The task specification
- The diff from the last attempt
- A constrained output schema (must return one of the valid action codes)

Forced Narrowing is designed to handle edge cases that the deterministic rule table cannot classify. It is bounded by:

- A strict output schema (prevents hallucination of novel action codes)
- A short token budget (no multi-turn reasoning)
- A single-attempt limit (no retry loop within forensics)

If Forced Narrowing fails or returns an invalid action, the final fallback is `block`.

---

## Unattended Mode Behavior

In unattended autopilot runs, some forensic actions behave differently:

| Action | Interactive Mode | Unattended Mode |
|--------|-----------------|-----------------|
| `block` | Task blocked, user notified | Task blocked, run continues with next task |
| `redecompose` | LLM generates new subtasks | LLM generates new subtasks (same) |
| `regenerateSpec` | LLM rewrites task spec | LLM rewrites task spec (same) |
| `retryWithGuidance` | Retry with injected guidance notes | **Silently blocked** — operator guidance required |

The `retryWithGuidance` → block substitution in unattended mode is intentional. Guidance retry assumes a human can intervene if the guidance is insufficient. In fully unattended mode, repeated guidance retries without human input can produce open-ended token burn. The task is blocked instead and the run log records `forensics_action_blocked_in_unattended_mode`.

---

## Action Details

### `block`

The task is marked as `blocked` in STATE.json with a `forensics_blocked` reason. The orchestrator skips it on all subsequent steps until the operator manually unblocks it via `genaisys tasks unblock <id> /path`.

The run log records a `task_forensics_block` event with the full classification evidence.

### `redecompose`

Used when the task specification is too large or complex for a single delivery cycle.

1. The task spec is sent to the LLM with a decomposition prompt.
2. The LLM returns 2–5 smaller tasks that together cover the original scope.
3. The new tasks are inserted into the backlog as successors of the original.
4. The original task is retired (not blocked — it succeeded in producing a plan).

`redecompose` differs from the reactive subtask split triggered during review: reactive splits happen mid-retry based on reviewer feedback; `redecompose` happens post-budget-exhaustion and produces independent backlog tasks rather than subtask queue entries.

### `regenerateSpec`

Used when the task specification itself is incorrect (wrong files, wrong assumptions).

1. The task spec is sent to the LLM with the rejection evidence.
2. The LLM produces a corrected specification.
3. The task is reset to `planned` state with the new spec and a fresh retry budget.

This allows the system to self-correct bad task definitions without operator intervention.

### `retryWithGuidance`

Used when the coding approach was wrong but the spec is sound.

1. The forensics module distills the rejection notes into explicit guidance.
2. The guidance is injected as a high-priority constraint into the next coding prompt.
3. The retry budget is partially refilled (typically +1 attempt).

In unattended mode this action is replaced with `block` (see above).

---

## Preflight Repair Loop

A separate forensic-like loop governs preflight failures. When consecutive preflight checks fail:

```
consecutivePreflightFailures >= 5
        │
        ▼
   StateRepairService.repair()
        │
        ├─► Repair succeeded → reset counter, continue
        │
        └─► Repair failed → repairAttempts++
                │
                ├─► repairAttempts < 3 → retry repair
                │
                └─► repairAttempts >= 3 → terminate(preflight_irrecoverable)
```

`StateRepairService` handles known corruption patterns:
- STATE.json schema violations (field type mismatches)
- Stale lock files from crashed processes
- Corrupted task index (duplicate IDs, broken parent links)
- Merge-in-progress state without corresponding git merge (auto-aborts)

Each repair attempt is logged as `state_repair_attempt` with the patterns found and actions taken. If three consecutive repair attempts all fail, the run terminates with `preflight_irrecoverable` — a human operator must inspect the project state.

---

## Run Log Events

| Event | When |
|-------|------|
| `task_forensics_start` | Forensic analysis begins |
| `task_forensics_classified` | Pass 1 produced a match |
| `task_forensics_forced_narrowing` | Pass 2 (LLM) invoked |
| `task_forensics_block` | Task blocked |
| `task_forensics_redecompose` | Task decomposed into subtasks |
| `task_forensics_regenerate_spec` | Spec regenerated |
| `task_forensics_retry_guidance` | Retry with guidance injected |
| `forensics_action_blocked_in_unattended_mode` | retryWithGuidance → block substitution |
| `state_repair_attempt` | StateRepairService invoked |
| `preflight_irrecoverable` | Repair budget exhausted |

---

## Related Documentation

- [Unattended Operations](../guide/unattended-operations.md) — Supervisor profiles, forensics table, incident handling
- [Task Lifecycle](./task-lifecycle.md) — Task states, block, and unblock transitions
- [Review Escalation](./review-escalation.md) — Retry and escalation before forensics
- [Pipeline Stages](./pipeline-stages.md) — The 12-stage pipeline that produces reject evidence
- [Self-Improvement](./self-improvement.md) — Error pattern learning from forensic data
