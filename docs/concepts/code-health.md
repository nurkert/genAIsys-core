[Home](../README.md) > [Concepts](./README.md) > Code Health

# Code Health

Genaisys uses a 3-layer detection system to monitor and improve code quality during autonomous operation.

---

## Overview

The `CodeHealthService` evaluates every delivery to detect code quality issues before they accumulate into technical debt. Each layer progressively deepens the analysis.

## Layer 1: Static Metrics

Rule-based analysis of code structure without AI involvement:

| Metric | Config Key | Default |
|--------|-----------|---------|
| Maximum file length | `code_health.max_file_lines` | 500 |
| Maximum method length | `code_health.max_method_lines` | 50 |
| Maximum nesting depth | `code_health.max_nesting_depth` | 4 |
| Maximum parameter count | `code_health.max_parameter_count` | 5 |

When a metric threshold is exceeded, a code health signal is generated with the file path, metric name, and measured value.

## Layer 2: Deja-Vu Detection

Pattern-based detection of recurring code patterns across deliveries:

- **Hotspot detection**: Files that are modified frequently within a time window indicate instability. Config keys: `code_health.hotspot_threshold`, `code_health.hotspot_window`.
- **Patch clustering**: When multiple deliveries touch overlapping file sets, it may indicate poor decomposition. Config key: `code_health.patch_cluster_min`.

Deja-vu signals are generated from the code health ledger (a persistent record of all delivery metrics).

## Layer 3: LLM Reflection

When Layer 2 signals are detected and LLM reflection is enabled, the system invokes a language model to perform deeper architectural analysis:

- Reviews the flagged patterns in context
- Assesses whether the pattern indicates a genuine design issue
- Suggests specific refactoring actions
- Budget-limited by `code_health.llm_budget_tokens`

Config keys: `code_health.reflection_enabled`, `code_health.reflection_cadence`.

## Automatic Task Creation

When `code_health.auto_create_tasks` is enabled, the service automatically adds refactoring tasks to the backlog for detected issues. Tasks are created with a minimum confidence threshold (`code_health.min_confidence`) and limited by `code_health.max_refactor_ratio` to prevent flooding the backlog.

## Feature Blocking

When `code_health.block_features` is enabled, new feature tasks are blocked until outstanding code health issues fall below the acceptable threshold. This enforces the "fix before feature" discipline.

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `code_health.enabled` | `true` | Enable code health detection |
| `code_health.auto_create_tasks` | `false` | Auto-create refactoring tasks |
| `code_health.min_confidence` | 0.7 | Minimum confidence for task creation |
| `code_health.max_refactor_ratio` | 0.3 | Max ratio of refactor tasks in backlog |
| `code_health.max_file_lines` | 500 | Layer 1: file length threshold |
| `code_health.max_method_lines` | 50 | Layer 1: method length threshold |
| `code_health.max_nesting_depth` | 4 | Layer 1: nesting depth threshold |
| `code_health.max_parameter_count` | 5 | Layer 1: parameter count threshold |
| `code_health.hotspot_threshold` | 3 | Layer 2: modification frequency threshold |
| `code_health.hotspot_window` | 7 | Layer 2: window in days |
| `code_health.patch_cluster_min` | 3 | Layer 2: min patches for cluster detection |
| `code_health.reflection_enabled` | `false` | Layer 3: enable LLM reflection |
| `code_health.reflection_cadence` | 5 | Layer 3: deliveries between reflections |
| `code_health.llm_budget_tokens` | 4000 | Layer 3: token budget per reflection |
| `code_health.block_features` | `false` | Block features until health improves |

---

## Related Documentation

- [Quality Gates](quality-gates.md) — Pre-review verification pipeline
- [Self-Improvement](self-improvement.md) — Reflection and optimization systems
- [Configuration Reference](../reference/configuration-reference.md) — All code health keys
