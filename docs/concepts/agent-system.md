[Home](../README.md) > [Concepts](./README.md) > Agent System

# Agent System

Genaisys delegates code generation and review to external AI [providers](../glossary.md#provider) through a pluggable [agent](../glossary.md#agent) architecture.

---

## Supported Providers

| Provider | CLI Executable | Auth Method |
|----------|---------------|-------------|
| [Claude Code](../glossary.md#claude-code) | `claude` | Session (`claude login`) or `ANTHROPIC_API_KEY` |
| [Gemini](../glossary.md#gemini) | `gemini` | Session or `GEMINI_API_KEY` (optional) |
| [Codex](../glossary.md#codex) | `codex` | Session (`codex auth`) |
| [Vibe](../glossary.md#vibe) | `vibe` | Session or `MISTRAL_API_KEY` |
| [AMP](../glossary.md#amp) | `amp` | Session (`amp login`) or `AMP_API_KEY` |

## Agent Runner Interface

Each provider implements the `AgentRunner` interface:

```dart
abstract class AgentRunner {
  Future<AgentResponse> run(AgentRequest request);
}
```

The `AgentRequest` contains:
- `prompt` — The composed prompt (task context + coding instructions)
- `workingDirectory` — Project root path
- `environment` — Sanitized environment variables

The `AgentResponse` contains:
- `stdout` — Agent output
- `stderr` — Error output
- `exitCode` — Process exit code

## Provider Pool

The provider pool defines the ordered list of providers available for execution:

```yaml
providers:
  primary: claude-code
  fallback: gemini
  pool:
    - claude-code@default
    - gemini@default
    - codex@default
```

The `primary` provider is promoted to the front of the pool. When a provider exhausts its quota, the pool automatically rotates to the next available provider.

### Quota Management

| Config Key | Default | Description |
|-----------|---------|-------------|
| `providers.quota_cooldown_seconds` | 60 | Pause after quota exhaustion before fallback |
| `providers.quota_pause_seconds` | 300 | Pause before retrying the exhausted provider |

## Agent Roles

The orchestrator assigns different roles to agents during a task cycle:

| Role | Invocation | Purpose |
|------|-----------|---------|
| Coding Agent | Primary provider | Implement code changes |
| Review Agent | Same or different provider | Independent diff review |
| Spec Agent | Primary provider | Generate task specifications |
| Plan Agent | Primary provider | Create implementation plans |

The review agent always runs with fresh context to ensure independent assessment.

## Environment Sanitization

Before invoking any provider CLI, the environment is sanitized:
- `CLAUDECODE` env var is stripped (prevents nested session conflicts)
- Provider-specific overrides are applied via `GENAISYS_<PROVIDER>_CLI_CONFIG_OVERRIDES`
- Idle monitoring is enabled with configurable timeout

## Config Overrides

Each provider supports CLI config overrides through environment variables:

| Provider | Environment Variable | Format |
|----------|---------------------|--------|
| Claude Code | `GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES` | `--flag` or `--flag=value` |
| Gemini | `GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES` | `--flag` or `--flag=value` |
| Codex | `GENAISYS_CODEX_CLI_CONFIG_OVERRIDES` | `key=value` |
| Vibe | `GENAISYS_VIBE_CLI_CONFIG_OVERRIDES` | `--flag` or `--flag=value` |
| AMP | `GENAISYS_AMP_CLI_CONFIG_OVERRIDES` | `--flag` or `--flag=value` |

## Idle Monitoring

All agent runners include idle monitoring to detect hung processes. The configurable timeout (`GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS`, default 300s) kills provider processes that produce no output for too long.

---

## Related Documentation

- [Providers Guide](../guide/providers.md) — Step-by-step setup for each provider
- [Adding Providers](../contributing/adding-providers.md) — How to implement a new provider
- [Orchestration Lifecycle](orchestration-lifecycle.md) — Where agents fit in the pipeline
- [Configuration Reference](../reference/configuration-reference.md) — Provider config keys
