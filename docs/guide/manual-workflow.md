[Home](../README.md) > [Guides](./README.md) > Manual Workflow

# Manual Workflow

Step-by-step attended CLI flow for driving Genaisys one command at a time.

---

## When to Use Manual Mode

Use the manual workflow when you want full control over each step:
- Learning how Genaisys works
- Debugging a specific task
- Reviewing changes before each phase
- Working on sensitive code that needs human oversight

For autonomous operation, see [Autonomous Execution](autonomous-execution.md).

## The Complete Flow

### 1. Check What's Next

```bash
genaisys next
```

Output: `[Backlog] P1 CORE - Implement user authentication`

### 2. Activate the Task

```bash
genaisys activate
```

This creates a [feature branch](../glossary.md#feature-branch) and sets the task as active in [STATE.json](../glossary.md#statejson).

### 3. Generate Specification

```bash
genaisys spec init
```

Creates `.genaisys/task_specs/{id}/spec.md` — the technical specification for the task. Review and edit this file before proceeding.

### 4. Generate Plan

```bash
genaisys plan init
```

Creates `.genaisys/task_specs/{id}/plan.md` — the implementation plan. Review and edit.

### 5. Generate Subtasks

```bash
genaisys subtasks init
```

Creates `.genaisys/task_specs/{id}/subtasks.md` — the ordered subtask list. Review and edit.

### 6. Run Coding Cycle

```bash
genaisys cycle run --prompt "Implement the feature as specified in the plan."
```

The coding [agent](../glossary.md#agent) executes the prompt with full task context. The [quality gate](../glossary.md#quality-gate) runs automatically.

### 7. Check Review Status

```bash
genaisys review status
```

If the automated review rejected the changes:

```bash
genaisys review status --json  # See rejection details
```

### 8. Approve or Reject Manually

```bash
# After inspecting the diff yourself
genaisys review approve --note "Looks good, tests pass"

# Or reject with feedback
genaisys review reject --note "Missing error handling in auth module"
```

### 9. Mark Done

```bash
genaisys done
```

This merges the feature branch, marks the task as done in TASKS.md, and cleans up.

### 10. Deactivate

```bash
genaisys deactivate
```

Clears the active task, ready for the next one.

## Monitoring During Manual Work

### Project Status

```bash
genaisys status
genaisys status --json  # Includes health and telemetry
```

### Task List

```bash
genaisys tasks --open --sort-priority
```

### Health Check

```bash
genaisys health --json
```

### Config Validation

```bash
genaisys config validate
```

## Tips

- **Edit spec/plan/subtasks** before running `cycle run` — the agent uses them as context
- **Use `--overwrite`** to regenerate artifacts: `genaisys spec init --overwrite`
- **Check review before done** — `done` will fail if review is not approved
- **Use `--json`** for machine-readable output in scripts

---

## Related Documentation

- [Autonomous Execution](autonomous-execution.md) — Automated operation
- [Task Management](task-management.md) — Backlog management
- [Review & Quality](review-and-quality.md) — Review and quality gate details
- [CLI Reference](../reference/cli.md) — All commands and flags
