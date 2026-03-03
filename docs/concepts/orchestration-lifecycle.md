[Home](../README.md) > [Concepts](./README.md) > Orchestration Lifecycle

# Orchestration Lifecycle

How Genaisys drives the complete software delivery cycle from user vision to deployed code.

---

## The Grand Cycle

Genaisys follows a fixed orchestration lifecycle that transforms high-level project goals into verified, reviewed, and delivered code changes:

```
User Vision & Strategy
  ↓
.genaisys/TASKS.md (Sovereign Backlog)
  ↓
Orchestrator Activation (feature branch, STATE.json, lock)
  ↓
Stage 1: Planning
  SpecAgent → Plan → Technical Spec → Subtasks
  ↓
Stage 2: Execution Loop (per subtask)
  → Coding Agent
    → Safe-Write (path protection)
    → Shell-Allowlist (command gate)
    → Quality Gate (lint, analyze, test)
    → Review Agent (APPROVE or REJECT with notes)
  ↓
Stage 3: Delivery
  Evidence Bundle → Commit → Push → Merge → Mark Done
  ↓
Self-Evolution Step (update agent guidelines)
  ↓
[Loop to next task]
```

## Core Governance Pillars

### 1. Persistence and Truth

The `.genaisys/` directory is the single source of truth. All orchestrator state, task definitions, run logs, and configuration are persisted here with atomic-write guarantees. No in-memory-only state survives a crash.

Key artifacts:
- **STATE.json** — Runtime state (active task, workflow stage, counters). Schema-validated on every read.
- **TASKS.md** — The sovereign backlog. Checkbox-based Markdown with priority and category tags.
- **RUN_LOG.jsonl** — Structured audit trail of every orchestrator event.
- **config.yml** — Project configuration (150+ keys with schema validation).

### 2. Safety Shields

Three policy layers prevent agents from causing harm:
- **[Safe-Write](safety-system.md#safe-write)** — Restricts file writes to allowed directory roots
- **[Shell Allowlist](safety-system.md#shell-allowlist)** — Restricts executable commands to approved prefixes
- **[Diff Budget](safety-system.md#diff-budget)** — Limits the size of changes per step

### 3. Verification Gates

No code reaches the base branch without passing through:
- **[Quality Gate](quality-gates.md)** — Automated format, lint, analysis, and test commands
- **[Review Gate](review-system.md)** — Independent agent review with mandatory approval
- **DoD Evidence** — Definition-of-done checklist in the review evidence bundle

### 4. Resilience

The orchestrator is designed for crash-safe, self-recovering operation:
- Atomic writes for all critical state files
- PID-based lock recovery for dead processes
- Deterministic resume after crash (approved tasks are delivered before new work starts)
- Self-heal fallback for stuck states
- Configurable retry budgets with cooldowns

## Pipeline Steps

Each coding cycle passes through an ordered pipeline:

1. **Context Injection** — Project architecture, rules, vision, and task context prepended to the agent prompt
2. **Error Pattern Injection** — Known failure patterns injected as preventive guidance (if enabled)
3. **Impact Analysis** — Estimated scope of changes assessed (if enabled)
4. **Coding Agent** — The provider CLI is invoked with the composed prompt
5. **Quality Gate** — Format, lint, analyze, and test commands run against the diff
6. **Review Agent** — Independent assessment of the diff with evidence bundle generation
7. **Delivery** — On approval: commit, push, merge, mark done

## Task Selection

When no task is active, the orchestrator selects the next task based on the configured selection mode:

- **strict_priority** — Always picks the highest-priority open task (P1 > P2 > P3)
- **fair** — Priority-weighted selection with a fairness window to prevent P3 starvation
- **round_robin** — Cycles through tasks regardless of priority

Tasks with active cooldowns or that are blocked are skipped. The selection also respects the `min_open` threshold — if the backlog drops below this count, the planner seeds new tasks.

See [Task Lifecycle](task-lifecycle.md) for the full state machine and selection details.

## Autopilot Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `autopilot step` | Single cycle, then stop | Interactive development |
| `autopilot run` | Continuous loop with limits | Supervised batch processing |
| `autopilot supervisor` | Meta-orchestrator with restart/watchdog | Unattended overnight runs |
| `autopilot pilot` | Time-boxed run on dedicated branch | Release candidate validation |

---

## Related Documentation

- [State Machine](state-machine.md) — The 7-phase orchestrator loop
- [Task Lifecycle](task-lifecycle.md) — Task states, transitions, retry budgets
- [Safety System](safety-system.md) — Policy enforcement details
- [Review System](review-system.md) — Review gates and evidence bundles
- [Autonomous Execution](../guide/autonomous-execution.md) — How to run the autopilot
- [Unattended Operations](../guide/unattended-operations.md) — Supervisor and overnight runs
