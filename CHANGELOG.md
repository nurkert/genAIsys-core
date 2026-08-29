# Changelog

All notable changes to Genaisys are documented here. This project follows [Semantic Versioning](https://semver.org/) for stable releases and uses phase-based versioning during the active development period.

---

## [Unreleased] — Phase 2 Active

### 2026-08-29 — Public CI Made Honest

Publishing the full product made the public repository's CI meaningful for the first time —
`flutter-ci.yml` had never actually run anywhere, because it was filtered out of the mirror.
The first public run was red.

**The GUI build and widget-test jobs added in this cycle passed**, confirming
`flutter build linux --release` and the CLI build script work on a clean runner. Three other
jobs failed:

- **CLI import boundary** — the guard required `ripgrep` and exited 2 when the runner did not
  ship it, so it had been failing on every public run. Rewritten on `git grep`, which is always
  present. It was also silently ineffective: a negative control showed its pathspec never
  matched, so a real violation would have passed. Both are fixed, and the guard is now verified
  against a deliberately planted violation.
- **Analyze (fatal infos)** — CI resolved `channel: stable` to Flutter 3.47.2 while the project
  is developed and verified on 3.44.8. With `--fatal-infos`, a new SDK's new lints turn CI red
  without any code change. Both workflows now pin `FLUTTER_VERSION`, and
  `docs/contributing/releasing.md` documents how to bump it as its own delivery.
- **Core coverage thresholds** — the job measured `lib/core/policy/` and the redaction service
  but did not run the tests that cover them, so the policy scope sat at 66.8% against its own
  75% floor and could never have passed. Adding the six existing test files that cover the
  measured scope takes it to 91.6%; the threshold is unchanged, because the gate was right and
  the file list was wrong. Orchestration was already at 85.3%.

All ten jobs across both workflows pass on the next public snapshot. The workflow logs are only
readable with admin rights, so the analyzer diagnosis was reasoned from the tree rather than read
from a log — the green run confirms it, since pinning the SDK was the only change affecting that
job's inputs.

---

### 2026-08-29 — Complete, Registry-Driven Settings

**The GUI could only reach 43 of 144 config keys.** `AppConfigDto` was a hand-maintained
subset, so every new config key needed manual plumbing through the DTO, the update path, and a
bespoke form field before the GUI could show it — and until someone did that work, the setting
was invisible and uncontrollable from the app.

Settings are now generated from `configFieldRegistry`, the same source of truth the parser and
schema validator already use. Registering a `ConfigFieldDescriptor` is now sufficient: the key
becomes readable, validatable, searchable, and editable in the GUI with no further work.

**Core**
- `ConfigRegistryService`: generic read/validate/write for every scalar config key, driven by
  the registry. Writes go through `YamlEditor`, so comments and formatting in `config.yml`
  survive an edit
- Writes are fail-closed and atomic — one invalid value rejects the whole batch and leaves the
  file untouched — with machine-readable `ConfigValueErrorKind` per rejection
- Reads degrade safely: an absent file, a missing key, or a stored value of the wrong type all
  fall back to the registered default rather than surfacing a corrupt value

**App boundary**
- `getConfigSchema`, `setConfigValues`, `resetConfigValues` on `GenaisysApi`, with
  `ConfigSchemaDto` / `ConfigFieldDto` describing each setting: label, description, control
  type, choices, range, default, and whether it differs from that default
- Control type is derived from the declared field type, so a new key renders correctly without
  anyone writing a widget for it
- Every settings write leaves run-log evidence (`config_updated`) naming the keys that moved;
  settings alter safety budgets and gate behaviour, so they are audit-relevant

**GUI**
- New settings surface covering all 144 keys: a group rail for one area at a time, and a search
  that spans every group so a setting can be found without knowing where it lives
- Changes apply immediately — no save step to forget. A rejected value rolls back to what is on
  disk and explains itself inline, so the UI never shows a value the engine did not accept
- Per-setting "changed from default" marker and one-click restore; a restore-all that touches
  only what is currently in view
- The previous hand-written form remains as *Paths & allowlist* for the list-valued settings
  (safe-write roots, shell allowlist) that the scalar registry cannot express yet
- A project with no `config.yml` says so and offers a retry, rather than presenting an editor
  backed by defaults it has nowhere to save. `getConfigSchema` distinguishes that case from a
  genuine failure
- All settings strings go through `DesktopStrings`, including a new pattern for parameterized
  labels (counts, the searched term) so substitutions stay with the sentence

**Documentation**
- All 144 keys now carry a `description`, taken from `configuration-reference.md` where it
  already existed (123 keys) and newly written from the consuming code for the rest (21)
- The reference documented itself as exhaustive but was missing 18 keys; they are now listed
- `config_field_documentation_test.dart` keeps registry, descriptions, and the reference in sync

**Found while doing this**
- `autopilot.vision_drift_check_enabled` and `autopilot.vision_drift_check_interval` are
  configurable but no pipeline stage reads them — setting them currently does nothing. Their
  descriptions say so rather than implying behaviour that does not exist.

---

### 2026-08-29 — Full-Product Public Release

**Public mirror is no longer core-only.** The GUI, desktop shell, platform directories,
UI documentation, and branding now ship in the public GitHub snapshot. The mirror performs
no source rewriting: the public tree is the same Flutter project, built and tested with the
same commands.

**Distribution**
- New `.github/workflows/release.yml` builds the desktop GUI **and** the CLI for Linux, macOS,
  and Windows on every `v*` tag, and publishes them as a GitHub Release with `SHA256SUMS`
- Linux `.deb` installs the GUI to `/opt/genaisys`, puts `genaisys` (CLI) and `genaisys-gui`
  on `PATH`, and registers a desktop entry with hicolor icons
- Release job verifies the tag matches `pubspec.yaml` before building
- Replaces `build-deb.yml`, which packaged only the CLI
- Removed `dart-ci.yml`; the public repo is a full Flutter project and uses `flutter-ci.yml`
- `.github/scripts/build_cli.sh` compiles the CLI against a Flutter-free `tool/pubspec.cli.yaml`;
  `dart compile exe` cannot build against the root pubspec because Flutter pulls `objective_c`,
  which uses unsupported build hooks
- New `version_consistency_test.dart`: `CliBranding.version` is hard-coded and previously had no
  guard tying it to `pubspec.yaml`, so a release could have shipped a binary reporting the wrong
  version

**Build fix — the desktop GUI did not compile at all**
- `phosphor_flutter` (last published 2024) extends Flutter's `IconData`, which is now a `final`
  class. Every GUI build and every widget test failed to compile against current stable Flutter;
  `dart analyze` did not catch it because the analyzer does not analyze dependency sources.
- Replaced with the maintained successor `phosphor_icons` ^3.0.1 — same icon family, same
  `PhosphorIconsRegular` / `PhosphorIconsBold` class names, so the swap is import-only and the
  visual identity is unchanged

- macOS project migrated to Swift Package Manager for the plugins that support it
  (`file_selector_macos`, `window_manager`); `desktop_multi_window` and `screen_retriever_macos`
  remain on CocoaPods until upstream adopts SPM

**CI coverage gap that allowed the above**
- `flutter-ci.yml` ran a hand-picked list of core test files and never compiled the GUI, so a
  dependency that stopped building was invisible. Added a `gui-build` job (desktop GUI + CLI
  binary) and a `widget-tests` job covering `test/ui/` and `test/widget_test.dart`.

**Branding**
- New anvil mark in `assets/branding/` (SVG + PNG sizes), drawn from the existing metal palette
- Replaces the default Flutter icon on macOS, Windows, and web; Linux window sets `icon-name`

**Test count**: 2327 passing (the previously documented 2653 could not have been current — three
UI test files failed to compile and were never counted).

**GUI**
- Settings sidebar now shows the running build version. The GUI previously displayed the version
  nowhere, so a user filing a bug report had no way to say which build they were on. The value is
  selectable so it can be copied straight into a report.
- Version and product identity moved to `lib/core/product_info.dart`; `CliBranding` delegates to
  it, so the GUI reads the same source without importing from `lib/core/cli/` (a layer violation)

**Naming**
- Completed the Hephaistos → Genaisys rename: Linux/Windows/macOS/web/iOS/Android identifiers,
  window titles, and the Android package directory
- Root `TASKS.md` / `VISION.md` / `RULES.md` pointed at a non-existent `.hephaistos/` directory;
  they now point at `.genaisys/`
- `pubspec.yaml` description was still the `flutter create` placeholder

**Fixes**
- `pubspec.yaml` declared an `assets/` directory that no longer existed, breaking `flutter build`
- Zero analyzer issues under `--fatal-infos --fatal-warnings` (77 → 0): `dart fix` for 73
  mechanical issues, plus `SizeTransition.axisAlignment` → `alignment`, a spec-agent test fake
  that never recorded its calls, and two dead test fields
- Removed unreferenced `lib/ui/desktop/data/mock_workspace_data.dart`
- Re-established the documented `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` hard link, which had drifted
  into three separate files

**Public-surface hygiene**
- `.genaisys/ARCHITECTURE.md` contained an agent's chat reply instead of an architecture document,
  including an absolute path from the author's machine. It is fed into strategic planning and
  vision evaluation prompts, so the placeholder text was degrading every planning cycle. Replaced
  with a real document in the six required sections.
- Untracked `.claude/settings.local.json`, which held local machine paths despite `.claude/`
  being gitignored
- New `local-paths` repo-hygiene job fails CI on absolute developer home paths in tracked files
- Mirror job now fails closed if any public markdown still links to a stripped internal document
- `check_cli_import_boundary.sh` flagged `lib/core/legacy/` — a violation previously hidden because
  the mirror stripped that directory. The Dart architecture test already exempts `lib/core/legacy/`
  by design (documented back-compat GUI-over-CLI bridge); the shell guard now matches it

---

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

- [Run Log Schema](docs/reference/run-log-schema.md) — Event catalog
- [CLI Reference](docs/reference/cli.md) — Complete command documentation
- [Configuration Reference](docs/reference/configuration-reference.md) — All config keys
