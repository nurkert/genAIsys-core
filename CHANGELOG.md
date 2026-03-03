# Changelog

All notable changes to Genaisys are documented here. This project follows [Semantic Versioning](https://semver.org/) for stable releases and uses phase-based versioning during the active development period.

---

## [Unreleased] — Phase 2 Active

### 2026-03-02 — Post-Phase-2i Cleanup

**Fixes**
- `HitlGateService`: `stepId` now persists to and restores from the gate file, ensuring crash-recovery and supervisor-status accuracy
- `JsonPresenter.writeAutopilotStatus`: `hitl_gate_pending` and `hitl_gate_event` fields now included in `genaisys status --json` output — enables CI and GUI tooling to observe gate state
- `RunLogTailer` extracted from `cli_runner.dart` to `lib/core/cli/shared/cli_run_log_tailer.dart` as a public class — reduces file size by 273 lines and improves testability
- Removed `@override` annotations from 7 git mixin files (`git_branch_ops.dart`, `git_commit_ops.dart`, `git_diff_ops.dart`, `git_history_ops.dart`, `git_remote_ops.dart`, `git_stash_ops.dart`, `git_shared_state.dart`) — fixes `override_on_non_overriding_member` analyzer warnings
- `done_service_test.dart:333`: resolved pre-existing test confusion — `task_done` is correctly emitted on the `alreadyDone` path for `activate_service` skip logic; added clarifying comment

**Test count**: 2653 passing

---

### 2026-03-01 — Phase 2i: Human-in-the-Loop Gates + Observability

**New features**
- `HitlGateService`: pause the autopilot at configurable checkpoints and wait for an explicit human decision
- Three gate checkpoints: `after_task_done`, `before_sprint`, `before_halt`
- Gate file protocol: `.genaisys/locks/hitl.gate` (context) + `.genaisys/locks/hitl.decision` (response)
- Run-log events: `hitl_gate_opened`, `hitl_gate_resolved`, `hitl_gate_timeout`
- CLI: `genaisys hitl status|approve|skip|reject [path] [--note X] [--json]`
- API: `getHitlGate()` → `HitlGateDto`, `submitHitlDecision()` on `GenaisysApi`
- GUI: `GuiHitlUseCase` (approve/reject/getGate)
- `HitlConfig` sub-config view (9th sub-config); 5 config keys under `hitl.*`
- HITL gate deduplication: identical consecutive gates suppressed in text presenter

**Observability**
- `RunLogTailer` (extracted from `_RunLogTailer`): real-time event streaming for `autopilot run --follow`
- `genaisys autopilot follow` command for attaching to a running autopilot without stopping it
- Rich / plain dual-mode formatting for all HITL events

**Test count**: 2648 passing (pre-cleanup)

---

### 2026-03-01 — Phase 2i Cleanup: HITL Observability & UX

**Improvements**
- Gate-opened deduplication: identical consecutive `hitl_gate_opened` text lines suppressed
- `writeAutopilotStatus` / `writeAutopilotSupervisorStatus` in `TextPresenter` now display HITL gate badge
- Follow status presenter (`cli_follow_status_presenter.dart`) shows `⏸ HITL` indicator when gate pending
- Run-log tailer formats `hitl_gate_opened` / `hitl_gate_resolved` as distinct rich/plain lines

---

### 2026-03-01 — Phase 2h: Sprint-Based Autonomous Planning

**New features**
- `SprintPlannerService`: generates a new task sprint from the project vision when the backlog is exhausted
- Config keys: `autopilot.sprint_planning_enabled`, `autopilot.sprint_size` (default 8), `autopilot.max_sprints` (default 0 = unlimited)
- Termination signals: `sprint_max_reached`, `sprint_vision_fulfilled`
- HITL gate integration: `gate_before_sprint` pauses before each sprint generation

---

### 2026-03-01 — Codebase Modularization (Phases 1–3)

**Refactoring**
- **Phase 1A**: `git_service.dart` split into 7 mixin files under `lib/core/git/impl/`
- **Phase 1B**: `orchestrator_run_state_handlers.dart` split into 7 phase extension files under `lib/core/services/orchestrator/phases/`
- **Phase 1C**: `autopilot_workspace_view.dart` split into 13 widget files under `lib/ui/desktop/widgets/shell/workspaces/autopilot/`
- **Phase 2**: `ProjectConfig` gains 8 typed sub-config views (`config.autopilot`, `config.git`, `config.hitl`, etc.)
- **Phase 3A**: Services reorganized into `autopilot/`, `agents/`, `task_management/`, `observability/` subdirectories
- **Phase 3B**: `CliPresenter` abstract interface extracted; `TextPresenter` and `JsonPresenter` now `implements CliPresenter`

---

### 2026-03-01 — Phase 2c: Orchestrated Init Pipeline

**New features**
- `InitInputService.autoDetect()`: normalizes PDF (via `pdftotext`), text files, stdin, and raw strings to a consistent input
- `InitOrchestratorService.run()`: 6-stage agent pipeline — Vision → Architecture → Backlog → Config → Rules → Verification
- Each stage: max 2 retries on REJECT before aborting
- CLI: `genaisys init [path] --from <source> [--static] [--overwrite]`
- `--static` opt-out retains single-call behavior
- `genaisys init --from` automatically sets `sprint_planning_enabled: true`

---

### 2026-02-26 — Project Rename: Hephaistos → Genaisys

**Breaking changes**
- Package renamed: `hephaistos` → `genaisys`
- CLI binary: `hephaistos_cli` → `genaisys_cli`
- Runtime directory: `.hephaistos/` → `.genaisys/`
- All internal references updated; existing `.hephaistos/` directories require manual migration

---

### 2026-02-26 — CLI Output System (Phase 2g)

**New features**
- `CliOutput` dual-mode output: `CliOutput.rich` (TTY, ANSI, Unicode) / `CliOutput.plain` (CI/headless, key=value)
- `CliOutput.auto()` factory: detects TTY via `stdout.hasTerminal`; respects `NO_COLOR` / `TERM=dumb`
- `genaisys autopilot follow` command: attaches to a running autopilot and streams formatted run-log events
- Follow status: `formatCliFollowStatus` with rich and plain variants
- `isImportantEvent()`: filters run-log to 8 high-signal event types for the tailer

---

### 2026-02-28 — Robustness Wave 4 (10 fixes)

**Fixes and improvements**
1. `alreadyDone` path: merge always executes; `task_done` event emitted for activation-skip logic; `markDone` / audit / subtask cleanup skipped to prevent double-execution
2. Stash + discard double-failure: emits `reject_cleanup_failed` run-log event; throws `StateError` with structured error context
3. `preflightRepairThreshold`, `maxPreflightRepairAttempts`, `lockHeartbeatHaltThreshold` promoted to config keys (§15 pattern)
4. `_trySelfHeal()` extracted in `orchestrator_run_error_handler` — eliminates 4× duplication
5. `_handlePolicyViolationError` now calls `_trySelfHeal()` — parity with other error handlers
6. Config hot-reload propagates all 12 autopilot parameters (was only 5)
7. Heartbeat writer injectable for tests (`heartbeatWriterForTest` hook)
8. Auto-format executed before quality gate — prevents pure format-drift reject loops (§13 mandatory test)
9. Docs-only diff: quality gate skips irrelevant checks (§13 mandatory test)
10. OOM/SOE catch-all re-throws VM-fatal errors instead of masking them

---

### 2026-02-27 — Robustness Wave 3 (10 fixes)

**Fixes and improvements**
1. Universal exception catch in `_handleStepExecution` → `unexpected_exception` recovery path
2. SHA reachability guard in `review_bundle_service.dart` before between-diff computation
3. Code-health exception: sets `ctx.stepHadProgress = false` — not counted as progress
4. Heartbeat failure counter: `lock_heartbeat_failure_warning` after 3+ consecutive failures
5. `lessons_learned.md` rotation with `pipelineLessonsLearnedMaxLines` config key (default 100)
6. `contractNotes` included in `NoDiff` run-log event for better diagnostics
7. `mergeInProgress` bool on `ActiveTaskState` — set before merge, cleared on success/failure
8. TOCTOU lock protection: `_thisProcessStartedAt` compared against lock `started_at` when PID matches
9. Config hot-reload: `maxFailures`, `maxTaskRetries`, `stepSleep`, `idleSleep` now propagated
10. Off-by-one fix: `approvals > budget` (was `>=`) — allows exactly N approvals

---

### 2026-02-21 — Orchestrator Run Service State Machine

**Architecture change**
- `OrchestratorRunService` refactored from ~1360-line monolithic while-loop to 7-phase explicit state machine
- Phases: `gateCheck → preflight → stepExecution → stepOutcome → errorRecovery → progressCheck → sleepAndLoop`
- `RunLoopPhase` enum + `RunLoopTransition` drive dispatch; `RunLoopContext` carries all mutable counters
- Unified error handler replaces 5 duplicated catch blocks (~400 lines eliminated)
- New test coverage: 63 tests (59 existing + 4 new handler-level tests)

---

### 2026-02-20 — Init and Fix Milestones

**Field test fixes (QuickNotes)**
- `_ensureGeminiYoloOverride`: resolved `-y` / `--approval-mode` CLI conflict
- `_selectTask`: fixed single-candidate loop in `activate_service.dart`
- `task_already_done` early return: now still executes merge + task_done event
- `_persistPostStepCleanup`: silent failure now emits diagnostic run-log event

---

## Phase 0–1 History

### Phase 1: Minimal UI & Self-Host Loop (Complete)

- Flutter Desktop UI as observer/controller (project list, Kanban board, review panel)
- Agent status display and toggle controls
- Self-host loop activated: Genaisys creating tasks for itself
- `window_manager` + `flutter_acrylic` desktop integration

### Phase 0: Self-Host Foundations (Complete)

- `.genaisys/` runtime directory as single source of truth
- Task state machine with backlog parsing
- Provider adapter v1 (Codex CLI)
- Mandatory review gate — no task completion without approval
- Git service with branch-per-task workflow
- Safety policies: Safe-Write, Shell Allowlist, Diff Budget

---

## Related Documentation

- [Roadmap](docs/project/roadmap.md) — Phased delivery plan and current status
- [Run Log Schema](docs/reference/run-log-schema.md) — Event catalog
- [CLI Reference](docs/reference/cli.md) — Complete command documentation
- [Configuration Reference](docs/reference/configuration-reference.md) — All config keys
