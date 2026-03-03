# Provider Process Runner Inventory (Codex/Gemini)

Date: 2026-02-11  
Parent task: Extract shared provider process runner abstraction for codex/gemini adapters  
Status: Inventory only (no runtime behavior changes)

## Minimal Refactor Plan
1. Baseline current behavior and extraction boundaries (this document).
2. Add parity-focused regression tests for shared runner behavior before moving code.
3. Extract one shared process-runner primitive, then migrate Codex and Gemini wrappers incrementally.

## Process-Runner Path Inventory
| Area | Path | Responsibility |
| --- | --- | --- |
| Runner contract | `lib/core/agents/agent_runner.dart` | Defines `AgentRequest`, `AgentResponse`, and `AgentCommandEvent` contracts used by all providers. |
| Codex adapter | `lib/core/agents/codex_runner.dart` | Spawns Codex CLI, handles idle + hard timeouts, applies Codex config override args. |
| Gemini adapter | `lib/core/agents/gemini_runner.dart` | Spawns Gemini CLI, handles hard timeout only, returns command event metadata. |
| Executable resolution | `lib/core/agents/executable_resolver.dart` | Resolves executable path from PATH + default hints for both runners. |
| Process error hints | `lib/core/agents/agent_error_hints.dart` | Maps exit-code class (`126`/`127`) to actionable CLI hints. |
| Provider preflight + policy gate | `lib/core/services/agent_service.dart` | Preflight executable checks, environment normalization, command allowlist enforcement, fallback/pool rotation, quota/unavailable mapping. |
| Consumer parsing | `lib/core/services/coding_agent_service.dart` | Formats stdout/stderr attempt output and maps non-zero exits to operation failure detail. |
| Consumer parsing | `lib/core/services/review_agent_service.dart` | Parses stdout for `APPROVE`/`REJECT`; maps non-zero exits/timeouts. |
| Consumer parsing | `lib/core/services/spec_agent_service.dart` | Uses stdout as artifact content; maps non-zero exits/timeouts. |
| Existing runner tests | `test/core/codex_runner_test.dart`, `test/core/gemini_runner_test.dart`, `test/core/agent_service_test.dart` | Covers input shaping, command metadata, codex idle timeout, fallback/policy behavior. |

## Shared-Behavior Matrix
| Dimension | Codex (`CodexRunner`) | Gemini (`GeminiRunner`) | Extraction implication |
| --- | --- | --- | --- |
| Default spawn command | `codex exec -` | `gemini --prompt - --output-format text` | Keep provider-specific default args in thin wrappers. |
| Executable resolution | `resolveExecutable` + `runInShell = resolved == null` | Same | Extract shared resolution and `runInShell` decision. |
| Stdin payload format | `System: <systemPrompt>\n\n<prompt>` when system prompt exists; else prompt only | Same | Extract shared `buildInput` helper. |
| Environment passed to process | Uses request environment (already normalized by `AgentService`) | Same | Extract shared process-start env plumbing only; keep upstream env normalization in `AgentService`. |
| Provider-specific env behavior | Reads `HEPHAISTOS_CODEX_CLI_CONFIG_OVERRIDES` and inserts validated `-c key=value` args; reads `HEPHAISTOS_AGENT_IDLE_TIMEOUT_SECONDS` | None | Keep as optional provider hook in wrapper (not core runner primitive). |
| Stdout/stderr capture | Stream subscriptions + chunk buffering + explicit finalize/drain | `utf8.decodeStream` futures | Extract shared capture/drain strategy to remove divergence and simplify timeout handling. |
| Hard timeout (`request.timeout`) | Supported; exit `124`; appends `Timed out after Ns.`; command event `timedOut=true` | Same | Extract shared timeout/cancel/error-message path. |
| Idle timeout (no output) | Supported via idle timer; exit `124`; appends idle-timeout message | Not implemented | Keep as configurable optional shared feature; Codex enables, Gemini disables. |
| Process cancellation | `kill()` then `sigkill` (non-Windows) | Same | Extract shared terminate helper. |
| Process-start exception mapping | `ProcessException` -> `126` permission denied, else `127`; appends `AgentErrorHints` | Same | Extract shared exception mapping and error composition. |
| Command metadata | Emits `AgentCommandEvent` with executable, args, runInShell, startedAt, duration, timeout flag, working dir | Same | Extract shared command-event factory. |
| Provider side effects | None | None | Keep shared primitive side-effect free. |
| Higher-level stdout/stderr interpretation | Done in `CodingAgentService` / `ReviewAgentService` / `SpecAgentService` | Same consumer layer | Explicit non-goal for this extraction; do not move parsing into runner abstraction. |

## Extraction Scope (In)
- Shared process lifecycle primitive: start process, write stdin, collect stdout/stderr, enforce hard timeout, terminate, compose response.
- Shared process-start failure mapping (`126`/`127` + hint composition).
- Shared command-event construction.
- Optional shared knobs to preserve behavior parity:
  - idle-timeout duration (enabled for Codex only),
  - argument mutator hook (used by Codex config overrides).

## Non-Goals (Out)
- Provider selection, pool rotation, quota cooldown state, unattended blocklist logic (`AgentService` scope).
- Shell allowlist enforcement and command-event policy gating (`AgentService` scope).
- Prompt construction and response interpretation in coding/review/spec services.
- Any change to public contracts (`AgentRunner`, `AgentRequest`, `AgentResponse`, `AgentCommandEvent`).

## Exact Next Safe Step
Add a focused parity test slice before code movement: create one runner-parity test suite that locks shared expectations for both adapters (process-start exception mapping, hard-timeout exit/message behavior, and command-event fields), then proceed with extraction under that safety net.
