[Home](../README.md) > [Guides](./README.md) > Project Setup

# Project Setup

How to initialize a project with Genaisys and understand the `.genaisys/` directory structure.

---

## Contents

- [Initialization](#initialization)
- [Directory Structure](#directory-structure)
- [Configuration](#configuration)
- [Project Type Detection](#project-type-detection)
- [Health Check](#health-check)

---

## Initialization

Initialize Genaisys in an existing git repository:

```bash
genaisys init /path/to/project
```

Or in the current directory:

```bash
genaisys init
```

To reinitialize (overwrite existing files):

```bash
genaisys init --overwrite
```

The `init` command:
1. Detects the [project type](../reference/project-types.md) by scanning for marker files
2. Generates a language-appropriate `config.yml`
3. Creates the full `.genaisys/` directory tree
4. Sets up a `.gitignore` for runtime artifacts

## Directory Structure

```
.genaisys/
  config.yml              # Project configuration (policies, providers, autopilot)
  STATE.json              # Runtime state (active task, counters, review status)
  VISION.md               # Project vision (injected into agent prompts)
  RULES.md                # Project rules for AI agents
  TASKS.md                # Task backlog (priorities, categories, status)
  RUN_LOG.jsonl           # Structured audit trail
  .gitignore              # Excludes runtime artifacts from git

  agent_contexts/         # Architecture context files for agent prompts
  task_specs/             # Per-task specs, plans, and subtasks
    {task-id}/
      spec.md
      plan.md
      subtasks.md
  attempts/               # Archived agent outputs and incident bundles
  workspaces/             # Temporary simulation/eval workspaces
  locks/                  # Process locks (autopilot.lock)
  audit/                  # Error patterns, provider state, trends
  evals/                  # Evaluation harness results
  releases/               # Release candidate snapshots
  logs/                   # Log rotation archive
    run_log_archive/      # Rotated RUN_LOG segments
```

### Key Files

| File | Purpose | Tracked in Git |
|------|---------|---------------|
| `config.yml` | Project configuration | Yes |
| `VISION.md` | Long-term project goals | Yes |
| `RULES.md` | Agent behavioral rules | Yes |
| `TASKS.md` | Task backlog | Yes |
| `STATE.json` | Runtime state | No (gitignored) |
| `RUN_LOG.jsonl` | Audit trail | No (gitignored) |
| `locks/` | Process locks | No (gitignored) |

## Configuration

The generated `config.yml` contains language-appropriate defaults. Key sections:

```yaml
# Provider setup
providers:
  primary: claude-code
  pool:
    - claude-code@default

# Git workflow
git:
  base_branch: main
  feature_prefix: feat/

# Safety policies
policies:
  safe_write:
    enabled: true
    roots: [lib, test, docs]
  quality_gate:
    enabled: true
    commands:
      - dart format --output=none --set-exit-if-changed .
      - dart analyze
      - dart test

# Autopilot behavior
autopilot:
  selection_mode: fair
  max_failures: 5
  max_task_retries: 3
```

See [Configuration Guide](configuration.md) for tuning options and [Configuration Reference](../reference/configuration-reference.md) for all 150+ keys.

### Validate Configuration

```bash
genaisys config validate
```

### Show Non-Default Values

```bash
genaisys config diff
```

## Project Type Detection

During `init`, Genaisys scans for well-known build files:

| Priority | Type | Marker |
|----------|------|--------|
| 1 | Dart/Flutter | `pubspec.yaml` |
| 2 | Node.js | `package.json` |
| 3 | Python | `pyproject.toml`, `requirements.txt`, `setup.py` |
| 4 | Rust | `Cargo.toml` |
| 5 | Go | `go.mod` |
| 6 | Java | `pom.xml`, `build.gradle` |

Each type generates appropriate [quality gate](../glossary.md#quality-gate) commands and [shell allowlist](../glossary.md#shell-allowlist) entries. See [Project Types](../reference/project-types.md) for full details.

## Health Check

After initialization, verify everything is working:

```bash
genaisys health --json
```

This checks:
- Project structure (`.genaisys/` exists)
- Git repository (valid, clean)
- Configuration (schema valid)
- Provider readiness (CLI installed, credentials available)

---

## Related Documentation

- [Quickstart](quickstart.md) — Full setup walkthrough
- [Configuration](configuration.md) — Config tuning guide
- [Project Types](../reference/project-types.md) — Language-specific defaults
- [Data Contracts](../reference/data-contracts.md) — Artifact schemas
