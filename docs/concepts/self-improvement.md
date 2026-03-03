[Home](../README.md) > [Concepts](./README.md) > Self-Improvement

# Self-Improvement

Genaisys includes multiple feedback loops that allow the orchestrator to learn from past performance and improve autonomously.

---

## Reflection Service

The [reflection](../glossary.md#reflection) service performs periodic meta-analysis of autopilot productivity:

1. **Trigger**: Runs after a configurable number of loops, tasks, or hours
2. **Analysis**: Reviews recent run log entries for failure patterns, retry rates, and success metrics
3. **Action**: Creates optimization tasks in the backlog targeting identified issues

### Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `reflection.enabled` | `true` | Enable periodic reflection |
| `reflection.trigger_mode` | `loop_count` | Trigger: `loop_count`, `task_count`, or `hours` |
| `reflection.trigger_loop_count` | 10 | Loops between reflections |
| `reflection.trigger_task_count` | 5 | Tasks between reflections |
| `reflection.trigger_hours` | 4 | Hours between reflections |
| `reflection.min_samples` | 5 | Minimum events for meaningful analysis |
| `reflection.max_optimization_tasks` | 3 | Max tasks created per reflection |
| `reflection.optimization_task_priority` | `P2` | Priority for generated tasks |
| `reflection.analysis_window_lines` | 500 | Run log lines to analyze |

## Self-Tune

The [self-tune](../glossary.md#self-tune) system adjusts autopilot configuration parameters based on observed performance:

- Analyzes success rates across recent steps
- Adjusts retry limits, sleep timers, and other parameters
- Only applies changes when confidence is high (sufficient samples)
- Records before/after values in the run log

Available via `genaisys autopilot improve --no-meta --no-eval`.

## Error Pattern Learning

The `ErrorPatternRegistryService` maintains a persistent registry of observed error patterns:

- **Recording**: After each analysis window, error kinds and counts are merged into `.genaisys/audit/error_patterns.json`
- **Injection**: Top patterns (up to 5, max 1000 chars) are injected into coding prompts as preventive guidance
- **Resolution tracking**: When an error kind is resolved, the strategy is recorded (first-strategy-wins)
- **Optimization**: Patterns with 5+ occurrences and no resolution strategy trigger optimization task creation

Config key: `pipeline.error_pattern_learning_enabled` (default: `true`)

## Evaluation Harness

The evaluation harness runs end-to-end tests on isolated workspaces to measure pipeline quality:

- Creates temporary projects with synthetic tasks
- Runs full autopilot cycles in isolated workspaces
- Measures success rate, diff quality, and policy compliance
- Results stored in `.genaisys/evals/`

Available via `genaisys autopilot improve --no-tune`.

## Supervisor Reflection

When the supervisor halts, it can automatically trigger a reflection analysis:

- Analyzes the pattern that led to the halt
- Creates targeted optimization tasks
- Records patterns in the run log for operator review

Config key: `supervisor.reflection_on_halt` (default: `true`)

## Context Injection

The pipeline injects accumulated knowledge into agent prompts:

| Feature | Config Key | Default | Description |
|---------|-----------|---------|-------------|
| Architecture context | `pipeline.context_injection_enabled` | `true` | Project architecture and rules |
| Error patterns | `pipeline.error_pattern_injection_enabled` | `true` | Known failure patterns |
| Impact analysis | `pipeline.impact_analysis_enabled` | `false` | Estimated change scope |
| Architecture gate | `pipeline.architecture_gate_enabled` | `false` | Import graph validation |
| Forensic recovery | `pipeline.forensic_recovery_enabled` | `false` | Stuck-state recovery |

---

## Related Documentation

- [Code Health](code-health.md) — 3-layer quality detection
- [Orchestration Lifecycle](orchestration-lifecycle.md) — Pipeline steps
- [Unattended Operations](../guide/unattended-operations.md) — Operative intelligence features
- [Configuration Reference](../reference/configuration-reference.md) — All pipeline and reflection keys
