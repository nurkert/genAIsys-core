# CLI Handler Target Layout

This directory is the extraction target for `cli_runner_handlers.dart`.
The layout below keeps per-command responsibilities isolated and leaves shared behavior in `lib/core/cli/shared/`.

## Planned Files

- `lib/core/cli/handlers/init_handler.dart`
- `lib/core/cli/handlers/status_handler.dart`
- `lib/core/cli/handlers/cycle_handler.dart`
- `lib/core/cli/handlers/cycle_run_handler.dart`
- `lib/core/cli/handlers/tasks_handler.dart`
- `lib/core/cli/handlers/next_handler.dart`
- `lib/core/cli/handlers/activate_handler.dart`
- `lib/core/cli/handlers/deactivate_handler.dart`
- `lib/core/cli/handlers/spec_files_handler.dart`
- `lib/core/cli/handlers/done_handler.dart`
- `lib/core/cli/handlers/block_handler.dart`
- `lib/core/cli/handlers/review_handler.dart`
- `lib/core/cli/handlers/autopilot_step_handler.dart`
- `lib/core/cli/handlers/autopilot_run_handler.dart`
- `lib/core/cli/handlers/autopilot_candidate_handler.dart`
- `lib/core/cli/handlers/autopilot_pilot_handler.dart`
- `lib/core/cli/handlers/autopilot_cleanup_branches_handler.dart`
- `lib/core/cli/handlers/autopilot_follow_handler.dart`
- `lib/core/cli/handlers/autopilot_status_handler.dart`
- `lib/core/cli/handlers/autopilot_stop_handler.dart`
- `lib/core/cli/handlers/autopilot_smoke_handler.dart`
- `lib/core/cli/handlers/autopilot_simulate_handler.dart`
- `lib/core/cli/handlers/autopilot_improve_handler.dart`
- `lib/core/cli/handlers/autopilot_heal_handler.dart`

## Shared Dependencies to Keep Out of Per-Command Files

- `lib/core/cli/shared/cli_handler_context.dart` (runner dependencies and sinks)
- `lib/core/cli/shared/cli_error_presenter.dart` (`_requireData`, `_presentAppError`, option-validation helpers)
- `lib/core/cli/shared/cli_presenter_selector.dart` (`--json` presenter routing utilities)
- `lib/core/cli/shared/cli_option_parsing.dart` (option readers/parsers currently in utils)
- `lib/core/cli/shared/cli_run_log_tailer.dart` (`_RunLogTailer` extraction target)

