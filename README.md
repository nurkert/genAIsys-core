# Genaisys — Sovereign AI Orchestration

A desktop-first orchestrator that applies software-engineering discipline to AI-assisted development.
Genaisys doesn't just run an AI coding agent — it manages the full lifecycle: planning, code generation,
quality gates, review, and git delivery, in a controlled, auditable, and repeatable process.

![Tests](https://img.shields.io/badge/tests-2653%20passing-brightgreen)
![Version](https://img.shields.io/badge/version-0.0.4-blue)
![Phase](https://img.shields.io/badge/phase-2%20active-orange)

---

## What is Genaisys?

Genaisys is a **process orchestrator** for AI coding agents. You define a backlog of tasks; Genaisys
drives an AI agent through each task in a structured, safety-gated cycle — and delivers results as clean,
reviewed git commits on feature branches, automatically merged when approved.

Unlike running an AI agent directly, Genaisys enforces a lifecycle. Every step is preflight-checked,
every change is quality-gated and reviewed, and every outcome is logged in a structured, machine-readable
audit trail. You stay in control even when the system runs unattended.

The project is built on four principles:

- **Iterative Safety** — changes happen in small, verified, atomic steps; no large sweeping diffs
- **Independence** — the core engine is UI-agnostic; fully controllable via CLI without any GUI dependency
- **Self-Evolution** — Genaisys is designed to build and improve itself through its own orchestration pipeline
- **Truth in Persistence** — `.genaisys/` is the single source of truth for state, logs, and project vision

---

## Why Genaisys?

### The problem with current AI coding tools

Raw AI coding agents (Claude Code, Gemini CLI, Codex) are powerful but unstructured. They:

- Produce large, hard-to-review diffs with no enforced scope
- Have no built-in quality gate or test runner integration
- Leave no audit trail — you can't reconstruct *what* was decided *why*
- Have no concept of a task backlog, sprint planning, or multi-step lifecycle
- Can run indefinitely, burning tokens with no progress-failure halts

### What Genaisys adds

- **Mandatory review gate** — every change is assessed by an independent review agent before merge
- **Fail-closed preflight** — if preconditions aren't met, the agent is never invoked
- **Diff budget enforcement** — maximum files and lines per step, not negotiable
- **Safe-Write policy** — agent writes are restricted to explicitly whitelisted directory roots
- **Shell allowlist** — only pre-approved commands can be executed; no pipes, no shell operators
- **Full audit trail** — every decision, review outcome, and failure reason in `RUN_LOG.jsonl`
- **Structured progress gates** — repeated failures block a task instead of burning tokens endlessly
- **Human-in-the-loop checkpoints** — pause for human review at configurable points in the cycle

| | Raw agent | Genaisys |
|---|---|---|
| Enforced task scope | No | Yes — per-task feature branch + diff budget |
| Independent review | No | Yes — separate review agent, mandatory |
| Safety policies | No | Yes — Safe-Write, Shell Allowlist, fail-closed |
| Audit trail | No | Yes — structured JSONL, append-only |
| Progress failure halts | No | Yes — retry budgets, task blocking, safety halt |
| Human checkpoint support | No | Yes — 3 configurable HITL gates |
| Sprint planning | No | Yes — auto-generates tasks when backlog empties |

---

## How It Works — The Autopilot Cycle

```
  BACKLOG (TASKS.md)
        |
        v
  +-----+-------+     +----------+     +-----------+     +--------------+
  |  Activate   | --> | Spec &   | --> |  Code     | --> | Quality Gate |
  |  task +     |     | Plan     |     |  (Agent)  |     | (lint, test) |
  |  branch     |     +----------+     +-----------+     +--------------+
  +-------------+                                               |
                                                               v
  +-----------+     +-----------+     +----------------------+
  |  Deliver  | <-- |  Review   | <-- | Review Gate          |
  |  merge +  |     |  (Agent)  |     | APPROVE / REJECT     |
  |  cleanup  |     +-----------+     +----------------------+
  +-----------+
        |
        v
   Next task (or sprint planning if backlog empty)
```

**Activate** — highest-priority open task is selected; a `feat/<slug>` branch is created.

**Spec & Plan** — the agent writes a plan and decomposes the task into atomic subtasks.

**Code** — the coding agent implements one subtask at a time, with a configurable diff budget.

**Quality Gate** — `dart format`, `dart analyze`, `dart test` (or your equivalent) run automatically.
Pure format drift is auto-corrected; test failures block progress.

**Review Gate** — an independent review agent assesses the diff and either APPROVEs or REJECTs with
structured feedback. REJECTs consume retry budget; exhausted budget blocks the task.

**Deliver** — approved changes are merged to the base branch, the feature branch is deleted, and the
task is marked done. The cycle returns to Activate.

**Core guarantees**: single-instance lock, fail-closed preflight before every step, mandatory review,
atomic git delivery, full run-log evidence.

---

## Quick Start

### Prerequisites

- Dart SDK >= 3.10
- Git
- At least one AI provider CLI installed and authenticated:
  `claude` (Claude Code), `gemini` (Gemini CLI), `codex`, `vibe`, or `amp`

### 1. Build

```bash
git clone <repo-url> genaisys
cd genaisys
dart compile exe bin/genaisys_cli.dart -o build/genaisys
```

Or run directly without building:

```bash
dart run bin/genaisys_cli.dart <command> <path>
```

### 2. Initialize your project

```bash
# Interactive: creates .genaisys/ with vision, config, and empty task backlog
./build/genaisys init /path/to/your/project

# Agent-driven: feed a PDF, text doc, or description — the init pipeline generates
# vision, architecture, backlog, config, and rules automatically
./build/genaisys init /path/to/your/project --from /path/to/spec.pdf
./build/genaisys init /path/to/your/project --from description.txt
```

### 3. Configure your provider

Edit `.genaisys/config.yml` in your project:

```yaml
providers:
  primary: claude-code       # claude-code | gemini | codex | vibe | amp
  pool:
    - name: claude-code
      binary: claude
    - name: gemini
      binary: gemini
```

### 4. Add tasks

Edit `.genaisys/TASKS.md` — tasks use checkbox format with priority tags:

```markdown
- [ ] [P1] Implement user authentication with JWT tokens
- [ ] [P1] Add database migration for users table
- [ ] [P2] Write integration tests for auth endpoints
- [ ] [P3] Update API documentation
```

### 5. Start the autopilot

```bash
./build/genaisys autopilot run /path/to/your/project
```

Expected output:

```
[12:34:01] autopilot started  task=none  step=0
[12:34:02] task.activated     task=implement-user-authentication  branch=feat/implement-user-authentication
[12:34:15] step.start         subtask=1  agent=claude-code
```

Follow the live run-log in a second terminal:

```bash
./build/genaisys autopilot follow /path/to/your/project
```

See the [Quickstart Guide](docs/guide/quickstart.md) for a full walkthrough including provider setup.

---

## Feature Highlights

### Autonomous Orchestration

- 7-phase state machine: `gateCheck → preflight → stepExecution → stepOutcome → errorRecovery → progressCheck → sleepAndLoop`
- Fail-closed preflight validates git state, config schema, review policy, and provider readiness before every step
- Sprint-based planning: when the backlog empties, `SprintPlannerService` generates the next sprint automatically
- Supervisor meta-orchestrator monitors the autopilot process and auto-restarts it after crashes
- Progress-failure budgets halt task or autopilot instead of burning tokens on repeated failures

```bash
genaisys autopilot run .          # start the autonomous loop
genaisys autopilot follow .       # stream live events from a running autopilot
genaisys autopilot supervisor start .   # start the supervisor watchdog
genaisys autopilot step .         # execute exactly one step manually
```

### Multi-Provider AI

- Supports Claude Code, Gemini CLI, Codex, Vibe, and AMP out of the box
- Unified `AgentRunner` interface — adding a new provider is a single adapter class
- Provider pool with quota-rotation: when one provider hits its limit, the next takes over
- Category-based timeouts and configurable reasoning effort per provider
- Coding and review agents can be different providers

```yaml
providers:
  primary: claude-code
  pool:
    - name: claude-code
      binary: claude
    - name: gemini
      binary: gemini
      quota_per_minute: 10
```

### Three-Layer Safety System

All three layers are **fail-closed**: uncertainty means deny, not allow.

- **Safe-Write** — agent file writes are restricted to whitelisted root paths; writes outside the
  allowlist are blocked and logged before execution
- **Shell Allowlist** — only explicitly listed shell commands may run; no pipes (`|`), no shell
  operators (`&&`, `;`, `>`), no wildcard expansion
- **Diff Budget** — configurable maximum files and maximum lines changed per step; exceeded budget
  blocks the step before the review gate

```yaml
policies:
  safe_write:
    enabled: true
    roots:
      - lib/
      - test/
      - pubspec.yaml
  shell_allowlist:
    - dart format
    - dart analyze
    - dart test
    - flutter build
  diff_budget:
    max_files: 20
    max_lines: 500
```

### Human-in-the-Loop Gates

When running unattended, you may want human sign-off at critical moments — not every step, just the
ones that matter.

- **Gate 1** `after_task_done` — pause after each task completes, before the next activates
- **Gate 2** `before_sprint` — pause before a new sprint is planned and the backlog refilled
- **Gate 3** `before_halt` — pause before a safety halt triggers, allowing human intervention

The autopilot writes a gate file and polls for a decision file. You respond via CLI:

```bash
genaisys hitl status .        # show pending gate and context
genaisys hitl approve .       # autopilot continues
genaisys hitl reject .        # autopilot terminates cleanly
genaisys hitl approve . --note "Reviewed tasks 3-5, all look good"
```

Gates time out (default: 60 min) and can be configured to auto-approve on timeout.

### Observability & Audit

Every event in the autopilot lifecycle is recorded with structured metadata.

- **`RUN_LOG.jsonl`** — append-only structured event log; one JSON object per line with `event`,
  `timestamp`, `step_id`, `task_id`, `error_class`, `error_kind`, and relevant payload fields
- **`genaisys autopilot follow`** — real-time tail of the run-log with colored, human-readable output
- **`genaisys status --json`** — stable machine-readable JSON contract for tooling integration
- **`genaisys diagnostics`** — summarizes error patterns and failure reasons across runs
- All failure paths emit `error_class` and `error_kind` — no silent reliability failures

```bash
genaisys status .             # human-readable project and autopilot state
genaisys status . --json      # JSON output for scripts and dashboards
genaisys health .             # detailed health diagnostic report
genaisys diagnostics .        # error pattern analysis
```

### Orchestrated Init Pipeline

Initialize any project from a document, not just from scratch.

- `genaisys init --from <doc>` accepts PDF (via `pdftotext`), plain text, or stdin
- **6-stage agent pipeline**: Vision → Architecture → Backlog → Config → Rules → Verification
- Each stage generates a specific artifact; Verification stage runs a review agent to check coherence
- Up to 2 retries per stage on REJECT before raising a pipeline error
- Auto-detects project type (Dart, Flutter, Python, Node.js, Rust, Go, Java) to configure quality gates

```bash
# From a PDF specification
genaisys init . --from product-spec.pdf

# From a text description
genaisys init . --from architecture-notes.txt

# From stdin
echo "A CLI tool to manage Kubernetes deployments" | genaisys init . --from -

# Static mode: generate artifacts without running an agent
genaisys init . --from spec.txt --static
```

---

## Configuration

A minimal `config.yml` for a Dart project:

```yaml
providers:
  primary: claude-code
  pool:
    - name: claude-code
      binary: claude

git:
  base_branch: main
  feature_prefix: feat/
  auto_push: false

autopilot:
  selection_mode: fair          # fair | strict_priority | random
  max_failures: 5               # safety halt after N consecutive failures
  max_task_retries: 3           # block task after N review rejections
  sprint_planning_enabled: true # auto-generate new tasks when backlog empties
  min_open: 8                   # minimum open tasks before sprint planning triggers

hitl:
  enabled: false
  timeout_minutes: 60
  gate_after_task_done: false
  gate_before_sprint: true      # pause for human review before each new sprint
  gate_before_halt: true        # pause for human review before safety halt

policies:
  safe_write:
    enabled: true
    roots: [lib/, test/, pubspec.yaml]
  shell_allowlist:
    - dart format
    - dart analyze
    - dart test
  quality_gate:
    enabled: true
    adaptive_by_diff: true
    skip_tests_for_docs_only: true
    commands:
      - dart format --output=none --set-exit-if-changed .
      - dart analyze
      - dart test
```

Full reference with all 150+ keys: [Configuration Reference](docs/reference/configuration-reference.md)

---

## CLI Reference

| Area | Command | Description |
|------|---------|-------------|
| **Setup** | `init [path]` | Initialize project with `.genaisys/` structure |
| | `init [path] --from <doc>` | Agent-driven init from PDF, text, or stdin |
| | `config validate [path]` | Validate project configuration |
| | `config diff [path]` | Show non-default configuration values |
| **Tasks** | `tasks [path]` | List and filter backlog tasks |
| | `next [path]` | Show the next recommended task |
| | `activate [path]` | Activate next task by priority |
| | `activate [path] --id <id>` | Activate a specific task by ID |
| | `done [path]` | Mark active task as done (requires review approval) |
| | `block [path] --id <id>` | Block a task with optional reason |
| | `review [path] approve` | Approve current step's review |
| | `review [path] reject` | Reject current step's review with feedback |
| **Autopilot** | `autopilot run [path]` | Start autonomous processing loop |
| | `autopilot step [path]` | Execute exactly one autopilot step |
| | `autopilot follow [path]` | Stream live run-log events |
| | `autopilot heal [path]` | Incident-based repair step |
| **Supervisor** | `autopilot supervisor start [path]` | Start the supervisor watchdog |
| | `autopilot supervisor stop [path]` | Stop the supervisor |
| | `autopilot supervisor status [path]` | Show supervisor health |
| **HITL** | `hitl status [path]` | Show pending HITL gate |
| | `hitl approve [path]` | Approve the pending gate |
| | `hitl reject [path]` | Reject the pending gate |
| **Diagnostics** | `status [path]` | Project and autopilot state |
| | `health [path]` | Detailed health diagnostic report |
| | `diagnostics [path]` | Error pattern analysis |

Full syntax, flags, and exit codes: [CLI Reference](docs/reference/cli.md)

---

## Supported AI Providers

| Provider | CLI Binary | Authentication |
|----------|-----------|----------------|
| Claude Code | `claude` | Session auth or `ANTHROPIC_API_KEY` |
| Gemini | `gemini` | Session auth or `GEMINI_API_KEY` |
| Codex | `codex` | Session auth (`codex auth`) |
| Vibe | `vibe` | Session auth or `MISTRAL_API_KEY` |
| AMP | `amp` | Session auth or `AMP_API_KEY` |

Provider setup guide: [Providers Guide](docs/guide/providers.md)

---

## Documentation

### Guides

| | |
|---|---|
| [Quickstart](docs/guide/quickstart.md) | Install, initialize, and run your first autonomous task |
| [Project Setup](docs/guide/project-setup.md) | TASKS.md format, config.yml, safe-write roots |
| [Autonomous Execution](docs/guide/autonomous-execution.md) | Autopilot, supervisor, sprint planning |
| [Unattended Operations](docs/guide/unattended-operations.md) | HITL gates, progress budgets, safety halts |
| [Review & Quality](docs/guide/review-and-quality.md) | Quality gate configuration, review flow |
| [Task Management](docs/guide/task-management.md) | Task lifecycle, priority, blocking, retries |
| [Providers](docs/guide/providers.md) | Provider setup, pool configuration, quota rotation |
| [Troubleshooting](docs/guide/troubleshooting.md) | Common issues, deadlock recovery, incident playbook |

### Concepts

| | |
|---|---|
| [Safety System](docs/concepts/safety-system.md) | Safe-Write, Shell Allowlist, Diff Budget — detailed |
| [Agent System](docs/concepts/agent-system.md) | How providers, pools, and the AgentRunner work |
| [State Machine](docs/concepts/state-machine.md) | 7-phase autopilot state machine in detail |
| [Task Lifecycle](docs/concepts/task-lifecycle.md) | From activation to delivery |
| [Review System](docs/concepts/review-system.md) | Review gate, escalation, evidence bundles |
| [Quality Gates](docs/concepts/quality-gates.md) | Adaptive quality gate and profile selection |
| [Orchestration Lifecycle](docs/concepts/orchestration-lifecycle.md) | Full autopilot loop explained |
| [Git Workflow](docs/concepts/git-workflow.md) | Branch strategy, atomic delivery, conflict handling |
| [Pipeline Stages](docs/concepts/pipeline-stages.md) | Init pipeline stages and retry semantics |

### Reference

| | |
|---|---|
| [CLI Reference](docs/reference/cli.md) | All 40+ commands with full syntax and flags |
| [Configuration Reference](docs/reference/configuration-reference.md) | All 150+ config keys with defaults |
| [Run-Log Schema](docs/reference/run-log-schema.md) | All event types, fields, and examples |
| [Data Contracts](docs/reference/data-contracts.md) | Stable JSON contracts for `status --json` and APIs |
| [State JSON Schema](docs/reference/state-json-schema.md) | STATE.json schema and field definitions |
| [Exit Codes](docs/reference/exit-codes.md) | All CLI exit codes and their meanings |
| [Presets](docs/reference/presets.md) | Built-in config presets (strict, relaxed, docs-only) |

### Architecture

| | |
|---|---|
| [Architecture Overview](docs/architecture/overview.md) | Layer boundaries, core modules, dependency rules |
| [GUI Architecture](docs/architecture/gui-architecture.md) | Desktop shell layout, state management, widget tree |

### Project

| | |
|---|---|
| [Vision](docs/project/vision.md) | Long-term mission and design philosophy |
| [Roadmap](docs/project/roadmap.md) | Phase plan, current status, upcoming milestones |
| [Capability Gaps](docs/project/capability-gaps.md) | Known limitations and deferred work |
| [Glossary](docs/glossary.md) | 50+ Genaisys-specific terms defined |

---

## Current Status & Roadmap

**Phase 2 — Stabilization & Native Runtime Transition (Active)**

Completed:
- Phase 2c: Orchestrated Init Pipeline (PDF/text/stdin → full project setup)
- Phase 2g: CLI Output System (rich TTY + plain headless modes)
- Phase 2h: Orchestrator State Machine refactor (7-phase, ~400 lines eliminated)
- Phase 2i: Configurable HITL gates (3 checkpoints, CLI + GUI + API)
- Wave 3: 10 robustness fixes (exception handling, SHA reachability, lock TOCTOU, hot-reload)
- Wave 4: 10 robustness fixes (stash double-failure, config hot-reload parity, OOM guards)
- Refactoring Phases 1–3: git_service mixin composition, state handler part-split, config sub-views

Upcoming:
- Phase 2d: Rich Task Model (structured metadata, dependencies, acceptance criteria)
- Phase 2e: Supervised Autopilot (multi-project orchestration from a single supervisor)
- Phase 2f: Security Scan integration (static analysis, secret scanning)
- Phase 2j: Native runtime transition (replace CLI-based agent execution)

Test count: **2653 passing**, 0 known flaky.

Full plan: [Roadmap](docs/project/roadmap.md)

---

## Contributing

Clone the repo, run `dart test` to verify your environment, and read [CLAUDE.md](CLAUDE.md) (also
available as [AGENTS.md](AGENTS.md)) for the full agent and contributor guidelines.

Key rules:
- English only — all code, comments, commit messages, and docs
- No new dependencies without justification in the PR description
- Every behavior change requires new or updated tests
- Zero analyzer issues (`dart analyze`) before merge
- Follow the Genaisys Way: Understand → Plan → Atomic Implementation → Verify → Review-Gate → Deliver

Contributor docs: [Contributing Guide](docs/contributing/README.md) |
[Code Standards](docs/contributing/code-standards.md) |
[Testing Guidelines](docs/contributing/testing-guidelines.md) |
[Development Setup](docs/contributing/development-setup.md)

---

## License

Source-available under the **Business Source License 1.1 (BSL 1.1)**.

Free for non-commercial use and internal business use. Commercial use (embedding Genaisys in a
product or service offered to third parties) requires a separate commercial license.

The BSL Change Date is four years from first publication, after which this software is released
under an open-source license.

See [LICENSE](LICENSE) for the full license text and terms.
