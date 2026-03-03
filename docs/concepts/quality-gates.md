[Home](../README.md) > [Concepts](./README.md) > Quality Gates

# Quality Gates

The [quality gate](../glossary.md#quality-gate) pipeline runs automated verification commands after each coding step and before review. It ensures code meets formatting, analysis, and testing standards.

---

## Pipeline

Quality gate commands run in the order defined in `config.yml`. If any command fails (non-zero exit code), the step is marked as a quality gate failure and the coding agent receives the error output for retry.

### Default Pipeline (Dart/Flutter)

```yaml
policies:
  quality_gate:
    enabled: true
    commands:
      - dart format --output=none --set-exit-if-changed .
      - dart analyze
      - dart test
```

### Execution Order

1. **Format** — Code formatting check
2. **Analyze** — Static analysis / linting
3. **Test** — Test suite execution

Auto-format runs before the quality gate so that pure format drift does not produce reject loops.

## Position in the 12-Stage Pipeline

The quality gate (Stage 9) runs as part of the broader [task pipeline](./pipeline-stages.md). The stages that precede and follow it are relevant context:

| Stage | Name | Purpose |
|-------|------|---------|
| 3 | AutoFormat | Applies formatter automatically (before QG, so format drift never causes reject loops) |
| 5 | TestDeltaGate | Runs only tests for changed files — fast-fail before the full suite |
| 6 | DiffBudget | Checks file/line change limits — rejects oversized diffs before QG |
| **9** | **QualityGate** | Runs full configured command pipeline (this document) |
| 10 | ArchitectureGate | Import-graph integrity check — runs after QG passes |
| 11 | AcSelfCheck | Agent self-verification of acceptance criteria |

### Test Delta Gate (Stage 5)

Before the full quality gate runs, the `TestDeltaGate` performs a targeted pre-check. It computes which test files correspond to the changed source files and runs only those tests first. This fast-fail check catches the most obvious failures immediately — avoiding the cost of the full quality gate suite when targeted tests already reveal the problem.

Config key: `policies.quality_gate.test_delta_gate_enabled` (default: `true`)

If the targeted tests fail, the step is rejected with `test_delta_failure` without running the full test suite.

### Required Files Check (Stage 8)

Immediately before the quality gate, the pipeline checks that every file declared as required by the task specification is present. Missing required files cause an immediate reject (`missing_required_files`) before any quality commands run.

### AcSelfCheck (Stage 11)

After the quality gate passes, the coding agent performs a self-check against the task's acceptance criteria. If the agent concludes its own delivery does not satisfy the AC, it rejects early without burning a review-agent call (`ac_self_check_failed`).

---

## Adaptive Diff

When `adaptive_by_diff` is enabled, the quality gate narrows its scope based on what files changed:

- **Docs-only changes**: Tests may be skipped entirely (`skip_tests_for_docs_only`)
- **Lib-only Dart changes**: May prefer `dart test` over `flutter test` (`prefer_dart_test_for_lib_dart_only`)
- **Format commands**: Scoped to changed files only

Config key: `policies.quality_gate.adaptive_by_diff` (default: `true` for Dart projects)

## Flake Retry

Flaky tests can be automatically retried. Config key: `policies.quality_gate.flake_retry_count` (default: 1).

When a test command fails:
1. The quality gate retries the specific command up to `flake_retry_count` times
2. If any retry succeeds, the command is considered passed
3. If all retries fail, the failure is real

## Timeout

Quality gate commands have a configurable timeout. Config key: `policies.quality_gate.timeout_seconds` (default: 300).

## Language-Specific Defaults

Each project type gets appropriate quality gate commands during `genaisys init`:

| Language | Format | Analyze | Test |
|----------|--------|---------|------|
| Dart/Flutter | `dart format` | `dart analyze` | `dart test` |
| Node.js | `npx prettier --check .` | `npx eslint .` | `npm test` |
| Python | `ruff format --check .` | `ruff check .` | `pytest` |
| Rust | `cargo fmt --check` | `cargo clippy -- -D warnings` | `cargo test` |
| Go | `gofmt -l .` | `golangci-lint run` | `go test ./...` |
| Java | — | `mvn compile` | `mvn test` |

See [Project Types](../reference/project-types.md) for full details.

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `policies.quality_gate.enabled` | `true` | Enable/disable quality gate |
| `policies.quality_gate.adaptive_by_diff` | varies | Scope commands to changed files |
| `policies.quality_gate.skip_tests_for_docs_only` | `true` | Skip tests for documentation-only diffs |
| `policies.quality_gate.flake_retry_count` | 1 | Number of retries for flaky tests |
| `policies.quality_gate.timeout_seconds` | 300 | Command timeout |
| `policies.quality_gate.commands` | (language-specific) | Ordered list of verification commands |

---

## Related Documentation

- [Pipeline Stages](./pipeline-stages.md) — Full 12-stage pipeline including TestDeltaGate and AcSelfCheck
- [Safety System](safety-system.md) — Policy layers (Safe-Write, Shell Allowlist, Diff Budget)
- [Review System](review-system.md) — What happens after quality gate passes
- [Project Types](../reference/project-types.md) — Language-specific defaults
- [Configuration Reference](../reference/configuration-reference.md) — All quality gate keys
