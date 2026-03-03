[Home](../README.md) > [Concepts](./README.md) > Review System

# Review System

Every code change in Genaisys must pass through an independent [review gate](../glossary.md#review-gate) before delivery. No task can be completed without explicit approval.

---

## Review Policy

The review system enforces a mandatory 4-eyes principle: the coding agent and the review agent are always different invocations, ensuring independent assessment.

### Fresh Context

When `review.fresh_context` is enabled (default: `true`), the review agent is instantiated without any carry-over from the coding agent. This prevents the reviewer from being biased by the coder's reasoning.

### Strictness Levels

| Level | Config Value | Behavior |
|-------|-------------|----------|
| Strict | `strict` | Comprehensive review with full DoD checklist |
| Standard | `standard` | Balanced review (default) |
| Lenient | `lenient` | Lighter review, focuses on critical issues only |

Config key: `review.strictness`

### Max Review Rounds

The maximum number of review attempts per task before blocking. Config key: `review.max_rounds` (default: 5).

## Evidence Bundle

Each review generates an evidence bundle containing:
- **Diff summary** — What changed and why
- **Test results** — Quality gate output
- **DoD checklist** — Definition-of-done items checked by the reviewer
- **Review notes** — Approval or rejection rationale

### Definition of Done (DoD)

The DoD gate is fail-closed: if the `definition_of_done` checklist in the evidence bundle is missing or incomplete, `done` is blocked. The reviewer must explicitly check off each DoD item.

## Review Decisions

| Decision | Effect |
|----------|--------|
| `approve` | Task proceeds to delivery (merge) |
| `reject` | Task returns to coding with feedback; retry counter incremented |

### Rejection Flow

1. Review agent returns `reject` with detailed notes
2. Rejection notes are recorded in the run log
3. Retry counter increments
4. If retry budget remains: coding agent receives rejection feedback as additional context
5. If retry budget exhausted: forensic analysis runs, task may be blocked

## Review Status

The current review status is tracked in STATE.json:
- `review_status`: `approved`, `rejected`, or `null`
- `review_updated_at`: ISO 8601 timestamp

### Manual Review Override

Operators can manually control the review status:

```bash
genaisys review approve --note "Manual approval after inspection"
genaisys review reject --note "Needs rework on error handling"
genaisys review clear
genaisys review status --json
```

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `review.fresh_context` | `true` | Instantiate reviewer without coding context |
| `review.strictness` | `standard` | Review thoroughness level |
| `review.max_rounds` | 5 | Max review attempts before blocking |
| `review.require_evidence` | `true` | Require evidence bundle for approval |
| `review.evidence_min_length` | 50 | Minimum evidence text length |
| `workflow.require_review` | `true` | Enforce review gate (disabling is not recommended) |

---

## Related Documentation

- [Quality Gates](quality-gates.md) — Verification before review
- [Task Lifecycle](task-lifecycle.md) — Retry budgets and blocking
- [Review & Quality Guide](../guide/review-and-quality.md) — How to use review features
- [CLI Reference](../reference/cli.md#review) — Review commands
