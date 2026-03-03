[Home](../README.md) > [Concepts](./README.md) > Pipeline Stages

# Pipeline Stages

The Genaisys [task pipeline](../glossary.md#task-pipeline) is the inner execution engine that runs inside every orchestrator step. It is a sequential 12-stage pipeline that transforms a coding-agent response into a verified, reviewed delivery — or rejects it with machine-readable evidence.

---

## Overview

The pipeline is invoked by `TaskCycleService` once per step cycle. Each stage runs in order. A stage can:

- **Continue** — pass control to the next stage
- **EarlyReturn** — exit the pipeline early with a specific outcome (e.g. noDiff, noProgress)
- **Reject** — fail the delivery with a structured reason; triggers retry or forensics
- **ReviewComplete** — signal that review succeeded; pipeline exits cleanly

```
NoDiffCheck ──► SafeWrite ──► AutoFormat ──► PostFormatNoDiffCheck
     │                                              │
     │                                              ▼
     │                                         TestDeltaGate
     │                                              │
     │                                              ▼
     │                                          DiffBudget
     │                                              │
     │                                              ▼
     │                                      BuildReviewBundle
     │                                              │
     │                                              ▼
     │                                       RequiredFiles
     │                                              │
     │                                              ▼
     │                                         QualityGate
     │                                              │
     │                                              ▼
     │                                      ArchitectureGate
     │                                              │
     │                                              ▼
     │                                         AcSelfCheck
     │                                              │
     │                                              ▼
     └──────────────────────────────────────► ReviewAgent
```

---

## Stage Reference

### Stage 1 — NoDiffCheck

**Purpose**: Detect no-progress before doing any verification work.

The stage inspects the working tree. If the agent produced no file changes at all (empty diff), it immediately returns `StageEarlyReturn(noDiff: true)`. This is recorded as a no-progress step and counts against the retry budget.

**Early exit**: `noDiff` → pipeline aborts, step marked as no-progress.

---

### Stage 2 — SafeWrite

**Purpose**: Enforce the [safe-write policy](../concepts/safety-system.md).

Validates that every file modified by the agent is within an allowed root path (defined in `policies.safe_write.allowed_roots`). Files outside the allow-list are rejected immediately.

**Reject reason**: `safe_write_violation` with the exact violating path.

---

### Stage 3 — AutoFormat

**Purpose**: Apply automatic code formatting before quality checks.

Runs the project's formatter (e.g. `dart format .`) automatically. This ensures that pure format drift does not produce reject loops — the formatter corrects trivial style differences so quality-gate format checks can focus on real violations.

Auto-format only runs if the quality gate is enabled. Its output is staged before continuing.

---

### Stage 4 — PostFormatNoDiffCheck

**Purpose**: Check for diff collapse after auto-format.

After formatting, if the working tree is clean (the agent's only changes were formatting that the formatter already applied), this is treated as no-progress. Returns `StageEarlyReturn(noDiff: true)` so the step is not counted as a false success.

---

### Stage 5 — TestDeltaGate

**Purpose**: Run a targeted pre-check using only tests related to changed files.

When `policies.quality_gate.test_delta_gate_enabled` is true, the stage computes which test files correspond to the changed source files and runs only those tests first. This provides fast-fail feedback before the full quality gate. If the targeted tests fail, the stage rejects without running the full suite.

**Reject reason**: `test_delta_failure` — delta tests failed before full quality gate.

---

### Stage 6 — DiffBudget

**Purpose**: Enforce per-step and cumulative [diff budget](../concepts/safety-system.md#diff-budget) limits.

Checks three counters against configured ceilings:

| Limit | Config key | Default |
|-------|-----------|---------|
| Files changed | `policies.diff_budget.max_files_per_step` | 20 |
| Lines added | `policies.diff_budget.max_additions_per_step` | 500 |
| Lines deleted | `policies.diff_budget.max_deletions_per_step` | 500 |

If any counter exceeds its ceiling, the stage rejects. Cumulative (scope) budget enforcement happens in the orchestrator's `stepOutcome` phase, not here.

**Reject reason**: `diff_budget_exceeded` with the specific counter that triggered.

---

### Stage 7 — BuildReviewBundle

**Purpose**: Assemble the review evidence package.

Collects all materials the review agent will need:

- **Full diff patch** (or delta diff from `lastRejectCommitSha` to HEAD for retries)
- **Advisory notes** from prior rejections (up to 6 accumulated hints)
- **Contract notes** from current task spec
- **Run log excerpts** for forensic context

If the SHA referenced by `lastRejectCommitSha` is no longer reachable (force-push or history rewrite), the stage falls back to the full working-tree diff instead of the between-diff.

If the bundle's diff is empty at this stage (after all checks), it logs a `task_cycle_no_diff` event with any accumulated contract notes for the next retry, then returns `StageEarlyReturn(noDiff: true)`.

---

### Stage 8 — RequiredFiles

**Purpose**: Verify that all files declared as required by the task spec are present.

The task spec can list files that must exist for the task to be considered complete. If any required file is missing, the stage rejects immediately — preventing review from approving incomplete deliveries.

**Reject reason**: `missing_required_files` with the list of absent paths.

---

### Stage 9 — QualityGate

**Purpose**: Run the full quality gate pipeline.

Executes all configured quality gate commands in order (format check, static analysis, tests). See [Quality Gates](./quality-gates.md) for detailed documentation of adaptive diff, flake retry, timeout, and language defaults.

**Reject reason**: `quality_gate_failed` with the command output and exit code.

---

### Stage 10 — ArchitectureGate

**Purpose**: Enforce architectural layer integrity.

The `ArchitectureHealthService` analyzes the project's import graph for:

- **Layer violations**: A lower layer (e.g. `core`) importing from a higher layer (e.g. `ui`)
- **Circular dependencies**: Import cycles between modules
- **Excessive coupling**: High fan-in or fan-out that breaks encapsulation contracts

Critical violations produce a reject. Advisory violations are logged as warnings but do not block delivery.

**Reject reason**: `architecture_violation` with the violating import path.

---

### Stage 11 — AcSelfCheck

**Purpose**: Agent self-verification of acceptance criteria.

The coding agent is prompted to self-check its own delivery against the task's acceptance criteria (AC) before the external review agent sees it. This is an internal consistency check — if the agent concludes its delivery does not satisfy the AC, it rejects early without burning a review-agent call.

**Reject reason**: `ac_self_check_failed` — agent self-reported AC mismatch.

---

### Stage 12 — ReviewAgent

**Purpose**: External review by the designated review agent.

Sends the assembled review bundle to the review agent (which may be the same or a different provider than the coding agent). The review agent returns `approve` or `reject` with structured evidence.

On **approve**: the pipeline exits with `StageReviewComplete`, triggering the delivery phase (commit → push → merge).

On **reject**: the review notes are archived, `lastRejectCommitSha` is bookmarked, advisory notes are accumulated (up to 6 cross-subtask hints), and retry escalation may trigger reactive subtask split. See [Review Escalation](./review-escalation.md).

---

## Stage Outcomes

| Outcome | Meaning | Next Action |
|---------|---------|-------------|
| `StageContinue` | Stage passed, continue to next | Next stage runs |
| `StageEarlyReturn(noDiff)` | No changes detected | Step marked as no-progress |
| `StageReject(reason)` | Policy or quality violation | Retry budget decremented; forensics if exhausted |
| `StageReviewComplete` | Review approved | Delivery phase begins |

---

## Policy Rollback on Reject

When a reject occurs, the orchestrator rolls back the working tree in escalating steps:

1. **Discard** — `git checkout .` (discard unstaged changes)
2. **Hard reset** — `git reset --hard HEAD` (discard staged + unstaged)
3. **Clean untracked** — `git clean -fd` (remove untracked files)

Each escalation step is tried in order until the worktree is clean. The final clean state is archived as a stash with an audit entry for forensic inspection. This guarantees the [Clean-End Invariant](../CLAUDE.md#8-unattended-anti-block-invariants) regardless of what the agent wrote.

---

## Related Documentation

- [Quality Gates](./quality-gates.md) — QG commands, adaptive diff, flake retry
- [Safety System](./safety-system.md) — Safe-Write, Shell Allowlist, Diff Budget
- [Review Escalation](./review-escalation.md) — Contract lock, escalation modes, subtask split
- [Task Lifecycle](./task-lifecycle.md) — How tasks move through states
- [Forensic Recovery Advanced](./forensic-recovery-advanced.md) — What happens when retries are exhausted
