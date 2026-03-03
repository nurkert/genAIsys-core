[Home](../README.md) > [Guides](./README.md) > Task Management

# Task Management

How to define, organize, and manage the [backlog](../glossary.md#backlog) in `.genaisys/TASKS.md`.

---

## Task Format

Tasks use checkbox-based Markdown:

```markdown
- [ ] [P1] [CORE] Implement user authentication module
```

Format: `- [status] [Priority] [Category] Title`

### Status Markers

| Marker | Status | Description |
|--------|--------|-------------|
| `- [ ]` | Open | Available for activation |
| `- [x]` | Done | Completed and delivered |
| `- [b]` | Blocked | Cannot proceed |

### Priority Levels

| Priority | Urgency | Weight (default) |
|----------|---------|-----------------|
| `[P1]` | Critical | 3 |
| `[P2]` | Important | 2 |
| `[P3]` | Nice-to-have | 1 |

### Categories

Common categories: `CORE`, `QA`, `SEC`, `GUI`, `DOCS`, `UI`, `INTERACTION`

Custom categories are allowed — the orchestrator reads them but does not enforce a fixed set.

## Sections

Tasks are organized into sections using Markdown headers:

```markdown
# Backlog

## Phase 1: Foundation

- [ ] [P1] [CORE] Implement core API
- [ ] [P2] [QA] Add integration tests

## Phase 2: Features

- [ ] [P2] [GUI] Create dashboard view
- [ ] [P3] [DOCS] Write API documentation
```

Sections are used for:
- Organization and readability
- Filtering: `genaisys tasks --section "Phase 1"`
- Activation: `genaisys activate --section "Phase 1"`

## CLI Commands

### List Tasks

```bash
genaisys tasks                    # All tasks
genaisys tasks --open             # Open tasks only
genaisys tasks --done             # Completed tasks
genaisys tasks --blocked          # Blocked tasks
genaisys tasks --sort-priority    # Sort by priority
genaisys tasks --section "Phase 1" # Filter by section
genaisys tasks --show-ids         # Include task IDs
```

### Activate a Task

```bash
genaisys activate                     # Next by priority
genaisys activate --id alpha-3        # By ID
genaisys activate --title "Implement core API"  # By title
```

### Block a Task

```bash
genaisys block --reason "Waiting for dependency"
```

### Mark Done

```bash
genaisys done   # Requires review approval
```

### Deactivate

```bash
genaisys deactivate                # Clear active task
genaisys deactivate --keep-review  # Keep review status
```

## Backlog Maintenance

### Minimum Open Tasks

The [autopilot](../glossary.md#autopilot) monitors the backlog size. When open tasks drop below `autopilot.min_open` (default: 8), the planner seeds new tasks (up to `autopilot.max_plan_add` per step, default: 4).

### Cooldowns

After blocking or failure, tasks enter a cooldown period before becoming eligible again:

| Config Key | Default | Description |
|-----------|---------|-------------|
| `autopilot.blocked_cooldown_seconds` | 0 | Cooldown for blocked tasks |
| `autopilot.failed_cooldown_seconds` | 0 | Cooldown for failed tasks |
| `autopilot.reactivate_blocked` | false | Auto-unblock after cooldown |
| `autopilot.reactivate_failed` | true | Auto-retry after cooldown |

### Interaction Tasks

Tasks that affect user-facing behavior require parity metadata:

```markdown
- [ ] [P1] [CORE] [INTERACTION] [GUI_PARITY:build-gui-status-41] Add CLI status command
- [ ] [P2] [UI] Build GUI status controls
```

- `[INTERACTION]` — Marks an interaction-facing task
- `[GUI_PARITY:DONE]` — GUI parity included in same task
- `[GUI_PARITY:<id>]` — GUI parity linked to an open UI task

---

## Related Documentation

- [Task Lifecycle](../concepts/task-lifecycle.md) — States, transitions, retry budgets
- [Subtask Decomposition](../concepts/subtask-decomposition.md) — Breaking tasks into subtasks
- [Quickstart](quickstart.md) — Adding your first tasks
- [Configuration Reference](../reference/configuration-reference.md) — Autopilot config keys
