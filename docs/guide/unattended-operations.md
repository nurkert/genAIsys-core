[Home](../README.md) > [Guides](./README.md) > Unattended Operations

# Unattended Operations

Operational reference for running the Genaisys native [supervisor](../glossary.md#supervisor) in unattended mode on a headless server.

---

## Contents

- [Startup Modes (Profiles)](#startup-modes-profiles)
- [Starting the Supervisor](#starting-the-supervisor)
- [Limits and Guardrails](#limits-and-guardrails)
- [Incident Handling](#incident-handling)
- [Operative Intelligence](#operative-intelligence)
- [Quick Reference](#quick-reference)

---

## Startup Modes (Profiles)

The supervisor ships three built-in profiles. Select with `--profile`.

| Profile     | Segment Steps | Step Sleep | Idle Sleep | Stop on Idle | Segment Pause |
|-------------|---------------|------------|------------|--------------|---------------|
| `pilot`     | 20            | 2 s        | 10 s       | yes          | 6 s           |
| `overnight` | 80            | 2 s        | 20 s       | no           | 4 s           |
| `longrun`   | 160           | 1 s        | 12 s       | no           | 3 s           |

- **pilot**: Short exploratory run. Stops when idle (no tasks available). Good for testing configuration or running a quick batch.
- **overnight** (default): Medium-duration unattended run. Does not stop on idle; waits and retries. Suitable for overnight batch work.
- **longrun**: Maximum throughput for multi-day runs. Shorter pauses, larger segment windows.

See [Presets](../reference/presets.md) for the matching config presets.

---

## Starting the Supervisor

### CLI

```bash
genaisys autopilot supervisor start /path/to/project --profile overnight
```

### systemd (Server Deployment)

Install via the deployment script:

```bash
bash scripts/deploy-server.sh install
```

This compiles a native binary, installs it to `~/.local/bin/genaisys`, and creates a systemd user service.

```bash
# Start
systemctl --user start genaisys-autopilot

# Stop
systemctl --user stop genaisys-autopilot

# Logs
journalctl --user -u genaisys-autopilot -f

# Status
systemctl --user status genaisys-autopilot
genaisys autopilot supervisor status /path/to/project --json
```

The systemd unit runs the supervisor in `_worker` foreground mode with `Restart=on-failure` and `WatchdogSec=600`.

### Environment Variables (deploy-server.sh)

| Variable                        | Default                |
|---------------------------------|------------------------|
| `GENAISYS_INSTALL_DIR`        | `~/.local/bin`         |
| `GENAISYS_PROJECT_ROOT`       | Repository root        |
| `GENAISYS_SUPERVISOR_PROFILE` | `overnight`            |

---

## Limits and Guardrails

All limits have [fail-closed](../glossary.md#fail-closed) defaults and can be overridden at start time.

### Restart Budget

| Flag                       | Default | Description                                    |
|----------------------------|---------|------------------------------------------------|
| `--max-restarts`           | 3       | Max consecutive restart attempts before halt    |
| `--restart-backoff-base`   | 5 s     | Exponential backoff base (5, 10, 20, 40, ...)  |
| `--restart-backoff-max`    | 90 s    | Backoff ceiling                                |

The supervisor restarts automatically on segment failure. Backoff formula: `base * 2^(attempt-1)`, capped at max. After `max-restarts` consecutive failures without a successful segment, the supervisor halts with `restart_budget_exhausted`.

### Progress Watchdog

| Flag                  | Default | Description                                   |
|-----------------------|---------|-----------------------------------------------|
| `--low-signal-limit`  | 3       | Consecutive low-signal segments before halt   |

A "low-signal" segment is one that produces no meaningful diff and no task advancement. When the streak reaches the limit, the supervisor halts with `progress_watchdog`.

### Throughput Guardrails

| Flag                           | Default | Description                                  |
|--------------------------------|---------|----------------------------------------------|
| `--throughput-window-minutes`  | 30      | Rolling window for throughput accounting     |
| `--throughput-max-steps`       | 200     | Max engine steps allowed in window           |
| `--throughput-max-rejects`     | 10      | Max review rejects/failures in window        |
| `--throughput-max-high-retries`| 20      | Max retry-2+ escalations in window           |

When any throughput counter exceeds its limit within the window, the supervisor halts with the corresponding reason (`throughput_steps`, `throughput_rejects`, `throughput_high_retries`).

### Agent Idle Timeout

In unattended mode, the environment variable `GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS` is automatically set (default 300 s, capped by agent timeout). This prevents [provider](../glossary.md#provider) processes that hang silently from blocking the supervisor indefinitely.

### Resource Limits (systemd)

| Limit       | Value | Description                              |
|-------------|-------|------------------------------------------|
| `MemoryMax` | 2 GB  | Hard memory ceiling                      |
| `CPUQuota`  | 80%   | CPU throttle                             |
| `RestartSec`| 15 s  | Minimum delay between systemd restarts   |
| `StartLimitBurst` | 5 | Max systemd restarts in interval    |
| `StartLimitIntervalSec` | 300 s | Restart burst window        |
| `WatchdogSec` | 600 s | Supervisor must show activity within 10 min |

---

## Incident Handling

### Halt Reasons

The supervisor records a machine-readable halt reason in [STATE.json](../glossary.md#statejson) and the [run log](../glossary.md#run-log).

| Halt Reason                        | Trigger                                                | Action Required                    |
|------------------------------------|--------------------------------------------------------|------------------------------------|
| `stop_requested`                   | User sent stop signal (CLI or systemd)                 | None (intentional)                 |
| `restart_budget_exhausted`         | Max restarts hit without recovery                      | Investigate root cause, restart    |
| `preflight_restart_budget_exhausted` | Preflight checks failed repeatedly                   | Fix prerequisites, restart         |
| `progress_watchdog`                | Consecutive low-signal segments                        | Check task backlog, add tasks      |
| `throughput_steps`                 | Too many steps in window                               | Wait for cooldown or raise limit   |
| `throughput_rejects`               | Too many rejects in window                             | Check task quality, review config  |
| `throughput_high_retries`          | Too many retry escalations in window                   | Investigate failing task patterns  |
| `run_safety_halt`                  | Engine run triggered [safety halt](../glossary.md#safety-halt) | Check run log for failure details  |

When `supervisor.reflection_on_halt` is enabled (default: `true`), the supervisor automatically triggers a productivity [reflection](../glossary.md#reflection) before halting.

### Reading Halt State

```bash
genaisys autopilot supervisor status /path/to/project --json
```

Key fields:
- `last_halt_reason`: The halt reason code (or null if running)
- `restart_count`: Current restart counter
- `cooldown_until`: ISO 8601 timestamp of next restart attempt (if in backoff)
- `low_signal_streak`: Current consecutive low-signal count
- `throughput.steps`, `throughput.rejects`, `throughput.high_retries`: Current window counters

### Run Log Inspection

All supervisor events are recorded in `.genaisys/RUN_LOG.jsonl`. Key events:

- `autopilot_supervisor_start`: Supervisor started with session ID and profile
- `autopilot_supervisor_segment_complete`: Segment finished (includes step count, outcome)
- `autopilot_supervisor_restart`: Automatic restart after failure
- `autopilot_supervisor_halt`: Supervisor halted (includes halt reason and counters)
- `autopilot_supervisor_resume`: Resume policy applied after restart
- `supervisor_reflection_on_halt`: Reflection triggered before supervisor halt
- `reflection_complete`: Periodic productivity reflection completed
- `git_sync_between_loops`: Inter-loop git sync result
- `context_injection_applied`: Architecture context injected into coding prompt

```bash
# Recent halt events
grep '"autopilot_supervisor_halt"' .genaisys/RUN_LOG.jsonl | tail -5

# Recent restart events
grep '"autopilot_supervisor_restart"' .genaisys/RUN_LOG.jsonl | tail -5

# Reflection events
grep '"reflection_complete\|supervisor_reflection"' .genaisys/RUN_LOG.jsonl | tail -5
```

### Recovery Procedures

**restart_budget_exhausted**:
1. Check run log for the failure pattern: `grep 'supervisor' .genaisys/RUN_LOG.jsonl | tail -20`
2. Identify root cause (provider auth expired, git remote unreachable, disk full, etc.)
3. Fix the underlying issue
4. Restart: `genaisys autopilot supervisor restart /path --reason manual_recovery`

**progress_watchdog**:
1. Check if the task backlog has actionable tasks: `genaisys tasks /path --json`
2. If backlog is empty or all tasks are blocked, add new tasks
3. If tasks exist but agents produce no diff, check provider config and agent prompts
4. Restart: `genaisys autopilot supervisor restart /path --reason watchdog_recovery`

**throughput_* limits**:
1. Wait for the throughput window to expire (default 30 min), or
2. Restart with higher limits: `genaisys autopilot supervisor restart /path --throughput-max-rejects 20`
3. If rejects are consistently high, review task specs and acceptance criteria

**preflight_restart_budget_exhausted**:
1. Check preflight requirements: git remote reachable, SSH keys configured, clean index
2. Verify `genaisys autopilot supervisor status /path --json` for error details
3. Fix prerequisites and restart

### Safe Resume Policy

After a crash or restart, the supervisor applies a deterministic resume policy:

1. **approved_delivery**: If the last review was `approved` and an active task exists, the supervisor delivers (merges) the approved task first.
2. **continue_safe_step**: Otherwise, the supervisor continues with the next unstarted task.

### Crash Recovery

- **Stale lock**: The supervisor detects stale `.genaisys/locks/autopilot.lock` files from crashed processes and recovers automatically.
- **Stale supervisor state**: If `supervisorRunning` is true in STATE.json but no worker process exists, the state is cleaned up on next start.
- **State repair**: `StateRepairService` runs at supervisor start to fix known corruption patterns.

### Preflight Checks

The supervisor runs preflight checks before starting and before each segment:

- Git repository is valid and clean
- Remote push readiness (SSH key, remote reachable)
- No conflicting autopilot process running
- Configuration is valid (config.yml schema)
- [Stabilization exit gate](../glossary.md#stabilization-exit-gate) is checked (feature freeze enforcement)

### Provider Pool Behavior

In unattended mode, the supervisor leverages [provider pool](../glossary.md#provider-pool) rotation:

- **Quota exhaustion**: When a provider hits rate limits, the pool rotates to the next available provider automatically.
- **Provider blocklist**: Providers that fail repeatedly are temporarily blocked.
- **Round-robin**: On success, the pool cursor advances so load is distributed.

---

## Operative Intelligence

### Task Forensics (Forensic Recovery)

When a task exhausts its retry budget, `TaskForensicsService` runs a two-pass analysis before blocking the task.

**Pass 1** is zero-cost (no LLM tokens): deterministic pattern matching against the accumulated reject evidence.

| Classification | Trigger | Action (interactive) | Action (unattended) |
|---------------|---------|---------------------|---------------------|
| `policyConflict` | Error kinds include `diff_budget_exceeded`, `safe_write_violation`, or `policy_violation` | `block` | `block` |
| `persistentTestFailure` | Error kinds include `quality_gate`, `test_failure`, `analyze_failed` | `retryWithGuidance` | **`block`** ¹ |
| `specTooLarge` | Required file count > 5, or review notes contain scope/size keywords | `redecompose` | `redecompose` |
| `specIncorrect` | Review notes mention "wrong file", "missing file", "incorrect spec" | `regenerateSpec` | `regenerateSpec` |
| `codingApproachWrong` | Review notes mention "wrong approach", "different strategy" | `retryWithGuidance` | **`block`** ¹ |
| `unknown` | No clear pattern identified | `block` ² | `block` ² |

¹ `retryWithGuidance` is silently replaced with `block` in unattended mode. Guidance retry assumes operator availability; unattended runs substitute `block` and emit `forensics_action_blocked_in_unattended_mode` in the run log.

² **Pass 2 — Forced Narrowing**: When Pass 1 yields `unknown`, a structured LLM call (constrained output schema, single attempt) tries to classify the failure from the full reject history. If Forced Narrowing succeeds, the resulting action is applied. If it fails or returns an invalid code, the final fallback is `block`.

See [Forensic Recovery Advanced](../concepts/forensic-recovery-advanced.md) for full details on both passes and action semantics.

### Preflight Repair Loop

When consecutive preflight checks keep failing, the orchestrator escalates through a repair loop before terminating:

```
consecutivePreflightFailures >= 5
        │
        ▼
   StateRepairService.repair()
        │
        ├─ Repair succeeded → reset counter, continue
        │
        └─ Repair failed → repairAttempts++
                │
                ├─ repairAttempts < 3 → retry repair
                │
                └─ repairAttempts >= 3 → terminate(preflight_irrecoverable)
```

`StateRepairService` handles: STATE.json schema violations, stale lock files, corrupted task index, and merge-in-progress state without a corresponding git merge. Each attempt is logged as `state_repair_attempt`. After three failed repair attempts the run terminates with `preflight_irrecoverable` — manual operator inspection is required.

### Error Pattern Learning

The `ErrorPatternRegistryService` maintains a persistent registry in `.genaisys/audit/error_patterns.json`. Error patterns influence future runs by injecting known patterns into [agent](../glossary.md#agent) prompts. Config key: `pipeline.error_pattern_learning_enabled`.

### Architecture Gate

The `ArchitectureHealthService` enforces architectural integrity by analyzing the project's import graph for layer violations, circular dependencies, and excessive coupling. Critical layer violations block the pipeline; warnings are logged.

See [Self-Improvement](../concepts/self-improvement.md) for full details on these subsystems.

---

## Quick Reference

```bash
# Start overnight run
genaisys autopilot supervisor start . --profile overnight

# Check status
genaisys autopilot supervisor status . --json

# Stop gracefully
genaisys autopilot supervisor stop . --reason maintenance

# Restart with custom limits
genaisys autopilot supervisor restart . \
  --profile longrun \
  --max-restarts 5 \
  --throughput-max-steps 300 \
  --reason tuning

# Tail run log
tail -f .genaisys/RUN_LOG.jsonl | jq -r '.event + ": " + .message'

# View error patterns and forensic state
genaisys autopilot diagnostics --json

# systemd operations
systemctl --user start genaisys-autopilot
systemctl --user stop genaisys-autopilot
journalctl --user -u genaisys-autopilot --since "1 hour ago"
```

---

## Related Documentation

- [Autonomous Execution](autonomous-execution.md) — Interactive autopilot usage
- [Configuration](configuration.md) — Config tuning for unattended runs
- [Presets](../reference/presets.md) — Built-in profile configurations
- [State Machine](../concepts/state-machine.md) — Orchestrator loop phases
- [CLI Reference](../reference/cli.md) — All supervisor commands
- [Troubleshooting](troubleshooting.md) — Diagnostics and recovery
