# CLI Handler Extraction Map

Scope: `lib/core/cli/cli_runner_handlers.dart`
Goal: split handlers into per-command modules while preserving behavior and contracts.

## Command Map

| Command route | Current handler | Primary dependency | Presenter path | Error mapping path |
| --- | --- | --- | --- | --- |
| `init` | `_handleInit` | `_api.initializeProject` | `_jsonPresenter.writeInit` / `_textPresenter.writeInit` | `_requireData` -> `_presentAppError` |
| `status` | `_handleStatus` | `_api.getStatus` | `_jsonPresenter.writeStatus` / `_textPresenter.writeStatus` | `_requireData` -> `_presentAppError` |
| `cycle` | `_handleCycle` | `_api.cycle` | `_jsonPresenter.writeCycle` / `_textPresenter.writeCycle` | `_requireData` -> `_presentAppError` |
| `cycle run` | `_handleCycleRun` | `_api.runTaskCycle` | `_jsonPresenter.writeCycleRun` / `_textPresenter.writeCycleRun` | missing `--prompt`: `missing_prompt`, `exitCode=64`; otherwise `_requireData` |
| `autopilot step` | `_handleAutopilotStep` | `_autopilotStep.run` | `_jsonPresenter.writeAutopilotStep` / `_textPresenter.writeAutopilotStep` | `_requireData` -> `_presentAppError` |
| `autopilot run` | `_handleAutopilotRun` | `_autopilotRun.run` + `_RunLogTailer` | `_jsonPresenter.writeAutopilotRun` / `_textPresenter.writeAutopilotRun` | invalid `--max-steps`: `invalid_option`, `exitCode=64`; `AppErrorKind.invalidInput`: `invalid_option`, `exitCode=64`; otherwise `_requireData` |
| `autopilot candidate` | `_handleAutopilotCandidate` | `_autopilotCandidate.run` | `_jsonPresenter.writeAutopilotCandidate` / `_textPresenter.writeAutopilotCandidate` | `_requireData`; if `!data.passed` -> `exitCode=1` |
| `autopilot pilot` | `_handleAutopilotPilot` | `_autopilotPilot.run` | `_jsonPresenter.writeAutopilotPilot` / `_textPresenter.writeAutopilotPilot` | invalid `--duration`/`--max-cycles`: `invalid_option`, `exitCode=64`; `_requireData`; if `!data.passed` -> `exitCode=1` |
| `autopilot cleanup-branches` | `_handleAutopilotCleanupBranches` | `_autopilotCleanupBranches.run` | `_jsonPresenter.writeAutopilotBranchCleanup` / `_textPresenter.writeAutopilotBranchCleanup` | `_requireData` -> `_presentAppError` |
| `autopilot follow` | `_handleAutopilotFollow` | `_autopilotStatus.load` + `_RunLogTailer` | direct text stream via `_writeFollowStatus` | `--json` unsupported -> `invalid_option`, `exitCode=64`; invalid `--status-interval` -> stderr, `exitCode=64`; status load failure -> stderr, `exitCode=1` |
| `autopilot status` | `_handleAutopilotStatus` | `_autopilotStatus.load` | `_jsonPresenter.writeAutopilotStatus` / `_textPresenter.writeAutopilotStatus` | `_requireData` -> `_presentAppError` |
| `autopilot stop` | `_handleAutopilotStop` | `_autopilotStop.run` | `_jsonPresenter.writeAutopilotStop` / `_textPresenter.writeAutopilotStop` | `_requireData` -> `_presentAppError` |
| `autopilot smoke` | `_handleAutopilotSmoke` | `_autopilotSmoke.run` | `_jsonPresenter.writeAutopilotSmoke` / `_textPresenter.writeAutopilotSmoke` | `_requireData` -> `_presentAppError` |
| `autopilot simulate` | `_handleAutopilotSimulate` | `_autopilotSimulation.run` | `_jsonPresenter.writeAutopilotSimulation` / `_textPresenter.writeAutopilotSimulation` | `_requireData` -> `_presentAppError` |
| `autopilot improve` | `_handleAutopilotImprove` | `_autopilotImprove.run` | `_jsonPresenter.writeAutopilotImprove` / `_textPresenter.writeAutopilotImprove` | `_requireData` -> `_presentAppError` |
| `autopilot heal` | `_handleAutopilotHeal` | `_autopilotHeal.run` | `_jsonPresenter.writeAutopilotHeal` / `_textPresenter.writeAutopilotHeal` | `_requireData` -> `_presentAppError` |
| `tasks` | `_handleTasks` | `_api.listTasks` | `_jsonPresenter.writeTasks` / `_textPresenter.writeTasks` | `_requireData` -> `_presentAppError` |
| `next` | `_handleNext` | `_api.getNextTask` | `_jsonPresenter.writeTask` / `_textPresenter.writeNext` | explicit `!result.ok` -> `_presentAppError`; `null` data -> "No open tasks found." |
| `activate` | `_handleActivate` | `_api.activateTask` | `_jsonPresenter.writeActivate` / `_textPresenter.writeActivate` | mutually exclusive `--id`/`--title` -> stderr, `exitCode=64`; otherwise `_requireData` |
| `deactivate` | `_handleDeactivate` | `_api.deactivateTask` | `_jsonPresenter.writeDeactivate` / `_textPresenter.writeDeactivate` | `_requireData` -> `_presentAppError` |
| `spec` | `_handleSpec` -> `_handleSpecFiles` | `_api.initializeSpec` | `_jsonPresenter.writeSpecInit` / `_textPresenter.writeSpecInit` | missing subcommand in json mode -> `missing_subcommand`; then `_handleSpecFiles` missing init -> stderr + `exitCode=64` |
| `plan` | `_handlePlan` -> `_handleSpecFiles` | `_api.initializePlan` | `_jsonPresenter.writeSpecInit` / `_textPresenter.writeSpecInit` | same as `spec` |
| `subtasks` | `_handleSubtasks` -> `_handleSpecFiles` | `_api.initializeSubtasks` | `_jsonPresenter.writeSpecInit` / `_textPresenter.writeSpecInit` | same as `spec` |
| `done` | `_handleDone` | `_api.markTaskDone` | `_jsonPresenter.writeDone` / `_textPresenter.writeDone` | `_requireData` -> `_presentAppError` |
| `block` | `_handleBlock` | `_api.blockTask` | `_jsonPresenter.writeBlock` / `_textPresenter.writeBlock` | `_requireData` -> `_presentAppError` |
| `review status` | `_handleReview` branch | `_api.getReviewStatus` | `_jsonPresenter.writeReviewStatus` / `_textPresenter.writeReviewStatus` | `_requireData` -> `_presentAppError` |
| `review clear` | `_handleReview` branch | `_api.clearReview` | `_jsonPresenter.writeReviewClear` / `_textPresenter.writeReviewClear` | `_requireData` -> `_presentAppError` |
| `review approve/reject` | `_handleReview` branch | `_api.approveReview` / `_api.rejectReview` | `_jsonPresenter.writeReviewDecision` / `_textPresenter.writeReviewDecision` | missing/unknown subcommand uses `missing_subcommand`/`unknown_decision` (`exitCode=64`), then `_requireData` |

## Shared Presenter Usage

- Every command path uses `--json` gate to choose `JsonPresenter` or `TextPresenter`, except `autopilot follow` which is stream-only text output.
- `stdout`/`stderr` are sanitized through `_SanitizingSink`; extraction must preserve this output surface.

## Shared Error Mapping Paths

- Common application failure path:
  - `_requireData(...)` returns `null` on failure.
  - `_presentAppError(...)` emits `state_error` (json) or message to stderr (text).
  - `_presentAppError(...)` sets `exitCode=2`.
- Input-validation path:
  - inline checks map to explicit codes (`missing_prompt`, `invalid_option`, `missing_subcommand`, `unknown_decision`) and set `exitCode=64`.
- Guard result path:
  - boolean status commands (`candidate`, `pilot`) set `exitCode=1` when checks fail while command succeeds technically.

