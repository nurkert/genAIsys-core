[Home](../README.md) > [Reference](./README.md) > Presets

# Presets Reference

Built-in [configuration presets](../glossary.md#config-preset) for common operating modes.

---

## conservative

Safety-first configuration for cautious operation.

| Key | Value | Default | Effect |
|-----|-------|---------|--------|
| `autopilot.max_task_retries` | 2 | 3 | Fewer retries before blocking |
| `autopilot.max_failures` | 3 | 5 | Earlier safety halt |
| `review.max_rounds` | 5 | 5 | Standard review rounds |
| `autopilot.scope_max_files` | 30 | 50 | Smaller change scope |
| `autopilot.scope_max_additions` | 3000 | 5000 | Smaller addition scope |
| `pipeline.forensic_recovery_enabled` | true | false | Forensic analysis on failure |
| `autopilot.self_heal_enabled` | true | true | Self-heal active |

## aggressive

Fast iteration configuration for rapid development.

| Key | Value | Default | Effect |
|-----|-------|---------|--------|
| `autopilot.max_task_retries` | 5 | 3 | More retries before blocking |
| `autopilot.max_failures` | 10 | 5 | Higher failure tolerance |
| `review.max_rounds` | 2 | 5 | Fewer review rounds |
| `autopilot.scope_max_files` | 100 | 50 | Larger change scope |
| `autopilot.scope_max_additions` | 10000 | 5000 | Larger addition scope |
| `autopilot.step_sleep_seconds` | 0 | 2 | No pause between steps |
| `autopilot.idle_sleep_seconds` | 5 | 30 | Shorter idle pause |

## overnight

Long-running unattended configuration.

| Key | Value | Default | Effect |
|-----|-------|---------|--------|
| `autopilot.max_steps` | 500 | 100 | Many more steps |
| `autopilot.max_wallclock_hours` | 8 | 2 | 8-hour wall clock |
| `autopilot.overnight_unattended_enabled` | true | false | Unattended mode active |
| `autopilot.self_restart` | true | false | Auto-restart on stuck |
| `autopilot.self_heal_enabled` | true | true | Self-heal active |
| `autopilot.reactivate_blocked` | true | false | Auto-unblock tasks |
| `autopilot.reactivate_failed` | true | true | Auto-retry failed tasks |
| `autopilot.selection_mode` | `strict_priority` | `fair` | Always pick highest P first |

## Applying Presets

Presets are not applied automatically. Copy the desired values into your `.genaisys/config.yml`:

```yaml
autopilot:
  max_steps: 500
  max_wallclock_hours: 8
  overnight_unattended_enabled: true
  self_restart: true
  reactivate_blocked: true
  selection_mode: strict_priority
```

Or use a preset as a starting point and customize individual values.

---

## Related Documentation

- [Configuration Guide](../guide/configuration.md) — How to tune config
- [Configuration Reference](configuration-reference.md) — All 150+ keys
- [Unattended Operations](../guide/unattended-operations.md) — Overnight run setup
