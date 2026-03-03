[Home](../README.md) > [Concepts](./README.md) > Subtask Decomposition

# Subtask Decomposition

Complex [tasks](../glossary.md#task) are broken into atomic [subtasks](../glossary.md#subtask) that are processed sequentially, each producing its own diff and review.

---

## Why Decompose

Large tasks that touch many files are more likely to:
- Exceed the [diff budget](../glossary.md#diff-budget)
- Produce review rejections (too much to assess)
- Create merge conflicts
- Fail quality gates

Subtask decomposition keeps each step small, focused, and independently verifiable.

## Decomposition Flow

1. **Spec generation**: The spec agent analyzes the task and creates a technical specification
2. **Plan creation**: A plan is generated with the implementation approach
3. **Subtask extraction**: The plan is decomposed into ordered subtasks, each with:
   - A clear scope (which files to touch)
   - Acceptance criteria
   - Dependencies on previous subtasks

Artifacts are stored in `.genaisys/task_specs/{task-id}/`:
- `spec.md` — Technical specification
- `plan.md` — Implementation plan
- `subtasks.md` — Ordered subtask list

## Subtask Queue

Subtasks form a FIFO queue. The orchestrator processes them sequentially:

```
Subtask 1 → Code → Review → (approve) → ✓
Subtask 2 → Code → Review → (reject) → Retry → (approve) → ✓
Subtask 3 → Code → Review → (approve) → ✓
All done → Merge → Task Done
```

Each subtask:
- Gets its own coding prompt with subtask-specific context
- Produces its own diff
- Goes through the quality gate and review independently
- Has its own retry budget

## Retry Within Subtask

When a subtask's review is rejected:
1. Rejection notes are fed back to the coding agent
2. The subtask retry counter increments
3. If the subtask retry budget is exhausted, forensic analysis runs
4. Based on forensic classification:
   - **redecompose**: Delete spec artifacts and re-decompose with smaller scope
   - **regenerateSpec**: Delete spec only, regenerate with corrections
   - **retryWithGuidance**: Inject anti-pattern guidance into next attempt
   - **block**: Mark the entire task as blocked

## Scope Control

The forensic service checks spec scope as part of its analysis:
- If required file count exceeds 5, the subtask may be flagged as `specTooLarge`
- The suggested action is `redecompose` — break the task into even smaller pieces
- Re-decomposition targets a maximum of 3 files per subtask

## CLI Commands

```bash
# Generate spec, plan, and subtasks for the active task
genaisys spec init
genaisys plan init
genaisys subtasks init

# Overwrite existing artifacts
genaisys spec init --overwrite
```

---

## Related Documentation

- [Task Lifecycle](task-lifecycle.md) — Task states and retry budgets
- [Orchestration Lifecycle](orchestration-lifecycle.md) — Where decomposition fits
- [Review System](review-system.md) — Subtask-level review
- [CLI Reference](../reference/cli.md) — spec/plan/subtasks commands
