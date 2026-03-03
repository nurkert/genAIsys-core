[Home](../README.md) > [Concepts](./README.md) > Security Model

# Security Model

Genaisys operates on a [fail-closed](../glossary.md#fail-closed) security model where uncertain or invalid states always result in blocking, never permitting.

---

## Core Assumptions

- Genaisys runs locally on the developer's machine
- Provider CLIs work with local credentials managed by the user
- The user is responsible for API key management and provider authentication
- The `.genaisys/` directory is trusted as the single source of truth

## Threat Model

| Threat | Countermeasure |
|--------|---------------|
| Uncontrolled file writes | [Safe-Write policy](safety-system.md#safe-write) with allowed root list |
| Malicious shell commands | [Shell Allowlist](safety-system.md#shell-allowlist) without chaining |
| Runaway agents | Timeout + [diff budget](safety-system.md#diff-budget) limits |
| Merge chaos | Central merge policy + [review gate](review-system.md) |
| Token/secret leakage | Output sanitization + redaction pipeline |
| State corruption | Atomic writes + schema validation + crash recovery |
| Infinite loops | Wall-clock timeout + iteration safety limit |

## Fail-Closed Design

Every security and policy decision follows the fail-closed principle:

- **Preflight checks**: If any check fails, no step is executed
- **Safe-Write**: Unknown paths are rejected (not allowed by default)
- **Shell Allowlist**: Unknown commands are rejected
- **Review gate**: Missing or uncertain review status blocks delivery
- **DoD evidence**: Missing checklist items block task completion
- **Schema validation**: Invalid STATE.json or config.yml blocks operation
- **Stabilization gate**: Feature work blocked until P1 count is zero

## Output Sanitization

All CLI output (stdout and stderr) passes through a sanitization sink that redacts:
- API keys and tokens
- Credential patterns
- Sensitive file paths

Config key: `app-settings --strict-secrets` enables aggressive redaction.

## Logging and Audit

All actions are logged in `.genaisys/RUN_LOG.jsonl` with:
- `event_id` and `correlation_id` for traceability
- `error_class` and `error_kind` for machine-readable failure classification
- `step_id`, `task_id`, `subtask_id` for context linking

Every agent attempt is archived in `.genaisys/attempts/` for post-incident review.

## Protected Paths

The following paths are always protected by Safe-Write, regardless of allowed roots:
- `.git/` and `.git/**` — Git metadata
- `.genaisys/config.yml` — Project configuration
- `.genaisys/RULES.md` — Project rules
- `.genaisys/VISION.md` — Project vision
- `.genaisys/STATE.json` — Runtime state

## Lock Security

The autopilot lock (`locks/autopilot.lock`) uses:
- PID-based liveness checks (not just TTL)
- Dead PID locks are recovered immediately with audit logging
- Live PID locks are never overridden by TTL alone
- Lock recovery emits structured evidence (`recovery_reason`, lock metadata)

---

## Related Documentation

- [Safety System](safety-system.md) — Policy enforcement details
- [Orchestration Lifecycle](orchestration-lifecycle.md) — Preflight and verification gates
- [Data Contracts](../reference/data-contracts.md) — Artifact integrity guarantees
- [Run Log Schema](../reference/run-log-schema.md) — Audit event structure
