[Home](../README.md) > [Reference](./README.md) > Exit Codes

# Exit Codes Reference

Complete table of CLI exit codes returned by Genaisys commands.

---

## Exit Code Table

| Code | Name | Description | Typical Cause |
|------|------|-------------|---------------|
| 0 | `success` | Command completed successfully | Normal operation |
| 1 | `state_error` | Operation failed due to invalid project state | Read/write failure, corrupt state |
| 2 | `state_error` | State-level error | No active task, review not approved, precondition unmet |
| 64 | `usage_error` | Invalid command, missing flag, or bad argument | Typo, missing `--prompt`, unknown subcommand |

## Error JSON Format

When `--json` is used and an error occurs:

```json
{"error": "<human-readable message>", "code": "<error_code>"}
```

Where `<error_code>` is one of: `success`, `state_error`, `usage_error`.

## Per-Command Exit Codes

| Command | 0 | 1 | 2 | 64 |
|---------|---|---|---|---|
| `init` | Initialized | — | — | Bad path |
| `cycle` | Updated | — | Not initialized | — |
| `cycle run` | Completed | — | State error | Missing `--prompt` |
| `next` | Found (or none) | — | State error | — |
| `activate` | Activated | — | State error | Both `--id` and `--title` |
| `deactivate` | Cleared | — | State error | — |
| `spec init` | Created | — | State error | Missing subcommand |
| `plan init` | Created | — | State error | Missing subcommand |
| `subtasks init` | Created | — | State error | Missing subcommand |
| `done` | Marked done | — | Not approved | — |
| `block` | Blocked | — | State error | — |
| `review *` | Recorded | — | State error | Unknown subcommand |
| `status` | Displayed | — | State error | — |
| `tasks` | Listed | — | State error | — |
| `app-settings` | Displayed | Read/write fail | — | Invalid option |
| `config validate` | Valid | — | State error | Missing subcommand |
| `config diff` | Displayed | — | State error | Missing subcommand |
| `health` | All OK | — | State error | — |
| `autopilot step` | Completed | — | State error | — |
| `autopilot run` | Completed | — | State error | Invalid option |
| `autopilot stop` | Stopped | — | State error | — |
| `autopilot candidate` | Gates pass | Gates fail | State error | — |
| `autopilot pilot` | Passed | Failed | State error | — |
| `autopilot supervisor *` | Success | — | State error | Unknown subcommand |
| `autopilot diagnostics` | Displayed | — | State error | — |

---

## Related Documentation

- [CLI Reference](cli.md) — All commands with full syntax
