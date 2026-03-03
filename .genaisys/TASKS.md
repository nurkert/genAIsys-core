# Tasks

## Backlog
Restructured (2026-02-15): Complete backlog overhaul for incremental bootstrap.
Strategy: Fix blocking conditions first, prove the loop works, then incrementally add capabilities.
All non-MVP tasks moved to Deferred section at bottom with [BLOCKED] status.
Autopilot must work on the simplest possible task before adding any complexity.
Each task is atomic, precisely scoped, and describes exactly what to change and where.

### Phase 0: Unblock Autopilot (Emergency — Do First)
Goal: Remove every condition that prevents `autopilot run` from executing a single step.
These tasks must be done MANUALLY (by a human or agent) because autopilot cannot run until they're complete.

- [x] [P1] [CORE] Reset STATE.json active task fields — set `active_task_id` to null, `active_task_title` to null, `workflow_stage` to "idle", `cycle_count` to 0 in `.genaisys/STATE.json` so autopilot starts with a clean slate instead of a stale task reference
- [x] [P1] [CORE] Clear STATE.json subtask queue — set `subtask_queue` to empty array `[]` and `current_subtask` to null in `.genaisys/STATE.json` to remove orphaned subtask entries from a previous task that no longer matches the active task
- [x] [P1] [CORE] Reset STATE.json forensic and reflection state — set `forensic_recovery_attempted` to false, `forensic_guidance` to null, `reflection_count` to 0, `last_reflection_at` to null, `reflection_tasks_created` to 0 in `.genaisys/STATE.json` so no stale recovery/reflection state interferes with fresh operation
- [x] [P1] [QA] Fix broken import in `right_sidebar_panels.dart` line 6 — change `../../../../../core/app/app.dart` to `../../../../core/app/app.dart` (4 levels up, not 5) because the current path resolves to `core/app/app.dart` outside of `lib/`, causing 3 analyzer errors (`uri_does_not_exist`, `non_type_as_type_argument` for `AutopilotStatusDto`, `undefined_class` for `AutopilotStatusDto`)
- [x] [P1] [QA] Verify zero analyzer errors — run `dart analyze` on the project root and confirm zero errors, zero warnings; the quality gate requires this and will fail-closed on any analyzer issue
- [x] [P1] [QA] Verify all 1233 tests still pass — run `flutter test` and confirm all tests pass; this validates that no state/import fix broke anything
- [x] [P1] [CORE] Run `autopilot status` and verify preflight passes — stabilization exit gate returns `ok: true` with 84 open P1 tasks and 0 post-stabilization unblocked tasks; preflight and stabilization gate tests all pass (18/18)
- [x] [P1] [CORE] If stabilization gate still blocks: identify and fix the exact blocking condition — RESOLVED: gate passes because all deferred sections use [BLOCKED] tags and no stray open tasks exist in post-stabilization sections

### Phase 1: First Green Loop (Minimal Viable Cycle)
Goal: ONE successful autopilot cycle — activate a task, call the agent, run quality gate, review, commit, mark done.
No complexity. No intelligence features. Just prove the pipe works end-to-end.

- [x] [P1] [QA] Add trivial test task: "Add doc comment to `StabilizationExitGateService.evaluate`" — already present as next task in this Phase; the task is simple enough for any coding agent to complete in one pass
- [x] [P1] [CORE] Add doc comment to `StabilizationExitGateService.evaluate` method — add a `///` documentation comment to the `evaluate(String tasksPath)` method in `lib/core/services/stabilization_exit_gate_service.dart` explaining that it reads TASKS.md, counts open P1 tasks and open post-stabilization unblocked tasks, and returns a result indicating whether the stabilization exit gate passes
- [x] [P1] [QA] Manually trigger one autopilot step and observe output — first attempt failed with `File name too long` because TaskSlugger.slug() had no length limit, producing 400+ char branch names
- [x] [P1] [CORE] Fix the first failure point discovered in the manual autopilot step — added `maxSlugLength=60` to `TaskSlugger.slug()` in `lib/core/ids/task_slugger.dart`, truncating slugs at 60 chars with clean trailing-dash removal; added 3 tests
- [x] [P1] [QA] Re-run autopilot step after first fix and observe output — second run succeeded: `autopilot_step_completed=true`, `review_decision=approve`, `deactivated_task=true`; Codex added a correct 3-line `///` doc comment, quality gate passed, committed to main
- [x] [P1] [CORE] Fix the second failure point discovered in the autopilot re-run — NOT NEEDED: first green cycle achieved on second attempt
- [x] [P1] [QA] Confirm first green cycle — verified: commit `facedee` on main contains the doc comment addition, TASKS.md task marked `[x]`, STATE.json shows `workflow_stage=done`, `review_status=approved`

### Phase 2: Config Wiring — Review & Cycle Settings
Goal: Wire parsed-but-unused config fields into the services that should consume them. Each task is one config field + one service.
Test tier: Unit tests per wiring (contract: config value → service behavior).

- [x] [P1] [CORE] Wire `reviewFreshContext` into ReviewAgentService — already wired: `review_agent_service.dart` line 70 reads `config.reviewFreshContext` to decide whether to include prior coding agent context; tested with 3 cases in `review_agent_service_test.dart`
- [x] [P1] [QA] Add test for `reviewFreshContext` wiring — already tested: 3 unit tests in `test/core/services/review_agent_service_test.dart` covering fresh_context=true (omits prior context), fresh_context=false (includes prior context), and fresh_context=false with no prior context (graceful omission)
- [x] [P1] [CORE] Wire `reviewMaxRounds` into TaskCycleService — wired `config.reviewMaxRounds` into both call paths: `OrchestratorStepService.run()` (lines 184-199) and `InProcessGenaisysApi.runTaskCycle()` (newly added); both normalize the value (min 1) and pass it as `maxReviewRetries` to `TaskCycleService.run()`, overriding the constructor default
- [x] [P1] [QA] Add test for `reviewMaxRounds` wiring — added test in `test/core/config_wiring_regression_test.dart` that sets `reviewMaxRounds=1` in config, runs a cycle with a reject, and verifies the task blocks after 1 reject (not 3); validates the config→run() override path works correctly

### Phase 2b: Config Wiring — Supervisor Settings
Goal: Wire supervisor config fields so the supervisor service uses configurable values instead of hardcoded ones.
Test tier: Unit tests per wiring (contract: config value → service behavior).

- [x] [P1] [CORE] Wire `supervisorMaxInterventionsPerHour` into AutopilotSupervisorService — in `lib/core/services/autopilot_supervisor_service.dart`, read `config.supervisorMaxInterventionsPerHour` (already parsed, default 5) and use it to rate-limit supervisor interventions; currently the field is parsed in `project_config_parser.dart` line 657 but never consumed
- [x] [P1] [QA] Add test for `supervisorMaxInterventionsPerHour` wiring — add a unit test that verifies the supervisor stops intervening after N interventions per hour where N comes from config
- [x] [P1] [CORE] Wire `supervisorCheckInterval` into AutopilotSupervisorService — in `lib/core/services/autopilot_supervisor_service.dart`, read `config.supervisorCheckIntervalSeconds` (already parsed, default 30) and use it as the Duration between health check iterations instead of any hardcoded value
- [x] [P1] [QA] Add test for `supervisorCheckInterval` wiring — add a unit test that verifies the supervisor uses the config-specified check interval duration

### Phase 2c: Config Wiring — Reflection Settings
Goal: Wire reflection config fields so the reflection/insight services use configurable values.
Test tier: Unit tests per wiring (contract: config value → service behavior).

- [x] [P1] [CORE] Wire `reflectionMinSamples` into ProductivityReflectionService — in `lib/core/services/productivity_reflection_service.dart`, accept `reflectionMinSamples` from config (already parsed, default 5 in `project_config_parser.dart` line 633) and skip reflection analysis when the available sample count is below this threshold to avoid noisy/misleading results
- [x] [P1] [QA] Add test for `reflectionMinSamples` wiring — add a unit test that verifies ProductivityReflectionService skips reflection when sample count is below the configured minimum
- [x] [P1] [CORE] Wire `reflectionAnalysisWindowLines` into RunLogInsightService — in `lib/core/services/run_log_insight_service.dart`, replace the hardcoded `defaultMaxLines = 2000` (line 83) with the value from `config.reflectionAnalysisWindowLines` (already parsed in `project_config_parser.dart` line 648); the `analyze()` method at line 89 should use this config value as its default
- [x] [P1] [QA] Add test for `reflectionAnalysisWindowLines` wiring — add a unit test that verifies RunLogInsightService reads the configured window size lines from config instead of hardcoded 2000

### Phase 2d: Config Wiring — Pipeline Intelligence Settings
Goal: Add missing config keys for operative intelligence features so they can be disabled/tuned without code changes.
Test tier: Unit tests for config parsing + feature gating (contract: config boolean → feature on/off).

- [x] [P1] [CORE] Add `pipeline.forensic_recovery_enabled` config key — add a boolean field `forensicRecoveryEnabled` to `ProjectConfig` (default: true), parse it from `pipeline.forensic_recovery_enabled` in `project_config_parser.dart`, add it to `ConfigUpdate`, and include it in the default config template in `default_files.dart`
- [x] [P1] [CORE] Gate forensic recovery on `forensicRecoveryEnabled` config — in the service that invokes forensic recovery (TaskForensicsService or TaskCycleService), check `config.forensicRecoveryEnabled` before attempting forensic analysis; when false, skip forensic recovery entirely and proceed with normal blocking
- [x] [P1] [CORE] Add `pipeline.error_pattern_learning_enabled` config key — add a boolean field `errorPatternLearningEnabled` to `ProjectConfig` (default: true), parse it from `pipeline.error_pattern_learning_enabled` in `project_config_parser.dart`, add it to `ConfigUpdate`, and include it in the default config template
- [x] [P1] [CORE] Gate error pattern learning on `errorPatternLearningEnabled` config — in `ErrorPatternRegistryService`, check `config.errorPatternLearningEnabled` before recording new patterns; when false, the registry still serves existing patterns but does not learn new ones
- [x] [P1] [CORE] Add `pipeline.impact_context_max_files` config key — add an integer field `impactContextMaxFiles` to `ProjectConfig` (default: 10), parse it from `pipeline.impact_context_max_files` in `project_config_parser.dart`, add it to `ConfigUpdate`, and include it in the default config template
- [x] [P1] [CORE] Wire `impactContextMaxFiles` into ArchitectureContextService — in `lib/core/services/architecture_context_service.dart`, use `config.impactContextMaxFiles` to limit the number of impacted files injected into coding agent prompts instead of any hardcoded limit
- [x] [P1] [QA] Add tests for all three new pipeline config keys — add unit tests verifying: (a) forensic recovery is skipped when disabled, (b) error pattern learning stops recording when disabled, (c) impact context respects the max files limit from config

### Phase 2e: Forensic State Hygiene
Goal: Ensure forensic/recovery state doesn't leak across tasks.
Test tier: Unit test for state lifecycle (contract: stale state never leaks to next task).

- [x] [P1] [CORE] Clear forensic state on task activation — in `lib/core/services/activate_service.dart` (around line 63-69 where the task gets activated), reset `forensicRecoveryAttempted` to false and `forensicGuidance` to null in the state update; currently these fields are only cleared in `_clearActiveTask()` (task_cycle_service.dart line 284) which runs on task completion, but if a task is abandoned and a new one activated, stale forensic state could leak
- [x] [P1] [QA] Add test for forensic state clearing on activation — add a unit test that activates a new task when `forensicRecoveryAttempted` is true and `forensicGuidance` has a value, then verifies both are cleared after activation

### Phase 2f: Config Wiring Regression Gate
Goal: Prove all Phase 2 wiring works together and the autopilot handles multi-task runs.
Test tier: Integration test combining all config wiring + live autopilot validation.

- [x] [P1] [QA] Add config wiring regression test — create `test/core/config_wiring_regression_test.dart` that loads a config with ALL non-default values (reviewFreshContext=false, reviewMaxRounds=1, supervisorMaxInterventionsPerHour=2, supervisorCheckIntervalSeconds=10, reflectionMinSamples=10, reflectionAnalysisWindowLines=500, forensicRecoveryEnabled=false, errorPatternLearningEnabled=false, impactContextMaxFiles=3) and verifies each service reads the correct value; this single test catches any regression where a config field silently stops being wired
- [x] [P1] [QA] Run autopilot for 3 consecutive tasks — ran on `/tmp/genaisys_test_project` (word_counter CLI). All 3 tasks completed full pipeline (activate→plan→spec→subtasks→code→quality_gate→review→approve→commit→task_done). Bugs found and fixed: (1) `shell_allowlist_profile: "standard"` silently ignores custom entries → must use `"custom"`. (2) `claude -p` needs `--dangerously-skip-permissions` for file edits. (3) Review parser rejected positive reviews missing literal "APPROVE" keyword → fixed in `933ba4f`. (4) Delivery preflight failed without git remote even when `auto_push: false` → fixed in `6527d7e` by adding `workflowAutoPush`/`workflowAutoMerge` config fields and gating remote checks. (5) `.dart_tool` in git caused safe_write violations → `.gitignore` required. (6) Merge flow fails when `.genaisys/` runtime artifacts (RUN_LOG, STATE.json, locks) are dirty — need to exclude `.genaisys/` from git or auto-stash before checkout. Final result: 15/15 tests passing, 3 functions + 12 tests generated autonomously.
- [x] [P1] [QA] Run autopilot overnight profile for 5+ tasks — run the supervisor with `overnight` profile for a sustained period; verify that at least 5 tasks complete, no deadlocks occur, no state corruption, and the run log shows clean progression

### Phase 3: Core Service Unit Tests — Orchestration Safety Net
Goal: Every core orchestration service has dedicated test coverage. This creates the safety net that makes all future phases safe — if any refactor or feature addition breaks orchestration, these tests catch it immediately.
Test tier: Comprehensive unit tests per service. Each test file becomes a permanent regression guard.
Strategy: Use existing manual-fake patterns (no mockito). Each test file is self-contained with inline fakes.

**Test infrastructure first:**
- [x] [P1] [QA] Create shared test builders — create `test/support/builders.dart` with `TaskBuilder`, `RunLogEntryBuilder`, `ProjectStateBuilder`, `ProjectConfigBuilder` classes that provide fluent builder APIs for constructing test domain objects; each builder must have sensible defaults so tests only specify the fields they care about; migrate at least 3 existing tests to validate the builder API works
- [x] [P1] [QA] Create shared fake services — create `test/support/fake_services.dart` with reusable fakes for `FakeGitService`, `FakeStateStore`, `FakeTaskStore` that multiple test files can share instead of each defining their own; these fakes must be configurable (e.g., `FakeGitService({bool isDirty = false, bool isRepo = true})`) so tests can set preconditions declaratively

**Then service-by-service coverage (9 services):**
- [x] [P1] [QA] Add unit tests for ActivateService — create `test/core/services/activate_service_test.dart` covering: (1) successful task activation from idle state, (2) activation when another task is already active (should fail with meaningful error), (3) activation of BLOCKED task (should fail), (4) activation of completed task (should fail), (5) state transitions on activation (workflow_stage idle→planning, active_task_id set, cycle_count reset), (6) forensic state clearing on activation (forensicRecoveryAttempted→false, forensicGuidance→null), (7) git branch creation (feat/<slug>), (8) error paths (missing TASKS.md, corrupt STATE.json, task not found)
- [x] [P1] [QA] Add unit tests for DoneService — create or extend `test/core/services/done_service_test.dart` covering: (1) successful task completion with valid review evidence, (2) completion blocked when review evidence bundle is missing, (3) completion blocked when review evidence is malformed, (4) completion blocked when review_status is "rejected", (5) git delivery integration (branch merge to base, push, cleanup), (6) TASKS.md checkbox update on completion, (7) state transitions on completion (workflow_stage→done, active_task_id→null), (8) blocked-task completion attempt (should fail)
- [x] [P1] [QA] Add unit tests for TaskCycleService — create or extend `test/core/services/task_cycle_service_test.dart` covering: (1) full cycle coordination (spec→code→quality-gate→review→deliver), (2) stage transition ordering (planning→coding→testing→reviewing→delivering→done), (3) review retry logic with configurable maxReviewRetries (test with 1, 2, 3), (4) automatic task blocking after max retries exhausted, (5) forensic recovery trigger on repeated failures, (6) error recovery from agent invocation failure (timeout, crash, invalid output), (7) quality gate failure handling (format drift, analyzer error, test failure), (8) no-diff detection and counting
- [x] [P1] [QA] Add unit tests for WorkflowService — create `test/core/services/workflow_service_test.dart` covering: (1) all valid state transitions (idle→planning→coding→testing→reviewing→delivering→done), (2) invalid transition attempts (idle→delivering should fail, coding→idle should fail), (3) self-transition (coding→coding should be no-op or fail), (4) transition from done (done→idle for next task), (5) edge case: transition when STATE.json is corrupt
- [x] [P1] [QA] Add unit tests for InitService — create `test/core/services/init_service_test.dart` covering: (1) successful `.genaisys/` directory creation with all required files (config.yml, TASKS.md, VISION.md, RULES.md, STATE.json), (2) idempotent re-init (running init on already-initialized project should not overwrite existing files), (3) config generation with sensible defaults, (4) error paths (read-only parent directory), (5) generated files are valid (config.yml parses, STATE.json has valid checksum)
- [x] [P1] [QA] Add unit tests for StatusService — create `test/core/services/status_service_test.dart` covering: (1) status reporting with active task (shows task title, stage, cycle count), (2) status with no active task (shows idle), (3) health aggregation (agent availability, git state, policy health), (4) edge states: supervisor running but autopilot idle, review rejected, task blocked, consecutive failures > 0
- [x] [P1] [QA] Add unit tests for SpecService — create `test/core/services/spec_service_test.dart` covering: (1) spec file creation from task with subtasks, (2) spec file creation from task without subtasks, (3) spec file reading, (4) spec file path derivation from task ID, (5) error handling (missing spec directory, malformed spec file), (6) spec content includes required sections (scope, acceptance criteria, files list)
- [x] [P1] [QA] Add unit tests for ReviewService — create or extend `test/core/services/review_service_test.dart` covering: (1) review approve flow (sets review_status=approved, stores evidence), (2) review reject flow (sets review_status=rejected, stores rejection reason), (3) review evidence validation (bundle must contain diff, test results, lint results), (4) unattended mode auto-review behavior, (5) review status clearing, (6) edge cases: review without active task (should fail), review when already approved (should warn/no-op)
- [x] [P1] [QA] Add unit tests for ConfigService — create or extend `test/core/services/config_service_test.dart` covering: (1) config loading from valid YAML with all fields, (2) config loading with missing optional fields (defaults applied correctly), (3) config update with valid values (ConfigUpdate → persisted), (4) config update with invalid values (type mismatch → error), (5) malformed YAML handling (syntax errors → structured error), (6) config round-trip (load → update → load → values preserved)

**Phase 3 regression gate:**
- [x] [P1] [QA] Add orchestration contract test — create `test/core/orchestration_contract_test.dart` that wires together ActivateService + TaskCycleService + DoneService with fake dependencies and runs a complete task lifecycle (activate→cycle→done) in-process, verifying: state transitions are correct, no state leaks between tasks, and all invariants from CLAUDE.md section 8 (clean-end, reject-archival, deterministic halt) hold. This is the single most important regression test — if this passes, the orchestration pipeline is intact.

### Phase 4: CLI Diagnostics & Onboarding Commands
Goal: A new user can install, init, and get clear diagnostic feedback.
Test tier: CLI JSON contract tests per handler (contract: handler → structured JSON output).
Strategy: Follow existing `cli_*_json_output_test.dart` pattern with `CliJsonOutputHelper`.

- [x] [P1] [CORE] Implement `config validate` CLI handler — add `ConfigValidateHandler` in `lib/core/cli/handlers/` that loads `config.yml`, validates schema, checks policy file paths exist, verifies quality gate commands are resolvable on PATH, checks for deprecated keys, and outputs structured JSON with pass/fail per check and remediation hints
- [x] [P1] [QA] Add test for `config validate` handler — test with valid config (all pass), config with missing quality gate command (fail + hint), config with deprecated key (warning + migration hint); validate JSON output schema matches other CLI handlers
- [x] [P1] [CORE] Implement `health` CLI handler — add `HealthHandler` in `lib/core/cli/handlers/` that runs all preflight checks (project structure, schema, git, review, stabilization gate, provider credentials, agent availability, disk space) and outputs a structured health report with pass/fail per check
- [x] [P1] [QA] Add test for `health` handler — test with healthy project (all pass) and project with missing provider credentials (fail + hint); verify JSON output includes all check names and statuses
- [x] [P1] [CORE] Implement `autopilot dry-run` CLI handler — add a `--dry-run` flag to the autopilot run handler that executes preflight + task selection + spec generation WITHOUT invoking the coding agent or mutating project files; outputs what would happen in JSON
- [x] [P1] [QA] Add test for `autopilot dry-run` handler — test that dry-run selects a task, generates spec, but does NOT create files, invoke agents, or modify STATE.json; verify STATE.json is byte-identical before and after
- [x] [P1] [CORE] Implement `autopilot diagnostics` CLI handler — add `DiagnosticsHandler` that dumps: current error pattern registry top-10 patterns, architecture health summary, forensic state for active task, last 5 run log events, and supervisor status
- [x] [P1] [QA] Add test for `autopilot diagnostics` handler — test with empty project (no patterns, no forensics) and with populated state; verify JSON structure
- [x] [P1] [CORE] Implement `config diff` CLI handler — add `ConfigDiffHandler` that loads current config and default config, compares field-by-field, and outputs only the non-default values with their effects (e.g., "diff_budget.max_files: 20 (default: 15) — limits max files changed per task to 20")
- [x] [P1] [QA] Add test for `config diff` handler — test with default config (no diff output) and with custom config (shows exactly the changed fields)
- [x] [P1] [CORE] Add shared `CliStructuredError` utility — create a utility class in `lib/core/cli/` that all handlers use to emit structured JSON errors with fields: `error_code`, `error_class`, `error_kind`, `message`, `remediation_hint`; replace any raw `stderr.writeln` error output in handlers with this structured format
- [x] [P1] [QA] Add test for `CliStructuredError` — test that error output is valid JSON with all required fields; test that all new handlers use the shared utility (no raw stderr)

**Phase 4 regression gate:**
- [x] [P1] [QA] Add CLI handler round-trip test — create `test/core/cli_handler_roundtrip_test.dart` that runs every CLI handler (status, tasks, health, validate, diff, diagnostics, dry-run) on the same temp project and verifies: all produce valid JSON, all return exit code 0 on healthy project, no handler crashes, and the JSON schemas are stable (golden-file comparison). This catches any CLI regression in one test.

### Phase 4b: Documentation
Goal: Users can find answers without reading source code.

- [x] [P1] [DOCS] Write CLI reference document — create `docs/cli_reference.md` listing every CLI command with: syntax, flags, description, example output, and exit codes; generate from handler metadata where possible
- [x] [P1] [DOCS] Add operative intelligence section to playbook — add section to `docs/unattended_operations_playbook.md` documenting: forensic recovery behavior (what triggers it, what recovery actions exist), error pattern learning (how patterns are recorded, how they influence future runs), architecture gate (what violations block, what warnings are injected)
- [x] [P1] [DOCS] Write quickstart guide for external projects — create `docs/quickstart.md` with step-by-step: (1) install Genaisys, (2) run `genaisys init` in your project, (3) configure provider credentials, (4) add tasks to TASKS.md, (5) run first cycle, (6) review output, (7) deliver; include example terminal output for each step

### Phase 5: End-to-End Automated Proof
Goal: Prove the full lifecycle works in automated tests with stub agents. Each test is one scenario.
Test tier: E2E tests with real filesystem, real git, stub agents. These are the ultimate regression guards — if these pass, the autopilot works end-to-end regardless of internal refactors.
Strategy: Each E2E test creates a real temp project with git init, .genaisys/, TASKS.md, config.yml, registers a stub `AgentRunner` that produces deterministic output, runs the autopilot programmatically, and asserts the full outcome.

**E2E test infrastructure:**
- [x] [P1] [QA] Create E2E test harness — create `test/e2e/support/e2e_harness.dart` with a `E2EHarness` class that: (1) creates a temp directory with `git init`, (2) creates `.genaisys/` with config.yml + TASKS.md + STATE.json, (3) registers a configurable stub `AgentRunner`, (4) provides `runAutopilotStep()` and `runAutopilotLoop(maxSteps)` methods, (5) exposes `readState()`, `readTasks()`, `readRunLog()` for assertions, (6) auto-cleans temp dir on teardown. This harness eliminates boilerplate so each E2E test is just setup + run + assert.
- [x] [P1] [QA] Create stub agent library — create `test/e2e/support/stub_agents.dart` with configurable stub agents: `SuccessAgent` (always produces valid diff), `FailAgent` (always crashes), `FlakeAgent` (fails N times then succeeds), `NoOpAgent` (produces empty diff), `SlowAgent` (sleeps N seconds then succeeds). Each stub must produce output matching the real agent response format.

**E2E scenarios (8 scenarios):**
- [x] [P1] [QA] E2E: happy-path single cycle — set up temp project with one open task, register `SuccessAgent`, run one autopilot step, verify: task activated → code written → quality gate passed → review approved → task marked `[x]` in TASKS.md → STATE.json shows workflow_stage=done → commit exists on feature branch → branch merged to main
- [x] [P1] [QA] E2E: review reject and retry — set up temp project, register `FlakeAgent(failCount: 1)` (bad code first, good code second), run autopilot, verify: first cycle → review rejects → dirty state stashed/archived → retry cycle → review approves → task delivered. Assert retry_count=1 in state.
- [x] [P1] [QA] E2E: multi-task sequential execution — set up 3 tasks (A, B, C all independent), run `autopilotLoop(maxSteps: 6)`, verify: all 3 tasks marked done in TASKS.md, 3 commits on main, STATE.json clean after each, correct task ordering (P1 before P2, within same priority: FIFO by line index)
- [x] [P1] [QA] E2E: safety halt on repeated failures — set up temp project, register `FailAgent`, configure `max_failures: 2`, run autopilot loop, verify: 2 failures → safety halt → autopilot stops → STATE.json has `consecutive_failures=2` and meaningful `last_error`/`last_error_class`/`last_error_kind`
- [x] [P1] [QA] E2E: no-diff detection and task blocking — set up temp project, register `NoOpAgent` (produces no file changes), run autopilot step, verify: no-diff detected → progress failure counted → task cooldown applied → STATE.json reflects the no-diff outcome
- [x] [P1] [QA] E2E: quality gate failure handling — set up a real Dart project in temp dir, register agent that introduces a syntax error, run autopilot, verify: quality gate fails (dart analyze finds error) → review does not happen → failure counted → agent gets forensic guidance on retry
- [x] [P1] [QA] E2E: provider failover — configure primary provider to return error/timeout, register fallback agent that succeeds, run one cycle, verify: primary fails → fallback invoked → cycle completes. Assert run log shows provider switch event.
- [x] [P1] [QA] E2E: dry-run does not mutate — run autopilot dry-run, take SHA-256 hash of all project files before and after, verify: every file hash is identical, no git commits created, STATE.json unchanged, no run log events written

**Phase 5 regression gate:**
- [x] [P1] [QA] Add E2E smoke suite runner — create `test/e2e/autopilot_smoke_suite_test.dart` that runs ALL 8 E2E scenarios sequentially in one test file with shared setup; add a comment at the top: "If this file passes, the autopilot pipeline works end-to-end. Run this after every refactor." This becomes the single go/no-go gate for autopilot health.

### Phase 6: External Project Readiness
Goal: Genaisys can init, configure, and autonomously work on projects that are NOT Dart/Flutter.
Test tier: Integration tests with fixture projects per language. Each fixture proves that init + quality gate + cycle works for that language.
Strategy: Create minimal fixture projects (just enough for init to detect the language and quality gate to run).

**Language detection + profiles:**
- [x] [P1] [CORE] Add project type detection from build system markers — create `lib/core/services/project_type_detection_service.dart` that scans a project root for: `pubspec.yaml` (Dart/Flutter), `package.json` (Node), `requirements.txt`/`pyproject.toml` (Python), `Cargo.toml` (Rust), `go.mod` (Go), `pom.xml`/`build.gradle` (Java); returns detected project type enum
- [x] [P1] [QA] Add test for project type detection — test with fixture directories containing each marker file; verify correct type detection and fallback to "unknown" when no marker found
- [x] [P1] [CORE] Define language-specific quality gate profile model — create a `QualityGateProfile` model with fields: `testCommand`, `lintCommand`, `formatCommand`, `buildCommand` per language; define sensible defaults for Node (`npm test` / `npx eslint .` / `npx prettier --check .`), Python (`pytest` / `ruff check .` / `ruff format --check .`), Rust (`cargo test` / `cargo clippy` / `cargo fmt --check`), Go (`go test ./...` / `golangci-lint run` / `gofmt -l .`)
- [x] [P1] [QA] Add test for quality gate profile defaults — verify each language profile has correct default commands and that Dart/Flutter profile matches current hardcoded behavior (backward compatibility)

**Language-agnostic quality gate:**
- [x] [P1] [CORE] Make `BuildTestRunnerService` language-agnostic — refactor `lib/core/services/build_test_runner_service.dart` to read quality gate commands from a `QualityGateProfile` instead of hardcoded `dart analyze` / `flutter test`; for Dart/Flutter projects, the profile matches current behavior; for other languages, it uses the detected profile
- [x] [P1] [QA] Add test for language-agnostic quality gate — test that BuildTestRunnerService runs `npm test` for a Node project and `pytest` for a Python project when configured with the appropriate profile; also test that Dart/Flutter behavior is IDENTICAL to before the refactor (regression guard)

**Init for external projects:**
- [x] [P1] [CORE] Implement `genaisys init` for external projects — extend `InitService` to: detect project type, select quality gate profile, generate `config.yml` with language-appropriate settings (test/lint/format commands, safe-write roots covering `src/`, `lib/`, `tests/`, etc.), create empty `VISION.md` and `TASKS.md` templates
- [x] [P1] [QA] Add init integration test per project type — create fixture directories for Node, Python, Rust, Go, Java; run `genaisys init` on each and verify: correct config generated, correct quality gate commands, correct safe-write roots; also run init on Dart project and verify output matches current behavior (regression guard)
- [x] [P1] [CORE] Make safe-write roots configurable per project language — in `InitService`, set `safe_write.roots` based on detected project type instead of hardcoded Dart paths (`lib/`, `test/`, etc.); for Node: `src/`, `test/`, `package.json`; for Python: `src/`, `tests/`, `pyproject.toml`; etc.
- [x] [P1] [CORE] Make shell_allowlist extensible per project language — in `InitService`, append language-specific commands to `shell_allowlist` based on project type: Node adds `npm`, `npx`, `node`; Python adds `pip`, `pytest`, `ruff`, `python`; Rust adds `cargo`, `rustc`, `rustfmt`; Go adds `go`, `golangci-lint`; Java adds `mvn`, `gradle`, `java`, `javac`
- [x] [P1] [QA] Add test for language-specific shell_allowlist — verify that init for a Python project includes `pip`, `pytest`, `ruff` in allowlist but not `npm` or `cargo`

**Claude-Code adapter:**
- [x] [P1] [CORE] Add Claude-Code CLI adapter — create `lib/core/agents/claude_code_runner.dart` implementing the `AgentRunner` interface; invoke `claude` CLI with appropriate flags, capture output, handle timeouts and errors matching existing Codex/Gemini adapter patterns
- [x] [P1] [QA] Add test for Claude-Code CLI adapter — test with mock process that simulates Claude Code CLI output; verify request/response mapping, timeout handling, and error classification; also verify it follows same output contract as CodexRunner and GeminiRunner (adapter parity)

**Phase 6 regression gate:**
- [x] [P1] [QA] Add multi-language init regression test — create `test/core/multi_language_init_regression_test.dart` that runs init for ALL supported project types (Dart, Node, Python, Rust, Go, Java) in temp directories and verifies: (1) each produces valid config.yml, (2) each has correct quality gate commands, (3) each has correct safe-write roots, (4) each has correct shell_allowlist, (5) Dart behavior is identical to pre-Phase-6. This single test catches any language support regression.
- [x] [P1] [QA] Add adapter parity test — create `test/core/agent_adapter_parity_test.dart` that verifies CodexRunner, GeminiRunner, and ClaudeCodeRunner all implement the same AgentRunner contract: same input mapping, same output normalization, same timeout behavior, same error classification. Tests with mock processes for all three.

**Documentation:**
- [x] [P1] [DOCS] Document supported project types and configuration — create `docs/project_types.md` listing each supported language/framework, its auto-detected config, quality gate commands, safe-write roots, and shell allowlist; explain how to customize or override

### Phase 7: Autopilot Hardening Test Matrix
Goal: The autopilot is provably reliable under adversarial and edge-case conditions. This phase adds the tests that ensure long-term stability as complexity grows.
Test tier: Stress tests, adversarial tests, and soak tests. These are the "chaos engineering" tests for the autopilot.

**Concurrency and locking:**
- [x] [P1] [QA] Add lock contention test — create `test/core/lock_contention_test.dart` that starts two autopilot runs concurrently on the same project and verifies: second run detects the lock, reports `lock_contention` error, does NOT proceed, and the first run completes normally. Uses real lock file with PID checks.
- [x] [P1] [QA] Add stale lock recovery test — create `test/core/stale_lock_recovery_test.dart` that creates a lock file with a dead PID, runs autopilot, and verifies: lock is recovered with `pid_not_alive` reason logged, autopilot proceeds normally, run log contains recovery event with lock metadata.

**State corruption resilience:**
- [x] [P1] [QA] Add corrupt STATE.json recovery test — create `test/core/corrupt_state_recovery_test.dart` that writes invalid JSON, truncated JSON, and checksum-mismatch JSON to STATE.json, then verifies: StateStore.read() returns `ProjectState.initial()` for each case, corruption callback is invoked with correct diagnostics, autopilot can proceed after recovery.
- [x] [P1] [QA] Add corrupt TASKS.md resilience test — create `test/core/corrupt_tasks_resilience_test.dart` that provides TASKS.md with: empty file, only headers no tasks, malformed checkboxes, mixed encoding, and extremely long lines; verify the task parser handles each gracefully without crashing.

**Autopilot boundary conditions:**
- [x] [P1] [QA] Add max-failures boundary test — run autopilot with `max_failures=1`, verify it halts after exactly 1 failure (not 0, not 2). Then test with `max_failures=5` and 4 failures followed by success, verify it continues.
- [x] [P1] [QA] Add cooldown timing test — set task cooldown to 1 second, trigger a cooldown, attempt immediate reactivation (should fail), wait 1.1 seconds, attempt again (should succeed). Verify cooldown is respected precisely.
- [x] [P1] [QA] Add task retry budget test — set `max_task_retries=2`, run a task that fails twice then succeeds on third attempt, verify: first two failures increment retry counter, third attempt is the last chance, if third also fails the task is blocked permanently.

**Long-running stability:**
- [x] [P1] [QA] Add 10-task soak test — create a temp project with 10 trivial tasks, register `SuccessAgent`, run autopilot loop until idle, verify: all 10 tasks completed, no state corruption, no stale locks, run log has exactly 10 complete cycles, STATE.json is clean at end, no memory leak indicators (temp file cleanup).
- [x] [P1] [QA] Add alternating success/failure soak test — create 10 tasks, register `FlakeAgent(failCount: 1)` so each task fails once then succeeds, run autopilot loop, verify: all 10 tasks eventually complete, retry counts are correct, cooldowns are applied between retries, total cycle count = 20 (10 failures + 10 successes).

**Phase 7 regression gate:**
- [x] [P1] [QA] Add autopilot reliability matrix test — create `test/e2e/autopilot_reliability_matrix_test.dart` that runs the following scenarios in sequence: (1) happy path 3 tasks, (2) one reject + retry, (3) safety halt on 2 failures, (4) stale lock recovery, (5) corrupt state recovery, (6) cooldown respected. All in one test file. If this passes, the autopilot is production-reliable. Add a comment: "This is the release gate — do not merge if this test fails."

## Phase 2c: Orchestrated Init Pipeline

### Input Normalization
- [x] [P1] [CORE] Implement InitInputService: normalize PDF/text/string/stdin to plain text | AC: All input types produce consistent InitInputResult; pdftotext missing produces clear error; unit tests pass.
- [x] [P1] [QA] Add InitInputService unit tests covering all input types and edge cases

### Orchestration Context & Result Models
- [x] [P1] [CORE] Add InitOrchestrationContext model: mutable context threading through pipeline stages | AC: All 6 stage outputs + re-init fields + retry counter; freezed or plain Dart class.
- [x] [P1] [CORE] Add InitOrchestrationResult model: final result DTO with written file paths and retry count

### Pipeline Stages
- [x] [P1] [CORE] Implement InitPipelineStage interface and sealed InitStageOutcome types (Continue/Retry/Failed)
- [x] [P1] [CORE] Implement _VisionStage: agent reads input doc → produces VISION.md content
- [x] [P1] [CORE] Implement _ArchitectureStage: agent reads vision → produces ARCHITECTURE.md content
- [x] [P1] [CORE] Implement _BacklogStage: agent reads vision + architecture → produces TASKS.md initial backlog
- [x] [P1] [CORE] Implement _ConfigStage: agent reads vision + architecture + project type → refines config.yml
- [x] [P1] [CORE] Implement _RulesStage: agent reads vision + architecture → produces RULES.md
- [x] [P1] [CORE] Implement _VerificationStage: orchestrator agent reviews all 5 artifacts → APPROVE or REJECT + feedback
- [x] [P1] [QA] Add unit tests for all 6 pipeline stages with mock AgentService

### Orchestrator Service
- [x] [P1] [CORE] Implement InitOrchestratorService: runs 6-stage pipeline via AgentService.run() directly; retry on REJECT; max 2 full retries; emits run-log events
- [x] [P1] [QA] Add InitOrchestratorService tests: happy path, single-stage retry, max-retry exhaustion, re-init mode

### Re-init Support
- [x] [P1] [CORE] Add re-init detection in InitOrchestratorService: load existing .genaisys/ artifacts as context when --overwrite is set
- [x] [P1] [QA] Add re-init integration test

### CLI & Service Wiring
- [x] [P1] [CORE] Update InitService.initialize(): add fromInput + staticOnly params; delegate to InitOrchestratorService when fromInput provided
- [x] [P1] [CORE] Update init CLI handler: add --from and --static flag parsing; progress output during orchestration; --json support
- [x] [P1] [CORE] Wire InitOrchestratorService through GenaisysApi and use cases
- [x] [P1] [DOCS] Update docs/reference/cli.md with --from and --static flags for init command
- [x] [P1] [QA] Add CLI integration tests for --from and --static flag routing

---

## Completed

### Stabilization Wave 1: Runtime Correctness (Release-Blocking)
- [x] [P1] [SEC] Redact provider secrets and auth tokens from RUN_LOG.jsonl, attempt artifacts, and CLI error surfaces
- [x] [P1] [CORE] Add strict schema validation for STATE.json and config.yml at orchestrator step start with actionable errors
- [x] [P1] [CORE] Make state/task writes atomic and crash-safe (temp file + fsync + rename) for all critical artifacts
- [x] [P1] [CORE] Persist normalized failure reasons (timeout, policy, provider, test, review, git) in state and status APIs
- [x] [P1] [CORE] Enforce deterministic subtask scheduling tie-breakers and log scheduler decision inputs for replayability
- [x] [P1] [REF] Split TaskCycleService into explicit planning/coding/testing/review stages with typed stage boundaries
- [x] [P1] [REF] Refactor OrchestratorStepService into explicit state-transition handlers to reduce hidden coupling
- [x] [P1] [REF] Decompose `lib/core/services/orchestrator_run_service.dart` into orchestrator modules under `lib/core/services/orchestrator/` (loop coordinator, lock handling, release-tag flow, run-log events)
- [x] [P1] [ARCH] Add stabilization guard that blocks selection of non-critical UI tasks while any P1 stabilization task remains open
- [x] [P1] [ARCH] Enforce CLI-first parity rule: interaction-facing tasks require either matching GUI implementation or linked deferred GUI parity task
- [x] [P1] [QA] Add end-to-end crash-recovery tests for failures injected after each cycle stage boundary
- [x] [P1] [QA] Add regression tests for lock races and concurrent CLI actions (activate, done, review, autopilot run)
- [x] [P1] [QA] Add behavior-parity regression tests before/after orchestrator module split (status, stop, safety halts, release-tag events)

### Stabilization Wave 2: Policy and Delivery Hardening
- [x] [P1] [SEC] Add adversarial tests for safe-write bypass attempts (path traversal, symlink edges, relative escapes)
- [x] [P1] [SEC] Add adversarial tests for shell_allowlist bypass attempts (chaining, subshell, separator abuse)
- [x] [P1] [CORE] Enforce DOCS task safe-write scope (docs-only roots) to prevent scope mixing and format-gate reject loops
- [x] [P1] [CORE] Enable docs agent profile in config so DOCS tasks use docs system prompt (reduce no-diff stalls)
- [x] [P1] [CORE] Force git network operations to fail-closed (SSH BatchMode) to prevent unattended hangs on auth/host prompts
- [x] [P1] [CORE] Block task completion when mandatory review evidence bundle is missing or malformed
- [x] [P1] [CORE] Add explicit git delivery preflight (clean index, expected branch, upstream status) before done/merge
- [x] [P1] [CORE] Include provider token exhaustion pause metadata (resume_at, pause_seconds) and count the pause as an idle step with machine-readable reason
- [x] [P1] [CORE] Harden task spec Files parsing to only enforce plausible repo paths (avoid false `spec_required_files_missing` rejects)
- [x] [P1] [CORE] Scope spec-required file enforcement to current subtask targets when available (avoid forced placeholder refactor diffs)
- [x] [P1] [CORE] Make review prompt subtask-aware so partial subtask diffs are judged against current subtask scope (not full parent spec)
- [x] [P1] [CORE] Bootstrap dependencies before running `--no-pub` quality gate tests (ensure `.dart_tool/package_config.json` exists) to avoid false `test_failed` loops
- [x] [P1] [CORE] Avoid rewriting `flutter test` to `dart test` in quality gate unless `pubspec.yaml` declares `dev_dependencies: test` (prevent false `test_failed` in Flutter repos)
- [x] [P1] [CORE] Implement merge conflict recovery playbook hooks with machine-readable outcomes in run log
- [x] [P1] [QA] Add integration tests for guarded rebase/merge conflict paths and manual intervention boundaries
- [x] [P2] [QA] Add JSON contract tests for status/autopilot status output compatibility across edge states
- [x] [P2] [DOCS] Document incident response playbook for blocked/failed tasks and provider exhaustion recovery
- [x] [P2] [DOCS] Document unattended mode release checklist and safety guard expectations

### Stabilization Wave 3: Architecture Debt Paydown
- [x] [P1] [REF] Unify task parsing/writing logic into one shared parser to remove duplication between task stores/services
- [x] [P1] [REF] Replace generic StateError surfaces in app boundaries with typed OperationError mapping
- [x] [P2] [REF] Split `lib/core/config/project_config.dart` into focused config modules (schema/defaults/parser/validation) with stable serialization boundaries
- [x] [P2] [REF] Decompose `lib/core/services/agent_service.dart` into provider execution, prompt assembly, and response normalization modules
- [x] [P2] [REF] Split `lib/core/app/use_cases/in_process_genaisys_api.dart` into domain-focused API delegates (tasks/review/autopilot/config)
- [x] [P2] [REF] Break `lib/core/cli/cli_runner_handlers.dart` into per-command handler modules plus shared presenter/error mapping utilities
- [x] [P2] [REF] Extract shared provider process runner abstraction for codex/gemini adapters
- [x] [P2] [ARCH] Add explicit boundary interfaces for orchestration services (planning, execution, delivery, policy gates)
- [x] [P2] [ARCH] Add simple app state controller for polling status and tasks refresh
- [x] [P2] [QA] Add API parity tests between InProcessGenaisysApi and CLI JSON adapters for shared flows
- [x] [P2] [QA] Add golden tests for run log event schema and required fields per cycle stage

### Stabilization Wave 4: Operational Confidence and Quality Gates
- [x] [P1] [QA] Re-enable zero-analysis-issues quality gate in CI and fail pipeline on any new analyzer warning
- [x] [P1] [QA] Add minimum coverage thresholds for core orchestration and policy modules in CI
- [x] [P1] [CORE] Add autopilot health summary with failure trend, retry distribution, and cooldown visibility
- [x] [P2] [CORE] Add run log retention/rotation policy with size guard and archive strategy
- [x] [P2] [CORE] Add event correlation IDs across run log entries (task id, step id, attempt id, review id)
- [x] [P1] [CORE] Add fail-closed stabilization exit gate in autopilot preflight so feature freeze cannot lift while open P1 tasks remain
- [x] [P1] [QA] Add machine-readable stabilization exit gate CI check and fail pipeline on premature post-stabilization unfreeze
- [x] [P2] [DOCS] Add stabilization exit criteria checklist and declare feature freeze until P1 stabilization backlog is empty

### Stabilization Wave 5: Unattended Operations Autonomy
- [x] [P1] [CORE] Move overnight supervisor lifecycle (start/status/stop/restart) into native `autopilot supervisor` commands and treat shell script as optional wrapper only
- [x] [P1] [CORE] Add persistent supervisor state model in `STATE.json` (session id, start reason, restart count, cooldown, last halt reason)
- [x] [P1] [CORE] Enforce deterministic resume policy after crash/reboot: resume approved-delivery first, else continue next safe step
- [x] [P1] [CORE] Add unattended run profile presets (`pilot`, `overnight`, `longrun`) with validated hard limits and fail-closed defaults
- [x] [P1] [CORE] Add automatic supervisor self-restart with bounded retry budget, exponential backoff, and machine-readable halt reasons
- [x] [P1] [CORE] Block unattended supervisor start when remote push readiness or delivery prerequisites fail preflight
- [x] [P1] [CORE] Add native branch/remote hygiene automation after successful merges (delete merged feature branches local+remote with audit log)
- [x] [P1] [CORE] Add progress watchdog that halts unattended mode on repeated low-signal loops (no meaningful diff/no task advancement) with explicit incident events
- [x] [P1] [CORE] Add unattended throughput guardrails (max token burn per window, max retries per task family, max consecutive review rejects) with deterministic safety halt
- [x] [P1] [QA] Add end-to-end tests for native supervisor lifecycle parity with script behavior (start/status/stop/restart/crash-recover)
- [x] [P1] [QA] Add long-run soak tests (>= 6h simulated clock) validating no deadlock, no lock leak, and bounded retry behavior
- [x] [P1] [QA] Add regressions for reboot/relaunch continuity (state restore, lock recovery, resume policy correctness)
- [x] [P1] [QA] Add integration tests for merged-branch cleanup automation including protected-branch and divergence safeguards
- [x] [P1] [DOCS] Document unattended operations playbook for native supervisor (startup modes, limits, incident handling, safe resume)

### Operative Intelligence (Phase 2 Waves 7-10)
- [x] [P1] [CORE] Build import graph service with layer classification, fan-out analysis, and circular dependency detection (W7.1)
- [x] [P1] [CORE] Add architecture context service with impact analysis injection into coding agent prompts (W7.2)
- [x] [P1] [CORE] Add error pattern registry with persistent observation tracking and prompt injection (W7.3)
- [x] [P1] [CORE] Add task forensics service with rule-based root-cause classification (specTooLarge, specIncorrect, policyConflict, persistentTestFailure, codingApproachWrong) (W8.1)
- [x] [P1] [CORE] Add forensic-gated blocking with one recovery attempt before hard-block (redecompose, regenerateSpec, retryWithGuidance) (W8.2)
- [x] [P1] [CORE] Add architecture health service with layer violation, circular dependency, and fan-out checks (W9.1)
- [x] [P1] [CORE] Integrate architecture health gate into pipeline — block on critical violations, inject warnings into review (W9.2)
- [x] [P1] [CORE] Add review-reject error pattern learning — store resolution strategies from review notes (>= 50 chars) (W10.1)
- [x] [P1] [CORE] Add forensic-driven task re-decomposition — inject specific guidance into spec agent for redecompose/regenerate_spec recovery (W10.2)
- [x] [P1] [QA] Add integration smoke tests and metric baseline for all operative intelligence capabilities (W10.3)

### Post-Stabilization Feature Wave 2: Self-Upgrade and Dogfooding Release Loop
- [x] [P2] [ARCH] Define release-readiness contract (tests/lint/analyze/policy/review/git clean) with machine-readable failure reasons
- [x] [P2] [CORE] Implement readiness score aggregation and expose it in status + run log
- [x] [P2] [CORE] Block runtime promotion when P1 stabilization tasks remain open or review evidence is incomplete
- [x] [P2] [CORE] Build release candidate artifact + manifest (version, commit, checksums, build metadata)
- [x] [P2] [CORE] Register pending runtime candidate and require smoke-check before activation
- [x] [P2] [CORE] Implement safe runtime switch (blue/green style) with deterministic fallback pointer
- [x] [P2] [CORE] Add canary mode for new runtime on low-risk tasks before full activation
- [x] [P2] [CORE] Add hard rollback triggers (fatal errors, crash loops, policy violations, quality regressions)
- [x] [P2] [CORE] Persist upgrade journal entries (old/new runtime, trigger, result, rollback reason)
- [x] [P2] [QA] Add integration tests for promote/switch/canary/rollback state transitions
- [x] [P2] [DOCS] Document operator playbook for manual override, forced rollback, and postmortem collection

### Previously Completed (Misc)
- [x] [P1] [CORE] Move unattended release-candidate and pilot workflow into native `autopilot candidate` / `autopilot pilot` commands and keep script entrypoint as a compatibility wrapper
- [x] [P1] [CORE] Fail release-candidate pilot fast on global format drift and add optional pilot-branch baseline format remediation
- [x] [P1] [CORE] Add unattended release-candidate gate and controlled pilot-run workflow (timebox, hard limits, dedicated branch, incident post-review report)
- [x] [P1] [CORE] Enforce strict definition-of-done checklist in review evidence bundle and block delivery when checklist is missing/incomplete
- [x] [P1] [ARCH] Codify mandatory stabilization critical-path ordering and refactor-last guardrail to prevent silent regressions
- [x] [P1] [ARCH] Formalize global execution rules and strict same-step TASKS.md completion tracking for stabilization roadmap delivery
- [x] [P1] [CORE] Add startup validation for selected provider environment requirements (OPENAI_API_KEY / GEMINI_API_KEY groups) with actionable error messages
- [x] [P1] [CORE] Fail fast in autopilot preflight when selected provider credentials are missing or unreadable (including external auth manager readability checks)
- [x] [P1] [CORE] Ignore `.genaisys/logs/` runtime artifacts in git status to prevent false dirty-repo triggers
- [x] [P1] [CORE] Add fail-closed unattended preflight before step execution (git/review/allowlist/provider/push readiness)
- [x] [P1] [CORE] Normalize unattended reject handling so rejected context is archived and review state is auto-cleared for continuation
- [x] [P1] [CORE] Add adaptive quality-gate execution by diff profile with deterministic auto-format and flaky test retry
- [x] [P1] [CORE] Guard unattended runs from reject/no-diff token burn with progress-failure accounting and cooldown behavior
- [x] [P1] [CORE] Harden single-instance lock ownership with PID-liveness stale-lock recovery audit and deterministic cleanup
- [x] [P1] [CORE] Harden overnight supervisor with throttled self-improve and optional `systemd --user` service workflow
- [x] [P1] [QA] Add anti-block regression suite for reject cleanup, preflight fail-closed behavior, and dynamic quality-gate flow
- [x] [P1] [CORE] Auto-create and push release tags in autopilot when release-readiness gate passes
- [x] [P1] [CORE] Add planning/audit routine to seed periodic ARCH/DOCS/SEC/UI audit tasks with configurable cadence
- [x] [P1] [REF] Run a full self-review of the current core and CLI architecture before new feature work
- [x] [P1] [REF] Create a concrete refactor backlog from self-review findings with small safe steps
- [x] [P1] [QA] Add focused regression checks for every refactor step to prevent fast-iteration breakage
- [x] [P1] [CORE] Add provider account pool rotation on quota/limit errors with UI-managed credentials and autopilot pause when pool is exhausted
- [x] [P1] [CORE] Replace FIFO with dependency-aware subtask scheduler
- [x] [P1] [CORE] Require explicit overnight unattended release flag before unlimited autopilot runs
- [x] [P1] [CORE] Block providers for unattended mode when command-event compliance is missing
- [x] [P1] [CORE] Enforce command-event stream policy fail-closed for agent executions
- [x] [P1] [CORE] Extend AgentRunner with structured command event audit
- [x] [P1] [CORE] Enforce shell_allowlist policy as hard gate in task cycle execution path
- [x] [P1] [QA] Add tests for no diff review reject policy violation analyze fail test fail
- [x] [P1] [QA] Add integration tests for autonomous run lifecycle start loop stop resume crash-recovery
- [x] [P1] [CORE] Build native autonomous loop service in engine (no Bash dependency) with configurable step and idle intervals
- [x] [P1] [CORE] Add `autopilot run` CLI command to run continuous loop until stopped
- [x] [P1] [CORE] Add single-run-lock for autonomous mode (prevent parallel loop instances on same project)
- [x] [P1] [CORE] Persist autonomous runtime state (last loop timestamp current mode last error) in STATE.json
- [x] [P1] [CORE] Add native stop conditions and safety halts (max consecutive failures max reject rounds cooldown)
- [x] [P1] [CORE] Add `autopilot status` CLI command with machine-readable loop health and progress
- [x] [P1] [CORE] Route backlog seeding and next-task selection through native orchestrator only (script parity then script optional)
- [x] [P1] [CORE] Enforce safe-write and diff-budget as hard gates inside task cycle execution path
- [x] [P1] [CORE] Add build/test runner service driven by config.yml with timeouts, logs, and review bundle integration
- [x] [P1] [CORE] Convert generated subtasks into executable queue items (FIFO)
- [x] [P1] [CORE] Add persistent retry resume and cooldown strategy for blocked tasks in orchestrator step flow
- [x] [P1] [CORE] Implement branch-per-task git workflow (create/checkout/merge/delete)
- [x] [P1] [CORE] Add watchdog/heartbeat handling for autopilot run (stall detection, crash-safe resume, STATE markers)
- [x] [P1] [CORE] Add agent runtime timeouts + cancellation for agent CLI execution
- [x] [P1] [CORE] Add live CLI output for autopilot run (tail run log, --quiet to disable)
- [x] [P1] [CORE] Add GUI use cases for done and block actions
- [x] [P1] [CORE] Add GUI use cases for review approve reject and clear actions
- [x] [P1] [CORE] Add GUI use cases for cycle and cycle run actions
- [x] [P1] [CORE] Add GUI use cases for plan spec and subtasks init actions
- [x] [P1] [CORE] Create GUI CLI adapter for MVP JSON reads and writes
- [x] [P1] [CORE] Add dashboard read flow with combined status and review
- [x] [P1] [CORE] Add GUI use cases for dashboard tasks next and review status
- [x] [P1] [CORE] Add GUI use cases for project init activate and deactivate
- [x] [P1] [DOCS] Document CLI and GUI adapter mapping for MVP
- [x] [P2] [DOCS] Update docs gui_min_roadmap with use case layer and screen mapping
- [x] [P1] [CORE] Add guarded rebase/merge and conflict recovery to branch-per-task workflow
- [x] [P1] [CORE] Add deterministic agent failure handling + health checks (CLI availability, timeouts, exit codes) and surface in status/autopilot status
- [x] [P1] [CORE] Add system health-check service (git state, policy files, state integrity) and surface in status/autopilot status
- [x] [P1] [UI] Build read-only MVP screen with project root input and dashboard status
- [x] [P1] [UI] Add tasks list panel wired to GuiTasksUseCase and GuiNextTaskUseCase
- [x] [P1] [UI] Add review status panel wired to GuiReviewStatusUseCase
- [x] [P1] [QA] Add widget tests for dashboard and tasks read flows
- [x] [P2] [UI] Add action buttons for activate deactivate done and block via use cases
- [x] [P2] [UI] Add review action controls approve reject clear via use cases
- [x] [P2] [UI] Add cycle controls including cycle run prompt form
- [x] [P2] [UI] Add init controls for plan spec and subtasks artifacts
- [x] [P2] [QA] Add error-state UI tests for dashboard status and review failures
- [x] [P1] [CORE] Add self-improvement meta tasks for prompts/policies/tests
- [x] [P1] [CORE] Add eval harness with benchmark suite and success tracking
- [x] [P1] [CORE] Add self-tuning config based on success rate

### Phase 2h: Sprint-Based Autonomous Planning
- [x] [P1] [CORE] Add SprintPlannerService: agent-driven sprint planning that seeds new tasks when backlog is idle, respecting max_sprints and vision-fulfillment detection
- [x] [P1] [CORE] Wire sprint planning as HITL Gate 2 injection point (before_sprint) in step-outcome phase
- [x] [P1] [QA] Add SprintPlannerService unit tests: happy path, max sprints reached, vision fulfilled, no-op when backlog not empty

### Phase 2i: Configurable HITL Gates for Autopilot Orchestrator
- [x] [P1] [CORE] Add HitlGateService: writes `.genaisys/locks/hitl.gate`, polls for `.genaisys/locks/hitl.decision`, calls heartbeat each iteration; auto-approves on timeout
- [x] [P1] [CORE] Wire 3 configurable gate injection points: Gate 1 `after_task_done` (step_outcome), Gate 2 `before_sprint` (step_outcome), Gate 3 `before_halt` (progress_check — max_self_restarts and no_progress_threshold)
- [x] [P1] [CORE] Add 5 HITL config keys under `hitl:` section: `enabled`, `timeout_minutes`, `gate_after_task_done`, `gate_before_sprint`, `gate_before_halt`
- [x] [P1] [CORE] Add HitlConfig sub-config view (9th sub-config, lazy getter `config.hitl`)
- [x] [P1] [CORE] Add `genaisys hitl status|approve|skip|reject` CLI commands with `--note` and `--json` flags
- [x] [P1] [CORE] Add `getHitlGate()` and `submitHitlDecision()` to GenaisysApi; wire through InProcessGenaisysApi and GuiHitlUseCase
- [x] [P1] [QA] Add 12 HitlGateService tests + config parity + sub-config tests (2648 total)

### Phase 2i Cleanup: HITL Observability, Deduplication & UX
- [x] [P1] [CORE] Add `step_id` to `HitlGateInfo` and emit it in all 3 HITL run-log events (satisfies §12 log-contract)
- [x] [P1] [CORE] Extract `_runHitlGate()` helper in orchestrator_run_loop_support — replaces 4 duplicated 19-line gate blocks; heartbeat during polling goes through `_trackedHeartbeatRaw` so failures count toward safety halt
- [x] [P1] [CORE] Add `hitlGatePending` + `hitlGateEvent` to `AutopilotStatus` / `AutopilotStatusDto`; `getStatus()` reads pending gate file
- [x] [P1] [CORE] Guard `submitDecision()` with `StateError` when no gate is open to prevent orphaned decision files
- [x] [P1] [CLI] Add `hitl_gate_opened` + `hitl_gate_resolved` to `_importantEvents`; format HITL events in `_RunLogTailer` (rich + log modes)
- [x] [P1] [CLI] Show "⏸ HITL GATE awaiting decision" banner in `genaisys status` with approve/reject hint line; show "⏸ HITL" inline in `genaisys follow` status
- [x] [P1] [QA] Replace local `unawaited` stub with `dart:async`; fix 2 tests to open gate before submit; add 2 new submitDecision validation tests (2651 total)

---

## Deferred (Blocked until MVP phases complete)
All tasks below are blocked until Phases 0-6 above are complete and the autopilot is proven to work on external projects.

### Deferred: Dashboard Cache
- [ ] [BLOCKED] [P2] [ARCH] Add dashboard read snapshot cache with invalidation on task/review/state writes

### Deferred: Benchmark Regression
- [ ] [BLOCKED] [P2] [QA] Add benchmark regression checks for cycle latency and provider call overhead
- [ ] [BLOCKED] [P2] [QA] Add regression benchmarks comparing pre/post-upgrade success rate, cycle time, and failure profile

### Deferred: CLI Completeness Wave 1 — Observability
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys log search` CLI command with filters for event type, task ID, error kind, timestamp range, and regex pattern
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys forensics` CLI command that runs TaskForensicsService on a blocked/failed task
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys arch health` CLI command that runs ArchitectureHealthService and ImportGraphService
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys insights` CLI command that aggregates reflection data
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys storage info` CLI command that shows disk usage breakdown

### Deferred: CLI Completeness Wave 2 — Advanced Task Management
- [ ] [BLOCKED] [P2] [CORE] Add `--search` and `--grep` flags to `genaisys tasks`
- [ ] [BLOCKED] [P2] [CORE] Add `--category` filter to `genaisys tasks`
- [ ] [BLOCKED] [P2] [CORE] Add `--sort` and `--group-by` flags to `genaisys tasks`
- [ ] [BLOCKED] [P2] [CORE] Add `genaisys task show <task-id>` command

### Deferred: CLI Completeness Wave 3 — Operational Control
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys log rotate` CLI command
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys log follow` CLI command
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys error-patterns` CLI command
- [ ] [BLOCKED] [P2] [CORE] Implement `genaisys vision check` CLI command

### Deferred: Supervisor Intelligence
- [ ] [BLOCKED] [P2] [CORE] Integrate ErrorPatternRegistryService into AutopilotSupervisorService
- [ ] [BLOCKED] [P2] [CORE] Add supervisor intervention decision logging
- [ ] [BLOCKED] [P2] [CORE] Add supervisor failure-pattern escalation
- [ ] [BLOCKED] [P2] [CORE] Add supervisor degraded-mode parameter tuning

### Deferred: Pipeline Extensibility
- [ ] [BLOCKED] [P2] [CORE] Implement dynamic pipeline hook-point system
- [ ] [BLOCKED] [P2] [CORE] Add per-step pipeline configuration
- [ ] [BLOCKED] [P2] [CORE] Integrate merge conflict resolution into autopilot git sync loop

### Deferred: Reflection & Self-Tuning Enhancements
- [ ] [BLOCKED] [P2] [CORE] Implement anomaly-based reflection trigger
- [ ] [BLOCKED] [P2] [CORE] Add adaptive reflection frequency
- [ ] [BLOCKED] [P2] [CORE] Integrate VisionAlignmentService into task selection scoring
- [ ] [BLOCKED] [P2] [CORE] Add per-persona optimization task generation
- [ ] [BLOCKED] [P2] [CORE] Add cycle-stage latency instrumentation
- [ ] [BLOCKED] [P2] [CORE] Implement optimization objective function

### Deferred: Observability & Telemetry
- [ ] [BLOCKED] [P2] [CORE] Add provider cost tracking service
- [ ] [BLOCKED] [P2] [CORE] Add failure clustering in RunLogInsightService
- [ ] [BLOCKED] [P2] [CORE] Add cycle performance scorecard service
- [ ] [BLOCKED] [P2] [CORE] Add run log event emission validation

### Deferred: Testing & Quality Infrastructure
- [ ] [BLOCKED] [P2] [QA] Add dedicated tests for remaining untested advanced services
- [ ] [BLOCKED] [P2] [QA] Add error-path tests for support services
- [ ] [BLOCKED] [P2] [QA] Add benchmark regression checks for cycle latency
- [ ] [BLOCKED] [P2] [QA] Add regression benchmarks comparing pre/post-upgrade success rate

### Deferred: Safety & Policy Hardening
- [ ] [BLOCKED] [P2] [SEC] Add safe-write symlink traversal detection
- [ ] [BLOCKED] [P2] [CORE] Add review evidence immutability lock
- [ ] [BLOCKED] [P2] [CORE] Add subtask queue corruption detection and repair
- [ ] [BLOCKED] [P2] [CORE] Add pre-merge diff budget re-validation

### Deferred: Storage & Performance
- [ ] [BLOCKED] [P3] [CORE] Add run log index service for fast event lookup
- [ ] [BLOCKED] [P3] [CORE] Add task store caching with file-watch invalidation
- [ ] [BLOCKED] [P3] [CORE] Add state snapshot archival with compression

### Deferred: Documentation & Vision Alignment
- [ ] [BLOCKED] [P2] [DOCS] Write architecture decision records for non-negotiable invariants
- [ ] [BLOCKED] [P3] [DOCS] Audit and align docs/vision references with implemented behavior

### Deferred: Native Agent Runtime (Phase 3)
- [ ] [BLOCKED] [P2] [ARCH] Define native agent runtime architecture
- [ ] [BLOCKED] [P2] [CORE] Add config schema for direct LLM server endpoints
- [ ] [BLOCKED] [P2] [CORE] Implement provider-neutral LLM client
- [ ] [BLOCKED] [P2] [CORE] Implement internal coding-agent loop
- [ ] [BLOCKED] [P2] [CORE] Implement internal reviewer-agent loop
- [ ] [BLOCKED] [P2] [CORE] Add tool-call orchestration protocol for internal agents
- [ ] [BLOCKED] [P2] [SEC] Harden credential storage and transport for direct LLM server auth
- [ ] [BLOCKED] [P2] [CORE] Add model fallback and routing strategy per workflow stage
- [ ] [BLOCKED] [P2] [QA] Add contract tests for native agent runtime outputs
- [ ] [BLOCKED] [P2] [QA] Add parity benchmark suite comparing native runtime vs external CLI adapters
- [ ] [BLOCKED] [P2] [DOCS] Document migration plan from external CLI adapters to native runtime

### Deferred: Project Bootstrap (Phase 3)
- [ ] [BLOCKED] [P2] [CORE] Implement repository scanner for modules, build system, test setup
- [ ] [BLOCKED] [P2] [CORE] Generate initial vision/backlog proposals from scanner outputs
- [ ] [BLOCKED] [P2] [QA] Add fixture-based bootstrap tests
- [ ] [BLOCKED] [P2] [CORE] Add plan-only onboarding flow

### Deferred: Ecosystem and Team Readiness (Phase 3+)
- [ ] [BLOCKED] [P3] [ARCH] Define plugin API for providers, policy checks, and custom pipeline hooks
- [ ] [BLOCKED] [P3] [CORE] Add audit/report export service
- [ ] [BLOCKED] [P3] [DOCS] Publish operator playbooks and template profiles
- [ ] [BLOCKED] [P3] [CORE] Add optional team-mode primitives

### Deferred: Deep-Scan Init & Project Bootstrap (Phase 4)
- [ ] [BLOCKED] [P2] [CORE] Implement repository scanner service
- [ ] [BLOCKED] [P2] [CORE] Implement project type profile detection
- [ ] [BLOCKED] [P2] [CORE] Implement automatic vision generation from existing codebase
- [ ] [BLOCKED] [P2] [CORE] Implement automatic backlog generation from deep-scan results
- [ ] [BLOCKED] [P2] [CORE] Implement automatic config generation from project profile
- [ ] [BLOCKED] [P2] [CORE] Implement automatic rules extraction from existing code
- [ ] [BLOCKED] [P2] [CORE] Implement commit history analysis in deep-scan
- [ ] [BLOCKED] [P2] [CORE] Implement dependency health check in deep-scan
- [ ] [BLOCKED] [P2] [QA] Add deep-scan integration tests
- [ ] [BLOCKED] [P2] [DOCS] Document deep-scan init workflow

### Deferred: Interactive Self-Configuration (Phase 4)
- [ ] [BLOCKED] [P2] [CORE] Implement architecture planning agent
- [ ] [BLOCKED] [P2] [CORE] Implement language recommendation agent
- [ ] [BLOCKED] [P2] [CORE] Implement security profiling agent
- [ ] [BLOCKED] [P2] [CORE] Implement quality profiling agent
- [ ] [BLOCKED] [P2] [CORE] Implement chat-to-config translation service
- [ ] [BLOCKED] [P2] [CORE] Implement config decision audit trail
- [ ] [BLOCKED] [P2] [CORE] Implement autonomy level spectrum
- [ ] [BLOCKED] [P2] [QA] Add self-configuration integration tests
- [ ] [BLOCKED] [P2] [DOCS] Document self-configuration workflow

### Deferred: CLI-Wrapper Chat Mode (Phase 4)
- [ ] [BLOCKED] [P2] [CORE] Implement CLI-wrapper chat service
- [ ] [BLOCKED] [P2] [CORE] Implement conversation persistence for CLI-wrapper chat
- [ ] [BLOCKED] [P2] [CORE] Implement context injection for CLI-wrapper chat
- [ ] [BLOCKED] [P2] [QA] Add CLI-wrapper chat integration tests

### Deferred: Rich Task Model (Phase 4)
- [ ] [BLOCKED] [P2] [CORE] Extend task parser to read rich task format
- [ ] [BLOCKED] [P2] [CORE] Extend task writer to emit rich task format
- [ ] [BLOCKED] [P2] [CORE] Add RichTask model
- [ ] [BLOCKED] [P2] [CORE] Enrich spec agent output with acceptance criteria
- [ ] [BLOCKED] [P2] [CORE] Add automatic task enrichment on activation
- [ ] [BLOCKED] [P2] [CORE] Inject acceptance criteria into coding agent prompt
- [ ] [BLOCKED] [P2] [CORE] Inject acceptance criteria into review agent prompt
- [ ] [BLOCKED] [P2] [QA] Add rich task parser/writer roundtrip tests
- [ ] [BLOCKED] [P2] [DOCS] Document rich task format specification

### Deferred: LLM-Friendly Artifact Standards (Phase 4)
- [ ] [BLOCKED] [P2] [CORE] Define LLM-friendly writing guidelines
- [ ] [BLOCKED] [P2] [CORE] Add guardrail prompts for weaker models
- [ ] [BLOCKED] [P2] [CORE] Add first-pass-approve tracking per artifact format
- [ ] [BLOCKED] [P2] [CORE] Add model-capability-aware prompt assembly
- [ ] [BLOCKED] [P2] [QA] Add artifact readability tests

### Deferred: Security Audit Mode (Phase 5)
- [ ] [BLOCKED] [P2] [SEC] Implement security scan service
- [ ] [BLOCKED] [P2] [SEC] Implement dependency vulnerability check
- [ ] [BLOCKED] [P2] [SEC] Implement secret leak detection
- [ ] [BLOCKED] [P2] [CORE] Implement security finding to task conversion
- [ ] [BLOCKED] [P2] [CORE] Implement security gate in pipeline
- [ ] [BLOCKED] [P2] [CORE] Integrate security scan as pipeline hook
- [ ] [BLOCKED] [P2] [CORE] Implement periodic security scan scheduling
- [ ] [BLOCKED] [P2] [QA] Add security scan integration tests
- [ ] [BLOCKED] [P2] [DOCS] Document security audit mode configuration

### Deferred: Licensing & Commercialization (Phase 6)
- [ ] [BLOCKED] [P2] [CORE] Add BSL 1.1 license header to all Core/CLI source files
- [ ] [BLOCKED] [P2] [CORE] Add proprietary license header to all GUI source files
- [ ] [BLOCKED] [P2] [DOCS] Create LICENSE file with full BSL 1.1 text
- [ ] [BLOCKED] [P2] [DOCS] Create NOTICE/attribution file
- [ ] [BLOCKED] [P2] [CORE] Implement GUI license check service
- [ ] [BLOCKED] [P2] [CORE] Implement license tier feature gating
- [ ] [BLOCKED] [P2] [SEC] Implement license response signing and verification
- [ ] [BLOCKED] [P2] [CORE] Implement license grace period with cached token
- [ ] [BLOCKED] [P3] [CORE] Implement account management integration
- [ ] [BLOCKED] [P2] [QA] Add license check integration tests
- [ ] [BLOCKED] [P2] [DOCS] Document business model and licensing terms

### Deferred: Rewrite Mode (Phase 7 — Long-Term Vision)
- [ ] [BLOCKED] [P3] [ARCH] Design rewrite mode architecture
- [ ] [BLOCKED] [P3] [CORE] Implement API surface extractor
- [ ] [BLOCKED] [P3] [CORE] Implement behavior extractor
- [ ] [BLOCKED] [P3] [CORE] Implement feature parity backlog generator
- [ ] [BLOCKED] [P3] [CORE] Implement regression verification service
- [ ] [BLOCKED] [P3] [DOCS] Document rewrite mode vision
