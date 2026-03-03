[Home](../README.md) > [Concepts](./README.md) > State Machine

# State Machine

The Genaisys [orchestrator](../glossary.md#orchestrator) runs as a 7-phase state machine that processes the [backlog](../glossary.md#backlog) autonomously.

---

## Overview

Each iteration of the [autopilot](../glossary.md#autopilot) loop passes through seven phases in order. Each phase handler returns a `RunLoopTransition` — either `next(phase)` to advance to a specific phase, or `terminate(reason)` to stop the loop.

```
┌─── gateCheck ◄──────────────────────────────────┐
│       │                                          │
│       ▼                                          │
│   preflight                                      │
│       │                                          │
│       ▼                                          │
│   stepExecution                                  │
│       │                                          │
│       ▼                                          │
│   stepOutcome                                    │
│       │                                          │
│       ▼                                          │
│   errorRecovery  (only on caught errors)         │
│       │                                          │
│       ▼                                          │
│   progressCheck                                  │
│       │                                          │
│       ▼                                          │
│   sleepAndLoop ──────────────────────────────────┘
```

## Phase Details

### 1. gateCheck

Checks hard stop conditions before doing any work:
- Iteration safety limit (prevents infinite loops)
- Wall-clock timeout (max hours exceeded)
- Max steps reached (`--max-steps`)
- External stop signal (lock file deleted or stop command)

If any gate triggers, the loop terminates immediately.

### 2. preflight

Verifies all preconditions for a safe step execution:
1. Project structure (`.genaisys/` directory exists and is valid)
2. Git safety (is a git repo, no merge in progress, clean or auto-remediable worktree)
3. Review policy (handle `review_rejected` state)
4. Policy health (quality gate config valid, tokenizer valid, allowlist valid, required executables resolvable)
5. Provider readiness (credentials or approved external auth path)
6. Optional push readiness (remote + dry-run push)

On failure: emits `preflight_failed` with machine-readable `error_class` and `error_kind`. If consecutive preflight failures exceed the repair threshold (5), attempts automatic repair (up to 3 times). Beyond that, terminates.

### 3. stepExecution

Executes the actual orchestrator step:
- Delegates to `StepService.run()` which handles task selection, coding, review, and delivery
- The step result indicates: idle (no work), success (progress made), or failure

### 4. stepOutcome

Evaluates the step result and updates counters:
- On **success**: increments successful steps, resets failure counters
- On **idle**: increments idle steps, checks `stop-when-idle`
- On **failure**: increments failure counters, checks self-heal eligibility
- Checks approve budget and scope limits

Also handles:
- Self-heal attempts for specific failure types
- Cooldown application after failures
- Config reload on periodic cadence

### 5. errorRecovery

Unified error handler that catches exceptions from phases 2-4:
- Classifies errors by type (preflight, state, agent, timeout, etc.)
- Applies appropriate backoff based on error severity
- Records structured error events in the run log
- May terminate on unrecoverable errors

### 6. progressCheck

Detects no-progress loops:
- Tracks consecutive steps without meaningful progress
- If the no-progress threshold is exceeded and self-restart is enabled, resets counters and continues
- Otherwise terminates with a no-progress halt

### 7. sleepAndLoop

Computes the appropriate sleep duration and pauses:
- Productive steps: `step_sleep_seconds` (default 2s)
- Idle/error steps: `idle_sleep_seconds` (default 30s)
- Forced cooldown: sleeps until `cooldownNextEligibleAt`
- Second stop-signal check after sleep (prevents unnecessary next iteration)

Then transitions back to `gateCheck` for the next iteration.

## State Containers

### RunLoopContext (Mutable)

Carries all counters and per-iteration state across phases:

| Counter | Description |
|---------|-------------|
| `totalSteps` | Total iterations executed |
| `successfulSteps` | Steps that produced meaningful progress |
| `idleSteps` | Steps with no work available |
| `failedSteps` | Steps that ended in error |
| `consecutiveFailures` | Unbroken failure streak (resets on success) |
| `noProgressSteps` | Steps without progress (resets on progress) |
| `selfRestartCount` | Number of self-restarts in this run |
| `consecutivePreflightFailures` | Unbroken preflight failure streak |
| `approvalCount` | Total auto-approvals consumed |
| `scopeFiles` / `scopeAdditions` / `scopeDeletions` | Cumulative scope consumed |

### ResolvedRunParams (Immutable)

Configuration snapshot frozen at run start:
- All autopilot settings (max_steps, max_failures, sleep times, etc.)
- Policy limits (scope, approve budget)
- Feature flags (self_heal, self_restart, overnight_unattended)

## Termination

The loop terminates when any handler returns `RunLoopTransition.terminate()`. The termination reason is recorded in the run result and the run log. Common reasons:

- `max_steps_reached` — Step limit hit
- `stop_when_idle` — No work and idle-stop enabled
- `safety_halt` — Failure budgets exhausted
- `stop_signal` — External stop command
- `wallclock_timeout` — Max hours exceeded
- `no_progress` — Stuck loop detected
- `preflight_irrecoverable` — Preflight repair exhausted

---

## Related Documentation

- [Orchestration Lifecycle](orchestration-lifecycle.md) — The grand cycle from vision to delivery
- [Task Lifecycle](task-lifecycle.md) — Task states and transitions
- [Autonomous Execution](../guide/autonomous-execution.md) — How to run the autopilot
- [STATE.json Schema](../reference/state-json-schema.md) — Runtime state fields
- [Run Log Schema](../reference/run-log-schema.md) — Event catalog
