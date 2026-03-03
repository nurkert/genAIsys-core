[Home](../README.md) > [Concepts](./README.md) > Review Escalation

# Review Escalation

Review escalation governs how the orchestrator responds when a task is rejected — increasing scrutiny, narrowing scope, and accumulating evidence across retries to break reject loops and maintain unattended progress.

---

## Overview

A single task can be retried multiple times before the system blocks it or escalates to forensics. Each retry carries more evidence than the last:

```
First attempt (retryCount=0)
│   normalReview mode
│   Full diff, no advisory notes
│
Reject → retryCount++ → retryWithGuidance
│   verificationReview mode
│   Delta-diff from rejection SHA
│   Advisory notes injected
│   Reactive subtask split may trigger
│
Reject again → budget exhausted
    → TaskForensicsService
```

---

## Delta-Diff Bookmarking

On every review rejection the orchestrator records `lastRejectCommitSha` — the HEAD commit SHA at the moment of rejection.

On the next retry, `BuildReviewBundle` detects that `lastRejectCommitSha` differs from the current HEAD and requests a **delta diff**: only the changes made since the rejection commit are shown to the reviewer. This focuses attention on what changed between the last failed attempt and the current one, not the entire task history.

If `lastRejectCommitSha` is no longer reachable (e.g. after a force-push or history rewrite), the bundle falls back to the full working-tree diff automatically.

---

## Review Mode Escalation

| retryCount | Review Mode | Description |
|-----------|-------------|-------------|
| 0 | `normalReview` | Standard review of the full diff |
| ≥ 1 | `verificationReview` | Stricter review; reviewer receives prior reject notes and delta diff |

In `verificationReview` mode the review agent is explicitly told that a previous attempt was rejected and is given the prior rejection evidence. This prevents the reviewer from approving code that previously failed without addressing the noted issues.

---

## Advisory Notes

Advisory notes are structured hints accumulated from reviewer feedback across subtasks. They are injected into the next coding cycle's prompt so the agent is explicitly aware of what the reviewer did not like.

Rules:
- Each rejection appends the reviewer's notes to the advisory set.
- The advisory set is capped at **6 entries** across subtask boundaries.
- Notes are cleared when the task fully completes (approve + delivery).
- Notes persist even when a new subtask starts, so the agent carries cross-subtask institutional knowledge about the reviewer's expectations.

---

## Contract Notes

Contract notes are immutable constraints extracted from the task specification. Unlike advisory notes (which come from reviewer feedback), contract notes encode the **requirements** — what must be true when the task is done.

When a `StageEarlyReturn(noDiff)` occurs, contract notes are preserved in the run log (`task_cycle_no_diff` event) so they are available for injection on the next retry, even though the working tree was clean.

---

## Reactive Subtask Split

If a rejection reason contains keywords indicating scope complexity (e.g. "too many files", "scope too large", "split this", "separate concern"), the orchestrator may trigger a **reactive subtask split**:

1. The current subtask is retired.
2. An LLM call generates 2–4 smaller subtasks from the original scope.
3. The new subtasks are prepended to the task's subtask queue.
4. The next step works on the first new subtask instead of retrying the original.

This is the primary mechanism for adapting to unexpectedly large or complex task specifications without operator intervention. It is governed by:

| Config key | Default | Description |
|-----------|---------|-------------|
| `pipeline.reactive_split_enabled` | `true` | Enable reactive subtask split |
| `pipeline.reactive_split_keywords` | (built-in list) | Keywords that trigger split detection |
| `pipeline.reactive_split_max_subtasks` | 4 | Maximum subtasks produced per split |

---

## Contract Lock

At `retryCount ≥ 1`, the orchestrator applies a **contract lock** — the review mode switches to `verificationReview` and the coding prompt is constrained to only the specific changes called out in the prior rejection notes.

This prevents the agent from attempting to broaden scope or rewrite unrelated code on retries. The coding agent receives:
- Exact lines and files from the rejection note
- Prior advisory notes
- Explicit instruction not to modify files outside the rejection scope

The contract lock is released when:
- The task approves (retryCount resets to 0 on a new task)
- A reactive subtask split occurs (new subtasks start at retryCount=0)
- The task is blocked by forensics (no further attempts)

---

## Retry Budget

The retry budget is enforced at the task level:

| Config key | Default | Description |
|-----------|---------|-------------|
| `autopilot.max_task_retries` | 3 | Max retries per subtask before forensics |
| `autopilot.stuck_cooldown_seconds` | 60 | Cooldown between retry attempts |

When `retryCount` exceeds `max_task_retries`, `TaskForensicsService` is invoked to classify the failure and decide whether to block, redecompose, or escalate. See [Forensic Recovery Advanced](./forensic-recovery-advanced.md).

---

## Reject Archival Invariant

On every rejection, the dirty working tree is archived using `git stash` with a structured stash message that includes:

- Task ID and subtask index
- Rejection reason
- Retry count
- Timestamp

This stash is never automatically dropped and is retained for forensic inspection. The working tree is guaranteed to be clean after archival — enforcing the [Clean-End Invariant](../CLAUDE.md#8-unattended-anti-block-invariants).

---

## Related Documentation

- [Pipeline Stages](./pipeline-stages.md) — How the 12-stage pipeline produces the review bundle
- [Task Lifecycle](./task-lifecycle.md) — Task states and retry transitions
- [Forensic Recovery Advanced](./forensic-recovery-advanced.md) — What happens when retries are exhausted
- [Safety System](./safety-system.md) — Policy enforcement (Safe-Write, Diff Budget)
- [Review System](./review-system.md) — Review policy and evidence structure
