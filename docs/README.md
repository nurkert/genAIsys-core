# Genaisys Documentation

Welcome to the Genaisys documentation. Genaisys is a desktop-first orchestrator for AI-assisted software delivery — it manages the full lifecycle from task planning through code generation, review, and delivery.

---

## Quick Links

| I want to... | Start here |
|---|---|
| Get up and running fast | [Quickstart Guide](guide/quickstart.md) |
| Understand the project concept | [Vision](project/vision.md) |
| Run the autopilot | [Autonomous Execution](guide/autonomous-execution.md) |
| Look up a CLI command | [CLI Reference](reference/cli.md) |
| Find a config key | [Configuration Reference](reference/configuration-reference.md) |
| Contribute code | [Development Setup](contributing/development-setup.md) |

---

## Documentation Map

### [Guides](guide/) — How to use Genaisys

Step-by-step instructions for common workflows.

- [Quickstart](guide/quickstart.md) — Install, initialize, run your first cycle
- [Project Setup](guide/project-setup.md) — Initialization, `.genaisys/` structure, project types
- [Task Management](guide/task-management.md) — TASKS.md format, priorities, blocking, cooldowns
- [Manual Workflow](guide/manual-workflow.md) — Step-by-step attended CLI flow
- [Autonomous Execution](guide/autonomous-execution.md) — autopilot run/step/follow, supervisor, pilot
- [Unattended Operations](guide/unattended-operations.md) — Overnight runs, systemd, profiles, incidents
- [Review & Quality](guide/review-and-quality.md) — Review gates, quality gates, evidence bundles
- [Configuration](guide/configuration.md) — config.yml overview, presets, key tuning knobs
- [Providers](guide/providers.md) — Provider setup (Claude, Gemini, Codex, Vibe, AMP)
- [Troubleshooting](guide/troubleshooting.md) — Diagnostics, common errors, recovery

### [Concepts](concepts/) — How things work

Deep explanations of Genaisys internals.

- [Orchestration Lifecycle](concepts/orchestration-lifecycle.md) — Grand cycle: vision to backlog to delivery
- [State Machine](concepts/state-machine.md) — 7-phase orchestrator (gateCheck to sleepAndLoop)
- [Task Lifecycle](concepts/task-lifecycle.md) — Task states, transitions, retry budgets
- [Safety System](concepts/safety-system.md) — Safe-Write, Shell Allowlist, Diff Budget
- [Review System](concepts/review-system.md) — Review policy, evidence, DoD, escalation
- [Quality Gates](concepts/quality-gates.md) — QG pipeline, adaptive diff, language profiles
- [Code Health](concepts/code-health.md) — 3-layer detection (metrics, deja-vu, reflection)
- [Agent System](concepts/agent-system.md) — Agent roles, provider pool, quota, fallback
- [Self-Improvement](concepts/self-improvement.md) — Reflection, self-tune, error pattern learning
- [Git Workflow](concepts/git-workflow.md) — Branch-per-task, merge, stash, cleanup
- [Security Model](concepts/security-model.md) — Threat model, redaction, fail-closed policies
- [Subtask Decomposition](concepts/subtask-decomposition.md) — Subtask queue, scheduling, retry within task

### [Reference](reference/) — Lookup tables and specifications

Exhaustive, searchable details.

- [CLI Commands](reference/cli.md) — All 30 commands with syntax, flags, examples
- [Configuration Reference](reference/configuration-reference.md) — All 150+ config keys with types, defaults, ranges
- [Presets](reference/presets.md) — conservative / aggressive / overnight details
- [Project Types](reference/project-types.md) — Language detection, default profiles
- [STATE.json Schema](reference/state-json-schema.md) — STATE.json fields, types, transitions
- [Run Log Schema](reference/run-log-schema.md) — RUN_LOG.jsonl event catalog
- [Data Contracts](reference/data-contracts.md) — All `.genaisys/` artifacts and schemas
- [Exit Codes](reference/exit-codes.md) — CLI exit code table

### [Architecture](architecture/) — System design and decisions

- [Overview](architecture/overview.md) — 3-layer architecture (core/cli/ui), dependency rules
- [Core Interface Boundary](architecture/adr/0001-core-interface-boundary.md) — ADR-0001: app API boundary
- [GUI Architecture](architecture/gui-architecture.md) — GUI shell, widget tree, state management
- [GUI Development Guide](architecture/gui-development-guide.md) — How to extend the GUI
- [UI Design System](architecture/ui-design-system.md) — Tokens, spacing, radius, motion, theme
- [UI Engineering Guardrails](architecture/ui-engineering-guardrails.md) — 3rd-party isolation, transparency rules
- [UI Visual Identity](architecture/ui-visual-identity.md) — Premium White & Bronze CI
- [ADR Index](architecture/adr/README.md) — Architecture Decision Records

### [Contributing](contributing/) — Developer onboarding

- [Development Setup](contributing/development-setup.md) — Clone, build, test, IDE setup
- [Code Standards](contributing/code-standards.md) — Dart style, scout rule, dependency hygiene
- [Adding Config Keys](contributing/adding-config-keys.md) — 3-step registry pattern
- [Adding CLI Commands](contributing/adding-cli-commands.md) — Handler + presenter pattern
- [Adding Providers](contributing/adding-providers.md) — AgentRunner interface, registration
- [Testing Guidelines](contributing/testing-guidelines.md) — CI determinism, resource safety, conventions
- [Agent Guidelines](contributing/agent-guidelines.md) — Condensed CLAUDE.md for AI agents

### [Project](project/) — Vision and roadmap

- [Vision](project/vision.md) — Mission, philosophy, sovereign orchestration
- [Roadmap](project/roadmap.md) — Phased plan, current Phase 2 status
- [Capability Gaps](project/capability-gaps.md) — Known gaps, future targets

### [Glossary](glossary.md) — Terminology reference

50+ Genaisys-specific terms defined and cross-linked.

---

## Conventions

- **Cross-linking**: Every guide links to its concept and reference counterpart. First use of a Genaisys-specific term links to the [glossary](glossary.md).
- **Breadcrumbs**: Each page has a navigation breadcrumb at the top.
- **Language**: All documentation is in English.
