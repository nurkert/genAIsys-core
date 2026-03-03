[Home](../README.md) > [Guides](./README.md) > Autonomous Execution

# Autonomous Execution

How to run the Genaisys [autopilot](../glossary.md#autopilot) for automated task processing.

---

## Contents

- [Single Step](#single-step)
- [Continuous Run](#continuous-run)
- [Following a Run](#following-a-run)
- [Sprint-Based Planning](#sprint-based-planning)
- [Human-in-the-Loop Gates](#human-in-the-loop-gates)
- [Supervisor](#supervisor)
- [Pilot Run](#pilot-run)
- [Simulation](#simulation)
- [Self-Improvement](#self-improvement)
- [Stopping](#stopping)

---

## Single Step

Execute one complete orchestration cycle:

```bash
genaisys autopilot step
```

This activates the next task (if none active), runs coding + review, and handles the result. Use `--json` for machine-readable output.

### Custom Prompt

```bash
genaisys autopilot step --prompt "Focus on test coverage for the auth module."
```

### Backlog Maintenance

```bash
genaisys autopilot step --min-open 10 --max-plan-add 5
```

When open tasks drop below `--min-open`, the planner seeds up to `--max-plan-add` new tasks.

## Continuous Run

Process the backlog in a loop:

```bash
genaisys autopilot run --max-steps 20 --stop-when-idle
```

### Key Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--max-steps` | config | Hard stop after N steps |
| `--stop-when-idle` | false | Stop when no work available |
| `--max-failures` | 5 | Stop after N consecutive failures |
| `--max-task-retries` | 3 | Block task after N rejections |
| `--step-sleep` | 2s | Pause between productive steps |
| `--idle-sleep` | 30s | Pause when idle |
| `--quiet` | false | Suppress live run-log output |
| `--override-safety` | false | Override approve and scope budgets |

### Example: Supervised Batch

```bash
genaisys autopilot run \
  --max-steps 50 \
  --stop-when-idle \
  --max-failures 3 \
  --prompt "Work through P1 tasks. Keep changes minimal."
```

## Following a Run

Attach to a running autopilot and stream events:

```bash
genaisys autopilot follow --status-interval 5
```

Press `Ctrl+C` to detach (the autopilot continues running).

## Sprint-Based Planning

When `autopilot.sprint_planning_enabled: true`, the autopilot does not stop when the backlog is exhausted. Instead, `SprintPlannerService` generates a new sprint of `autopilot.sprint_size` tasks aligned with the project vision, then immediately continues processing.

```yaml
# config.yml
autopilot:
  sprint_planning_enabled: true
  sprint_size: 8      # tasks per sprint (default 8)
  max_sprints: 0      # 0 = unlimited
```

The autopilot terminates when:

- `max_sprints` is reached → emits `sprint_max_reached`
- The sprint planner determines the vision is fulfilled → emits `sprint_vision_fulfilled`
- A safety halt or wall-clock timeout occurs

```bash
# Unlimited sprint run (runs until vision is fulfilled or stopped manually)
genaisys autopilot run . --stop-when-idle=false

# Check status during a sprint run
genaisys autopilot status . --json | jq '.current_subtask, .subtask_queue'
```

> Sprint planning is enabled automatically by `genaisys init --from <document>`.

## Human-in-the-Loop Gates

HITL gates pause the autopilot at configured checkpoints to allow human review before continuing. The autopilot writes `.genaisys/locks/hitl.gate` and polls for a decision in `.genaisys/locks/hitl.decision`.

### Configuration

```yaml
# config.yml
hitl:
  enabled: true
  timeout_minutes: 60        # 0 = wait indefinitely
  gate_after_task_done: true  # pause after each completed task
  gate_before_sprint: true    # pause before each new sprint
  gate_before_halt: true      # pause before safety halt
```

### Responding to a Gate

```bash
# Check whether a gate is open
genaisys hitl status .

# Approve — autopilot continues
genaisys hitl approve .

# Approve with a note
genaisys hitl approve . --note "Reviewed sprint 2 backlog. Looks good."

# Skip the gate (continue without decision, treated as approve)
genaisys hitl skip .

# Reject — autopilot terminates cleanly
genaisys hitl reject . --note "Sprint 2 direction needs rework."
```

### Gate Events

The run log records every gate interaction:

| Event | Meaning |
|-------|---------|
| `hitl_gate_opened` | Gate created; autopilot waiting |
| `hitl_gate_resolved` | Human submitted a decision |
| `hitl_gate_timeout` | Timed out; auto-approved |

### Monitoring a Gate

```bash
# Tail run log for gate events
genaisys autopilot follow .

# JSON status for CI/tooling
genaisys hitl status . --json
```

## Supervisor

The [supervisor](../glossary.md#supervisor) wraps `autopilot run` with restart logic, throughput guardrails, and progress monitoring:

```bash
# Start with overnight profile
genaisys autopilot supervisor start . --profile overnight

# Check status
genaisys autopilot supervisor status . --json

# Stop gracefully
genaisys autopilot supervisor stop . --reason done

# Restart with different profile
genaisys autopilot supervisor restart . --profile longrun
```

### Profiles

| Profile | Steps | Stop on Idle | Use Case |
|---------|-------|-------------|----------|
| `pilot` | 20 | yes | Quick batch, testing config |
| `overnight` | 80 | no | Overnight unattended runs |
| `longrun` | 160 | no | Multi-day continuous runs |

See [Unattended Operations](unattended-operations.md) for server deployment, systemd setup, and incident handling.

## Pilot Run

Time-boxed unattended run on a dedicated branch with a full report:

```bash
genaisys autopilot pilot . --duration 2h --max-cycles 120
```

The pilot:
1. Runs release-candidate gates first (unless `--skip-candidate`)
2. Creates a dedicated branch
3. Executes within the time box
4. Generates a report at `.genaisys/logs/pilot_run_report_*.md`

## Simulation

Dry-run a step in an isolated workspace (no effect on the real project):

```bash
genaisys autopilot simulate --show-patch
```

Useful for testing prompts, reviewing agent behavior, or validating configuration changes.

## Self-Improvement

Run the self-improvement pipeline:

```bash
genaisys autopilot improve
```

This executes three phases:
1. **Meta-task generation** — Creates optimization tasks from error patterns
2. **Evaluation harness** — Runs end-to-end tests on isolated workspaces
3. **Self-tune** — Adjusts autopilot parameters based on observed performance

Skip individual phases with `--no-meta`, `--no-eval`, or `--no-tune`.

## Stopping

### Stop a Running Autopilot

```bash
genaisys autopilot stop
```

### Stop the Supervisor

```bash
genaisys autopilot supervisor stop . --reason maintenance
```

### Check Status

```bash
genaisys autopilot status --json    # Autopilot process status
genaisys autopilot supervisor status . --json  # Supervisor status
```

## Smoke Test

Verify the complete pipeline works:

```bash
genaisys autopilot smoke --cleanup
```

Creates a temporary project, runs a full cycle, and validates the result.

---

## Related Documentation

- [Unattended Operations](unattended-operations.md) — Server deployment, systemd, incidents
- [Manual Workflow](manual-workflow.md) — Step-by-step attended flow
- [State Machine](../concepts/state-machine.md) — Orchestrator loop phases
- [Configuration](configuration.md) — Autopilot tuning
- [Configuration Reference: autopilot](../reference/configuration-reference.md#autopilot) — Sprint planning keys
- [Configuration Reference: hitl](../reference/configuration-reference.md#hitl) — HITL gate keys
- [CLI Reference](../reference/cli.md) — All autopilot commands
