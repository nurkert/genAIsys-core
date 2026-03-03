# Rules

- Internal artifacts are always English.
- Review gate is mandatory for every task.
- No task is done without review approval.
- Safe-write and allowlist policies must be enforced in autopilot.
- Work only in small, single-scope increments.
- Prefer maintainable, readable, and testable code over speed hacks.
- Do not mix unrelated features in one change set.
- Every behavior change must include focused test coverage.
- Refactors must preserve behavior and include regression checks.
- Keep core logic UI-agnostic and preserve clear module boundaries.
- Current execution focus is stabilization/refactoring in Core and CLI; non-critical GUI feature work is deferred until stabilization exit criteria are met.
- During stabilization, only critical GUI tasks are allowed (operational visibility, incident diagnosis, or parity blockers for existing CLI workflows).
- When evolving Genaisys, user-facing capabilities must be implemented CLI-first and cannot be considered complete without a GUI control path; if GUI implementation is deferred, an explicit backlog task must exist and be linked.
- Interaction-facing tasks must be metadata-driven and fail-closed:
  use `[INTERACTION]` plus either `[GUI_PARITY:DONE]` (same-task GUI parity implemented)
  or `[GUI_PARITY:<linked-ui-task-id>]` (deferred GUI parity task, open `[UI]` task).
- Fail closed on security and preflight decisions; never continue on uncertain policy state.
- New reliability and failure handling must emit machine-readable `error_class` and `error_kind`.
- Treat all output surfaces as sensitive and route logs/artifacts/CLI output through centralized sanitization.
- Track completion immediately: once implementation + tests + analyze are green, mark the exact `TASKS.md` item done in the same delivery step.
- Merge is allowed only after analyzer and relevant tests are green.
- Keep security fixes, refactors, and CI hardening as separate scoped deliveries.
- Strict Definition of Done per subtask must hold before completion:
  1) implementation complete,
  2) relevant unit/integration/E2E tests added or updated,
  3) `dart analyze` green for affected paths,
  4) relevant test suites green,
  5) run-log/status behavior reviewed when impacted,
  6) docs updated when API/behavior changed,
  7) only then mark the related `TASKS.md` item done in the same delivery slice.
- Follow critical-path order during stabilization to avoid silent regressions:
  1) secret/token redaction, 2) normalized failure reasons, 3) review/git hard gates,
  4) deterministic scheduler + decision logging, 5) adversarial security tests,
  6) crash/lock/concurrency regressions, 7) large service refactors with parity protection,
  8) CI hardening (analyzer zero-issues + coverage thresholds).
- Do not start large refactors before failure contracts, security hardening, and regression suites are in place.
