[Home](../README.md) > [Guides](./README.md) > Providers

# Providers

How to set up and configure each AI [provider](../glossary.md#provider) for use with Genaisys.

---

## Supported Providers

Genaisys supports five AI providers. Each wraps a CLI tool that the orchestrator invokes for coding and review tasks.

| Provider | CLI | Install | Auth |
|----------|-----|---------|------|
| Claude Code | `claude` | [Anthropic docs](https://docs.anthropic.com) | `claude login` or `ANTHROPIC_API_KEY` |
| Gemini | `gemini` | [Google docs](https://ai.google.dev) | Session auth or `GEMINI_API_KEY` (optional) |
| Codex | `codex` | [OpenAI docs](https://platform.openai.com) | `codex auth` |
| Vibe | `vibe` | [Mistral docs](https://docs.mistral.ai) | Session auth or `MISTRAL_API_KEY` |
| AMP | `amp` | [Sourcegraph docs](https://sourcegraph.com) | `amp login` or `AMP_API_KEY` |

## Setup

### 1. Install the Provider CLI

Install the CLI tool for your chosen provider and verify it's on your PATH:

```bash
which claude    # or gemini, codex, vibe, amp
```

### 2. Authenticate

Most providers use session-based authentication:

```bash
claude login    # Anthropic Claude
codex auth      # OpenAI Codex
amp login       # Sourcegraph AMP
```

Gemini and Vibe can also use API keys:

```bash
export GEMINI_API_KEY="your-key"
export MISTRAL_API_KEY="your-key"
```

### 3. Configure in config.yml

```yaml
providers:
  primary: claude-code       # Main provider
  fallback: gemini           # Fallback when primary is unavailable
  pool:
    - claude-code@default
    - gemini@default
    - codex@default
```

The `primary` provider is promoted to the front of the pool. The `fallback` is used when the primary hits quota limits.

## Provider Pool

The [provider pool](../glossary.md#provider-pool) enables automatic failover:

1. The orchestrator tries the first provider in the pool
2. On quota exhaustion, it waits `quota_cooldown_seconds` (default: 60)
3. Then rotates to the next provider
4. After `quota_pause_seconds` (default: 300), the exhausted provider becomes eligible again

```yaml
providers:
  quota_cooldown_seconds: 60    # Wait before fallback
  quota_pause_seconds: 300      # Wait before retrying exhausted provider
```

## CLI Config Overrides

Each provider supports custom CLI flags through environment variables:

```bash
# Claude Code: add custom flags
export GENAISYS_CLAUDE_CODE_CLI_CONFIG_OVERRIDES="--model claude-sonnet-4-20250514"

# Gemini: add custom flags
export GENAISYS_GEMINI_CLI_CONFIG_OVERRIDES="--model gemini-2.5-pro"

# Codex: key=value format
export GENAISYS_CODEX_CLI_CONFIG_OVERRIDES="model=o3"

# Vibe: add custom flags
export GENAISYS_VIBE_CLI_CONFIG_OVERRIDES="--model mistral-large"

# AMP: add custom flags
export GENAISYS_AMP_CLI_CONFIG_OVERRIDES="--model default"
```

## Verifying Provider Health

```bash
genaisys health --json
```

The health check verifies that the configured provider CLI is installed and reachable.

## Agent Idle Timeout

To prevent hung provider processes:

```bash
export GENAISYS_AGENT_IDLE_TIMEOUT_SECONDS=300
```

This kills provider processes that produce no output for the specified duration. Default: 300 seconds.

---

## Related Documentation

- [Agent System](../concepts/agent-system.md) — How agents work internally
- [Adding Providers](../contributing/adding-providers.md) — Implementing a new provider
- [Configuration](configuration.md) — Provider config section
- [Configuration Reference](../reference/configuration-reference.md) — All provider keys
