# Architecture

## Overview

Genaisys is a desktop-first orchestrator that drives AI coding agents through a gated software
delivery lifecycle: activate → spec & plan → code → quality gate → review → deliver. The system
is split into a UI-agnostic core engine and two independent frontends (CLI and Flutter desktop
GUI). `.genaisys/` is the single source of truth for project state, backlog, vision, rules, and
the append-only run log.

The controlling design constraint is **fail-closed orchestration**: every step is preflight-checked
before an agent is invoked, every change passes a quality gate and an independent review agent, and
every reliability-relevant decision is written to `RUN_LOG.jsonl` with a machine-readable
`error_class` / `error_kind`.

## Modules

| Module | Responsibility |
|---|---|
| `lib/core/services/` | Orchestrator state machine, task cycle, autopilot supervisor, delivery, quality gates |
| `lib/core/services/agents/` | Spec, coding, and review agent invocation; prompt assembly; response parsing |
| `lib/core/agents/` | Provider adapters (Claude Code, Gemini, Codex, Vibe, AMP) and the native agent loop |
| `lib/core/policy/` | Safe-Write roots, shell allowlist, diff budget, language and interaction parity policy |
| `lib/core/security/` | Redaction policy and service for all outward-facing output surfaces |
| `lib/core/config/` | Schema-validated project configuration driven by a central field registry |
| `lib/core/git/` | Branch-per-task workflow: branch, commit, diff, stash, history, merge, cleanup |
| `lib/core/storage/` | Atomic-write persistence for `STATE.json`, `TASKS.md`, `RUN_LOG.jsonl`, health ledger |
| `lib/core/app/` | Stable application boundary: `GenaisysApi` contract, use cases, DTOs, typed results |
| `lib/core/cli/` | CLI adapter: one handler per command, text and JSON presenters, run-log tailer |
| `lib/desktop/` | Platform integration behind interfaces (window management, windowing adapters) |
| `lib/ui/desktop/` | Flutter desktop shell: workspaces, controllers, theme tokens, localization |

## Dependencies & Layer Rules

```
lib/ui/desktop/   ──┐
lib/desktop/      ──┤──> lib/core/app/ ──> lib/core/
lib/core/cli/     ──┘
```

| Source | May import | Must never import |
|---|---|---|
| `lib/core/` | `lib/core/` only | `lib/core/cli/`, `lib/ui/`, `lib/desktop/` |
| `lib/core/app/` | `lib/core/` | `lib/core/cli/`, `lib/ui/`, `lib/desktop/` |
| `lib/core/cli/` | `lib/core/`, `lib/core/app/` | `lib/ui/`, `lib/desktop/` |
| `lib/desktop/` | `lib/core/`, `lib/core/app/` | `lib/ui/` (except theme tokens) |
| `lib/ui/` | `lib/core/app/`, `lib/desktop/` interfaces | `lib/core/cli/`, core services directly |

Dependencies flow one way only. The core engine has zero Flutter imports, so the CLI is fully
functional without any GUI runtime. Third-party desktop packages (`window_manager`,
`flutter_acrylic`, …) are confined to adapter implementations in `lib/desktop/services/`; UI
widgets consume them only through interfaces. These rules are enforced by boundary tests in CI.

## Key Interfaces

- **`GenaisysApi`** (`lib/core/app/contracts/`) — the single application boundary. Both the CLI
  and the GUI go through it; it returns `AppResult<T>` / `AppError` rather than throwing across
  the boundary. `InProcessGenaisysApi` is the in-process implementation.
- **`AgentRunner`** — provider adapter contract. Adding a provider means implementing this
  interface and registering it; no orchestration code changes.
- **`BuildTestRunnerService`** — quality gate execution (format, analyze, test) with dynamic
  profile selection, so docs-only diffs skip irrelevant test scopes.
- **Storage stores** (`TaskStore`, `StateStore`, `RunLogStore`) — atomic-write persistence; all
  state transitions pass through them, never through direct file access.
- **Policy objects** (`SafeWritePolicy`, `ShellAllowlistPolicy`, `DiffBudgetPolicy`) — pure,
  side-effect-free predicates evaluated before any agent action takes effect.

Data flow per step: preflight → agent invocation → diff capture → auto-format → quality gate →
review agent → delivery (commit, merge, cleanup) → run-log event. Any failure short-circuits to a
structured failure reason and a clean worktree.

## Technology Stack

| Choice | Rationale |
|---|---|
| Dart 3.10+ | One language for engine, CLI, and GUI; `dart compile exe` produces a dependency-free CLI binary |
| Flutter (desktop) | Single codebase for Linux, macOS, and Windows desktop shells |
| YAML (`yaml`, `yaml_edit`) | Human-editable config with comment-preserving programmatic edits |
| JSONL run log | Append-only, streamable, machine-parseable audit trail |
| Markdown (`TASKS.md`, `VISION.md`) | Human- and agent-readable state that stays reviewable in git |
| `freezed` / `json_serializable` | Immutable models and generated serialization at the boundary |
| External agent CLIs | Reuses authenticated provider tooling; the native runtime is the successor path |

Dependency hygiene is deliberate: small, focused packages only, with internal solutions preferred
over heavy external libraries.

## Constraints & Boundaries

**Safety (fail-closed, non-negotiable)**
- Agent writes are restricted to configured Safe-Write roots.
- Shell execution is token-prefix matched against an allowlist; no pipes or shell operators.
- Diff budgets cap files and lines per step.
- Preflight failure blocks the step *before* the agent is invoked — never after.
- All log, artifact, and CLI output passes through centralized redaction.

**Orchestration invariants**
- No task completes without review approval.
- The worktree is clean at the end of every step, on approve and on reject alike; rejected context
  is archived via stash plus audit events, never left dirty.
- Progress failures (`review_rejected`, `no_diff`) consume retry budget and can block a task.
- Lock status combines lock metadata with PID liveness, not TTL alone.
- An approved-but-undelivered task resumes delivery before a new coding cycle starts.

**Architectural boundaries**
- The core engine must remain independently operable and testable without Flutter.
- Geometry and visual tokens live centrally in the theme layer, not scattered across widgets.
- Tests must be deterministic on clean ephemeral CI environments — no host-installed binaries,
  timing luck, or dirty worktree assumptions.
