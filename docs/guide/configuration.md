[Home](../README.md) > [Guides](./README.md) > Configuration

# Configuration

How to configure Genaisys through `.genaisys/config.yml`.

---

## Overview

All project-level configuration lives in `.genaisys/config.yml`. The file is schema-validated on every read — invalid config blocks operation ([fail-closed](../glossary.md#fail-closed)).

### Validate Configuration

```bash
genaisys config validate
```

### Show Non-Default Values

```bash
genaisys config diff
```

## Config Sections

### Providers

```yaml
providers:
  primary: claude-code
  fallback: gemini
  pool:
    - claude-code@default
    - gemini@default
  quota_cooldown_seconds: 60
  quota_pause_seconds: 300
```

See [Providers](providers.md) for setup details.

### Git

```yaml
git:
  base_branch: main
  feature_prefix: feat/
  auto_delete_remote_merged_branches: false
  auto_stash: true
  sync_between_loops: true
  sync_strategy: rebase
```

### Policies

```yaml
policies:
  safe_write:
    enabled: true
    roots: [lib, test, docs, .genaisys/task_specs, .genaisys/agent_contexts]

  quality_gate:
    enabled: true
    adaptive_by_diff: true
    skip_tests_for_docs_only: true
    flake_retry_count: 1
    timeout_seconds: 300
    commands:
      - dart format --output=none --set-exit-if-changed .
      - dart analyze
      - dart test

  diff_budget:
    max_files: 20
    max_additions: 2000
    max_deletions: 1500

  shell_allowlist_profile: standard
  shell_allowlist:
    - dart format
    - dart analyze
    - dart test
```

### Workflow

```yaml
workflow:
  require_review: true
  auto_commit: true
  auto_push: true
  auto_merge: false
  merge_strategy: merge
```

### Autopilot

```yaml
autopilot:
  selection_mode: fair
  fairness_window: 12
  priority_weight_p1: 3
  priority_weight_p2: 2
  priority_weight_p3: 1

  min_open: 8
  max_plan_add: 4
  step_sleep_seconds: 2
  idle_sleep_seconds: 30
  max_steps: 100
  max_failures: 5
  max_task_retries: 3

  reactivate_blocked: false
  reactivate_failed: true
  blocked_cooldown_seconds: 0
  failed_cooldown_seconds: 0

  self_heal_enabled: true
  self_restart: false
  lock_ttl_seconds: 600
```

### Review

```yaml
review:
  fresh_context: true
  strictness: standard
  max_rounds: 5
  require_evidence: true
  evidence_min_length: 50
```

### Pipeline

```yaml
pipeline:
  context_injection_enabled: true
  error_pattern_injection_enabled: true
  error_pattern_learning_enabled: true
  impact_analysis_enabled: false
  architecture_gate_enabled: false
  forensic_recovery_enabled: false
```

### Reflection

```yaml
reflection:
  enabled: true
  trigger_mode: loop_count
  trigger_loop_count: 10
  min_samples: 5
  max_optimization_tasks: 3
```

### Supervisor

```yaml
supervisor:
  reflection_on_halt: true
  max_interventions_per_hour: 5
  check_interval_seconds: 30
```

## Presets

Three built-in [presets](../glossary.md#config-preset) provide optimized defaults:

| Preset | Use Case | Key Settings |
|--------|----------|-------------|
| `conservative` | Safety-first | Low retries (2), strict scope (30 files) |
| `aggressive` | Fast iteration | High retries (5), large scope (100 files), no sleep |
| `overnight` | Unattended | 500 max steps, 8h wall clock, self-restart |

See [Presets Reference](../reference/presets.md) for full details.

## Key Tuning Knobs

### Speed vs Safety

| Faster | Safer |
|--------|-------|
| `step_sleep_seconds: 0` | `step_sleep_seconds: 5` |
| `max_task_retries: 5` | `max_task_retries: 2` |
| `review.strictness: lenient` | `review.strictness: strict` |
| `scope_max_files: 100` | `scope_max_files: 20` |

### Throughput

| More Work | Less Risk |
|-----------|-----------|
| `max_steps: 500` | `max_steps: 20` |
| `stop_when_idle: false` | `stop_when_idle: true` |
| `reactivate_blocked: true` | `reactivate_blocked: false` |

---

## Related Documentation

- [Configuration Reference](../reference/configuration-reference.md) — All 150+ keys with types, defaults, ranges
- [Presets](../reference/presets.md) — Built-in configuration profiles
- [Project Setup](project-setup.md) — Initial configuration
- [Providers](providers.md) — Provider-specific setup
