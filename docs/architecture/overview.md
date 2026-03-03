[Home](../README.md) > [Architecture](./README.md) > Overview

# Architecture Overview

Genaisys follows a strict 3-layer architecture that separates business logic, CLI presentation, and desktop GUI into independently developable modules.

---

## Layer Diagram

```
┌──────────────────────────────────────────────────┐
│                   lib/ui/desktop/                 │  Flutter Desktop GUI
│         widgets, controllers, theme, models       │  (optional -- CLI works without it)
├──────────────────────────────────────────────────┤
│                   lib/desktop/                    │  Platform Integration
│         window services, windowing adapters       │  (macOS/Windows/Linux)
├──────────────────────────────────────────────────┤
│                   lib/core/cli/                   │  CLI Adapter
│         handlers, presenters, runner              │  (argument parsing, text/JSON output)
├──────────────────────────────────────────────────┤
│                   lib/core/app/                   │  Application Boundary
│         use cases, DTOs, API contracts            │  (GenaisysApi, AppResult, AppError)
├──────────────────────────────────────────────────┤
│                   lib/core/                       │  Core Engine
│         services, policy, config, git, agents,    │  (orchestrator, state machine, safety)
│         storage, models                           │
└──────────────────────────────────────────────────┘
```

## Dependency Rules

| Source Layer | May Import From | Must Never Import |
|---|---|---|
| `lib/core/` | `lib/core/` only | `lib/core/cli/`, `lib/ui/`, `lib/desktop/` |
| `lib/core/app/` | `lib/core/` | `lib/core/cli/`, `lib/ui/`, `lib/desktop/` |
| `lib/core/cli/` | `lib/core/`, `lib/core/app/` | `lib/ui/`, `lib/desktop/` |
| `lib/desktop/` | `lib/core/`, `lib/core/app/` | `lib/ui/` (except theme tokens) |
| `lib/ui/` | `lib/core/app/`, `lib/desktop/` (via interfaces) | `lib/core/cli/` |

These rules are enforced by architecture boundary tests in CI.

## Core Engine (`lib/core/`)

The heart of Genaisys. Contains all business logic with zero Flutter dependencies.

**Key subsystems:**
- **Orchestrator** -- 7-phase state machine driving the autopilot loop
- **Services** -- Task management, review, delivery, coding agent invocation
- **Policy** -- Safe-Write, Shell Allowlist, Diff Budget
- **Config** -- Schema-validated configuration with 150+ keys and 3 presets
- **Git** -- Branch-per-task workflow, merge, stash, cleanup
- **Agents** -- Provider adapters (Claude Code, Gemini, Codex, Vibe, AMP)
- **Storage** -- Atomic-write persistence for STATE.json, TASKS.md, RUN_LOG.jsonl

## Application Boundary (`lib/core/app/`)

A stable API surface for consumers (GUI, tests, tooling):
- `GenaisysApi` -- In-process API contract
- `InProcessGenaisysApi` -- Implementation delegating to core services
- `AppResult<T>` / `AppError` -- Typed result wrapper (no exceptions across boundary)
- DTOs -- GUI-safe data transfer objects

See [ADR-0001: Core Interface Boundary](adr/0001-core-interface-boundary.md) for the design rationale.

## CLI Adapter (`lib/core/cli/`)

Thin adapter layer for terminal interaction:
- **Handlers** -- One per command, parse arguments, delegate to core services
- **Presenters** -- Format output as text or JSON
- **Runner** -- Command dispatch and error handling

The CLI is a first-class interface, not a wrapper. Genaisys must remain fully controllable via CLI without any GUI dependency.

## Desktop GUI (`lib/ui/` + `lib/desktop/`)

Optional Flutter desktop frontend:
- **Platform services** (`lib/desktop/`) -- Window management abstracted behind `WindowServiceInterface`
- **UI layer** (`lib/ui/desktop/`) -- Widgets, controllers, theme tokens, localization

The GUI communicates exclusively through `lib/core/app/` contracts. No direct core service imports.

See [GUI Architecture](gui-architecture.md) for the full widget tree and state management design.

## API Barrels

```dart
import 'package:genaisys/core/core.dart';       // Core + App (no CLI)
import 'package:genaisys/core/app/app.dart';     // App boundary only
import 'package:genaisys/core/cli/cli.dart';     // CLI adapter
```

---

## Related Documentation

- [GUI Architecture](gui-architecture.md) -- Widget tree, state management, shell layout
- [GUI Development Guide](gui-development-guide.md) -- How to extend the GUI
- [UI Engineering Guardrails](ui-engineering-guardrails.md) -- Boundary rules and isolation
- [Core Interface Boundary (ADR-0001)](adr/0001-core-interface-boundary.md) -- Design rationale
