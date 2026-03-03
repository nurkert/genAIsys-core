[Home](../README.md) > [Guides](./README.md) > Troubleshooting

# Troubleshooting

Diagnostics, common errors, and recovery procedures.

---

## Diagnostic Commands

### Health Check

```bash
genaisys health --json
```

Checks project structure, git state, config validity, and provider readiness.

### Autopilot Diagnostics

```bash
genaisys autopilot diagnostics --json
```

Shows error patterns, forensic state, recent events, and supervisor status.

### Config Validation

```bash
genaisys config validate --json
```

### Config Diff

```bash
genaisys config diff --json
```

Shows which config values differ from defaults.

### Status

```bash
genaisys status --json
```

Full project status including health summary, telemetry, and active task.

---

## Common Errors

### "No open tasks found"

**Cause**: All tasks in TASKS.md are done or blocked.

**Fix**: Add new tasks to `.genaisys/TASKS.md` or unblock existing ones:
```bash
genaisys tasks --blocked    # See what's blocked
```

### Review keeps rejecting

**Cause**: Agent output doesn't meet review criteria.

**Fix**:
1. Check rejection reasons: `genaisys autopilot diagnostics`
2. Try a more specific prompt: `--prompt "Focus on minimal changes only"`
3. Lower review strictness: `review.strictness: lenient`
4. Increase retry budget: `autopilot.max_task_retries: 5`
5. Check if the task scope is too large — consider decomposing

### Quality gate failures

**Cause**: Code doesn't pass format/lint/test checks.

**Fix**:
1. Run quality gate commands manually to identify the issue
2. Check if tests are flaky — increase `quality_gate.flake_retry_count`
3. For docs-only changes: enable `skip_tests_for_docs_only`

### Provider not responding

**Cause**: Provider CLI not installed, not authenticated, or quota exhausted.

**Fix**:
1. Verify CLI is installed: `which claude` (or `gemini`, `codex`, etc.)
2. Re-authenticate: `claude login`
3. Check health: `genaisys health --json`
4. Add fallback providers to the pool

### Lock file prevents autopilot start

**Cause**: Previous autopilot process didn't clean up, or another instance is running.

**Fix**:
1. Check if another process is actually running: `ps aux | grep genaisys`
2. If the process is dead, the lock will be auto-recovered on next start (PID liveness check)
3. Manual removal (last resort): `rm .genaisys/locks/autopilot.lock`

### Dirty worktree prevents checkout

**Cause**: Uncommitted changes in the git worktree.

**Fix**:
1. The orchestrator's `.genaisys/.gitignore` should exclude runtime artifacts
2. Commit or stash your changes: `git stash`
3. If `.genaisys/STATE.json` is tracked, the gitignore migration will fix this automatically on next start

### Preflight keeps failing

**Cause**: Preconditions not met (git issues, config invalid, etc.).

**Fix**:
1. Check the preflight error in the run log: `grep preflight_failed .genaisys/RUN_LOG.jsonl | tail -1`
2. Look at `error_class` and `error_kind` for specifics
3. Common causes: SSH keys expired, remote unreachable, merge conflict, invalid config

### Safety halt

**Cause**: Failure budgets exhausted (too many consecutive failures or rejects).

**Fix**:
1. Check what caused the failures: `genaisys autopilot diagnostics`
2. Fix the underlying issue (task quality, provider config, etc.)
3. Restart: `genaisys autopilot supervisor restart . --reason recovery`

### Diff budget exceeded

**Cause**: Agent made too many changes in a single step.

**Fix**:
1. Increase budget: `policies.diff_budget.max_files: 30`
2. Or use more specific prompts to constrain scope
3. Consider decomposing the task into smaller subtasks

## Run Log Analysis

The [run log](../glossary.md#run-log) is the primary diagnostic tool:

```bash
# Last 10 events
tail -10 .genaisys/RUN_LOG.jsonl | jq .

# Recent errors
grep '"error"' .genaisys/RUN_LOG.jsonl | tail -5

# Review rejections for a specific task
grep '"review_reject"' .genaisys/RUN_LOG.jsonl | grep "task title" | tail -5

# Preflight failures
grep '"preflight_failed"' .genaisys/RUN_LOG.jsonl | tail -3

# Supervisor events
grep '"autopilot_supervisor"' .genaisys/RUN_LOG.jsonl | tail -10
```

## Recovery Procedures

### Self-Heal

The autopilot includes an incident-based repair step:

```bash
genaisys autopilot heal --reason stuck --detail "No progress in recent segments"
```

### Force Deactivate

If the active task is stuck:

```bash
genaisys deactivate
```

### Clear Review State

```bash
genaisys review clear
```

### Branch Cleanup

```bash
genaisys autopilot cleanup-branches --dry-run    # Preview
genaisys autopilot cleanup-branches              # Execute
```

---

## Related Documentation

- [Unattended Operations](unattended-operations.md) — Incident handling for supervisor
- [State Machine](../concepts/state-machine.md) — Orchestrator phases
- [Safety System](../concepts/safety-system.md) — Policy enforcement
- [CLI Reference](../reference/cli.md) — All diagnostic commands
- [Run Log Schema](../reference/run-log-schema.md) — Event structure
