[Home](../README.md) > [Guides](./README.md) > Review & Quality

# Review & Quality

How to use and configure [review gates](../glossary.md#review-gate) and [quality gates](../glossary.md#quality-gate) in Genaisys.

---

## Quality Gate

The quality gate runs automated verification after each coding step.

### Viewing Quality Gate Config

```bash
genaisys config diff --json  # Shows non-default quality gate settings
```

### Customizing Commands

Edit `.genaisys/config.yml`:

```yaml
policies:
  quality_gate:
    enabled: true
    commands:
      - "npm run lint"
      - "npm run test:ci"
```

Commands run in order. If any fails, the step is marked as a quality gate failure.

### Adaptive Diff Mode

Enable scoped quality checks based on what changed:

```yaml
policies:
  quality_gate:
    adaptive_by_diff: true
    skip_tests_for_docs_only: true
```

This skips tests when only documentation files changed, reducing unnecessary CI time.

### Flake Retry

Handle flaky tests automatically:

```yaml
policies:
  quality_gate:
    flake_retry_count: 2  # Retry failed test commands up to 2 times
```

## Review Gate

The review gate ensures independent assessment of every code change.

### Check Review Status

```bash
genaisys review status
genaisys review status --json
```

### Manual Review Decisions

```bash
# Approve after inspection
genaisys review approve --note "LGTM, tests pass"

# Reject with feedback
genaisys review reject --note "Missing error handling in the auth module"

# Clear review status (start fresh)
genaisys review clear
```

### Review Configuration

```yaml
review:
  fresh_context: true       # Review agent gets no context from coding agent
  strictness: standard      # strict | standard | lenient
  max_rounds: 5             # Max review attempts before blocking
  require_evidence: true    # Require evidence bundle
  evidence_min_length: 50   # Minimum evidence text length
```

### Strictness Levels

| Level | Behavior |
|-------|----------|
| `strict` | Comprehensive review with full DoD checklist |
| `standard` | Balanced review (default) |
| `lenient` | Lighter review, focuses on critical issues |

## Evidence Bundle

Each review generates an evidence bundle containing:
- Diff summary
- Test results
- Definition-of-done checklist
- Review notes

The DoD gate is fail-closed: missing or incomplete checklist items block task completion.

## Workflow Settings

```yaml
workflow:
  require_review: true    # Enforce review gate (strongly recommended)
  auto_commit: true       # Auto-commit after coding step
  auto_push: true         # Auto-push after commit
  auto_merge: false       # Auto-merge on approval (use with caution)
```

## Diagnostics

When reviews keep rejecting:

```bash
# View error patterns and forensic analysis
genaisys autopilot diagnostics

# Check recent rejection reasons in the run log
grep '"review_reject"' .genaisys/RUN_LOG.jsonl | tail -5
```

Common rejection causes:
- Quality gate failures (fix tests/lint first)
- Diff budget exceeded (reduce scope)
- Missing files or wrong approach (regenerate spec)

---

## Related Documentation

- [Review System](../concepts/review-system.md) — How the review system works
- [Quality Gates](../concepts/quality-gates.md) — Pipeline details and adaptive diff
- [Task Lifecycle](../concepts/task-lifecycle.md) — Retry budgets and blocking
- [Troubleshooting](troubleshooting.md) — Common error resolution
- [Configuration Reference](../reference/configuration-reference.md) — All review and quality gate keys
