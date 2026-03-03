[Home](README.md) > Glossary

# Glossary

Alphabetical reference of Genaisys-specific terms. Every documentation page links here on first use of a term.

---

## A

### Activate
Transition an open [task](#task) from the [backlog](#backlog) to "In Progress" status, creating a dedicated [feature branch](#feature-branch) and updating [STATE.json](#statejson). See [Task Lifecycle](concepts/task-lifecycle.md).

### Adaptive Diff
A [quality gate](#quality-gate) mode that adjusts which checks run based on the size and type of the current diff. For example, docs-only changes may skip test execution. See [Quality Gates](concepts/quality-gates.md).

### Agent
A specialized AI worker invoked by the [orchestrator](#orchestrator) to perform a specific role (coding, review, planning, etc.). Agents are executed through [provider](#provider) CLI adapters. See [Agent System](concepts/agent-system.md).

### Agent Runner
The interface that adapts a [provider](#provider) CLI into a standardized execution contract. Each provider (Claude Code, Gemini, Codex, Vibe, AMP) has its own runner implementation. See [Adding Providers](contributing/adding-providers.md).

### AMP
Sourcegraph's Amp — one of the supported AI [providers](#provider). Invoked via the `amp` CLI.

### Approve Budget
Maximum number of auto-approvals the [autopilot](#autopilot) may perform in a single run. Config key: `autopilot.approve_budget`. See [Configuration Reference](reference/configuration-reference.md).

### Attempt
A single [agent](#agent) invocation producing a diff and logs. Multiple attempts may occur per [subtask](#subtask) if the [review](#review) rejects the first try. Archived in `.genaisys/attempts/`.

### Audit Trail
Structured log of all reliability-critical events (preflight failures, stash/restore, lock recovery, safety halts). Stored in [RUN_LOG.jsonl](#run-log). See [Run Log Schema](reference/run-log-schema.md).

### Autopilot
The autonomous execution mode that processes the [backlog](#backlog) without human intervention. Runs a [state machine](#state-machine) loop of activate → plan → code → review → deliver. See [Autonomous Execution](guide/autonomous-execution.md).

## B

### Backlog
The collection of open [tasks](#task) in `.genaisys/TASKS.md`, organized by priority and category. The [orchestrator](#orchestrator) draws work from the backlog. See [Task Management](guide/task-management.md).

### Blocked
A [task](#task) state indicating it cannot proceed without manual intervention or external resolution. Blocked tasks are skipped by the [autopilot](#autopilot) unless `reactivate_blocked` is enabled. See [Task Lifecycle](concepts/task-lifecycle.md).

## C

### Claude Code
Anthropic's Claude — one of the supported AI [providers](#provider). Invoked via the `claude` CLI.

### Codex
Sourcegraph's Codex — one of the supported AI [providers](#provider). Invoked via the `codex` CLI.

### Coding Agent
The [agent](#agent) role responsible for implementing code changes. The coding agent receives a prompt with task context and produces a diff. See [Agent System](concepts/agent-system.md).

### Cooldown
A time delay applied before a failed or blocked [task](#task) becomes eligible for reactivation. Config keys: `blocked_cooldown_seconds`, `failed_cooldown_seconds`. See [Task Lifecycle](concepts/task-lifecycle.md).

### Config Preset
A named set of configuration overrides optimized for a specific use case: `conservative` (safety-first), `aggressive` (fast iteration), or `overnight` (long-running unattended). See [Presets](reference/presets.md).

### Context Injection
The [pipeline](#pipeline) step that prepends project architecture, rules, and task context to the [agent](#agent) prompt. Config key: `pipeline.context_injection_enabled`. See [Orchestration Lifecycle](concepts/orchestration-lifecycle.md).

### Core Engine
The orchestration logic in `lib/core/` — no Flutter UI imports allowed. The Core Engine manages tasks, policies, git, agents, and state independently of any presentation layer. See [Architecture Overview](architecture/overview.md).

## D

### Data Contracts
The schemas and integrity guarantees for all `.genaisys/` artifacts (STATE.json, TASKS.md, RUN_LOG.jsonl, config.yml, etc.). See [Data Contracts](reference/data-contracts.md).

### Definition of Done (DoD)
A checklist in the [review evidence bundle](#evidence-bundle) that must be complete before a task can be marked done. The DoD gate is fail-closed. See [Review System](concepts/review-system.md).

### Diff Budget
A [policy](#policy) limiting the size of changes per step — maximum files changed, lines added, and lines deleted. Prevents runaway agents from making sweeping modifications. See [Safety System](concepts/safety-system.md).

## E

### Error Pattern Learning
A [pipeline](#pipeline) feature that analyzes past failures to inject preventive guidance into future [agent](#agent) prompts. Config key: `pipeline.error_pattern_learning_enabled`. See [Self-Improvement](concepts/self-improvement.md).

### Evidence Bundle
A structured package of review artifacts (diff summary, test results, DoD checklist) required for task completion. See [Review System](concepts/review-system.md).

### Exit Gate
See [Stabilization Exit Gate](#stabilization-exit-gate).

## F

### Fail-Closed
A design principle where uncertain or invalid states result in blocking (not proceeding). All [preflight](#preflight) checks, [policy](#policy) decisions, and [review gates](#review-gate) follow this principle. See [Security Model](concepts/security-model.md).

### Fair Selection
A [task selection mode](#selection-mode) that balances priority with fairness — lower-priority tasks get a chance after higher-priority tasks have been served within a window. Config key: `autopilot.selection_mode: fair`. See [Task Lifecycle](concepts/task-lifecycle.md).

### Feature Branch
A git branch created per [task](#task) following the pattern `{feature_prefix}{task-slug}` (default: `feat/task-slug`). See [Git Workflow](concepts/git-workflow.md).

### Forensic Recovery
A [pipeline](#pipeline) feature that attempts to recover from stuck states by analyzing recent failures and applying targeted repairs. Config key: `pipeline.forensic_recovery_enabled`. See [Self-Improvement](concepts/self-improvement.md).

### Fresh Context
A [review](#review) setting that instantiates the review agent without any carry-over from the coding agent, ensuring independent assessment. Config key: `review.fresh_context`. See [Review System](concepts/review-system.md).

## G

### Gemini
Google's Gemini — one of the supported AI [providers](#provider). Invoked via the `gemini` CLI.

### Git Sync
Automatic git pull/push between [autopilot](#autopilot) loops to keep the local repository synchronized. Config keys: `git.sync_between_loops`, `git.sync_strategy`. See [Git Workflow](concepts/git-workflow.md).

### HITL Gate

A Human-in-the-Loop checkpoint where the [autopilot](#autopilot) suspends execution and waits for an explicit human decision before continuing. The autopilot writes `.genaisys/locks/hitl.gate` with gate context and polls for `.genaisys/locks/hitl.decision`. Decision options are **approve** (continue), **reject** (terminate cleanly), or auto-approve after `hitl.timeout_minutes`. Gates are configured per checkpoint type: `after_task_done`, `before_sprint`, `before_halt`. See [Configuration Reference: hitl](reference/configuration-reference.md#hitl).

## H

### Health Check
A diagnostic report on project and [autopilot](#autopilot) state. Available via `genaisys health` CLI command. See [CLI Reference](reference/cli.md).

### Genaisys Directory
The `.genaisys/` directory at the project root — the single source of truth for all orchestrator state, logs, configuration, and artifacts. See [Project Setup](guide/project-setup.md).

### Hotspot
A source file with elevated churn, complexity, or repeated modifications detected by the [code health](#code-health) system. Hotspots may trigger automatic task creation for refactoring. See [Code Health](concepts/code-health.md).

## I

### Idle Step
An [autopilot](#autopilot) step that produces no meaningful progress (no diff, no task transition). Consecutive idle steps may trigger `stop-when-idle` termination. See [State Machine](concepts/state-machine.md).

## L

### Lock
A `.genaisys/locks/autopilot.lock` file ensuring only one [autopilot](#autopilot) instance runs at a time. Includes PID liveness checks for dead-lock recovery. See [State Machine](concepts/state-machine.md).

## N

### Native Agent Runtime
Direct LLM API integration (bypassing CLI wrappers) for lower latency and finer control. Currently in development (Phase 2). See [Roadmap](project/roadmap.md).

### No-Progress Detection
The [orchestrator's](#orchestrator) mechanism for detecting when repeated steps produce no useful work, triggering backoff or self-restart. See [State Machine](concepts/state-machine.md).

## O

### Orchestrator
The central engine that drives the [autopilot](#autopilot) loop — a 7-phase [state machine](#state-machine) managing task selection, agent invocation, review, and delivery. See [State Machine](concepts/state-machine.md).

### Overnight Profile
A [config preset](#config-preset) optimized for long-running unattended operation: 500 max steps, 8-hour wall clock, self-restart enabled. See [Unattended Operations](guide/unattended-operations.md).

## P

### Planning
A [workflow stage](#workflow-stage) where the [orchestrator](#orchestrator) generates a task specification, implementation plan, and [subtask](#subtask) queue before coding begins. See [Subtask Decomposition](concepts/subtask-decomposition.md).

### Pipeline
The sequence of processing steps applied during each [autopilot](#autopilot) cycle: context injection, error pattern injection, impact analysis, coding, quality gate, review. See [Orchestration Lifecycle](concepts/orchestration-lifecycle.md).

### Policy
A safety constraint enforced by the [orchestrator](#orchestrator) — [Safe-Write](#safe-write), [Shell Allowlist](#shell-allowlist), or [Diff Budget](#diff-budget). See [Safety System](concepts/safety-system.md).

### Preflight
A fail-closed check sequence that verifies all preconditions before each [autopilot](#autopilot) step: project structure, git safety, review policy, policy health, provider readiness. See [State Machine](concepts/state-machine.md).

### Priority
Task urgency level: P1 (critical), P2 (important), P3 (nice-to-have). Influences [task selection](#selection-mode) order. See [Task Management](guide/task-management.md).

### Provider
An AI service backend (Claude Code, Gemini, Codex, Vibe, AMP) that executes [agent](#agent) work through its CLI. See [Providers](guide/providers.md).

### Provider Pool
The ordered list of [providers](#provider) available for [agent](#agent) execution, with automatic failover on quota exhaustion. Config key: `providers.pool`. See [Agent System](concepts/agent-system.md).

## Q

### Quality Gate
A pipeline of verification commands (format, lint, analyze, test) that must pass before a diff can be reviewed. See [Quality Gates](concepts/quality-gates.md).

### Quota Cooldown
A pause applied when a [provider](#provider) exhausts its API quota, before the [orchestrator](#orchestrator) falls back to the next provider in the pool. Config key: `providers.quota_cooldown_seconds`. See [Agent System](concepts/agent-system.md).

## R

### Reflection
A periodic meta-analysis of [autopilot](#autopilot) productivity that generates optimization tasks. Config section: `reflection.*`. See [Self-Improvement](concepts/self-improvement.md).

### Review
An independent assessment of a code diff by a review [agent](#agent). The review gate is mandatory — no [task](#task) can be completed without explicit approval. See [Review System](concepts/review-system.md).

### Review Gate
The mandatory review checkpoint that blocks task completion until explicit approval. [Fail-closed](#fail-closed) — uncertain review state blocks delivery. See [Review System](concepts/review-system.md).

### Run Log
The `.genaisys/RUN_LOG.jsonl` file — a structured JSONL audit trail of all orchestrator events. Rotated by size with archives in `.genaisys/logs/run_log_archive/`. See [Run Log Schema](reference/run-log-schema.md).

## S

### Safe-Write
A [policy](#policy) that restricts file writes to explicitly allowed directory roots. Prevents agents from modifying files outside the project scope. See [Safety System](concepts/safety-system.md).

### Safety Halt
An emergency stop triggered when the [orchestrator](#orchestrator) detects unrecoverable states (exceeded failure budgets, repeated rejects, stuck loops). See [State Machine](concepts/state-machine.md).

### Selection Mode
The algorithm used by the [autopilot](#autopilot) to choose the next task: `strict_priority` (highest P first), `fair` (priority-weighted with fairness window), `round_robin`. Config key: `autopilot.selection_mode`. See [Task Lifecycle](concepts/task-lifecycle.md).

### Self-Heal
An automated repair mechanism that attempts to fix detected issues (git state, config drift, stuck locks) without human intervention. Config key: `autopilot.self_heal_enabled`. See [Self-Improvement](concepts/self-improvement.md).

### Self-Improvement
The collective system of [reflection](#reflection), [self-tune](#self-tune), [self-heal](#self-heal), and [error pattern learning](#error-pattern-learning) that enables Genaisys to optimize its own operation over time. See [Self-Improvement](concepts/self-improvement.md).

### Self-Tune
An [autopilot](#autopilot) feature that adjusts configuration parameters (sleep timers, retry limits) based on observed performance. Part of the [reflection](#reflection) system. See [Self-Improvement](concepts/self-improvement.md).

### Shell Allowlist
A [policy](#policy) that restricts which shell commands agents may execute. Commands must match allowed prefixes; shell operators (pipes, chains) are rejected. See [Safety System](concepts/safety-system.md).

### Sprint

A bounded set of tasks generated by the [SprintPlannerService](#sprint-planner) when the backlog is exhausted. Each sprint is aligned with the project vision and contains `autopilot.sprint_size` tasks (default 8). Sprints enable indefinite autonomous operation without manual backlog maintenance.

### Sprint Planner

The `SprintPlannerService` component that generates new task sprints when the backlog is empty and `autopilot.sprint_planning_enabled: true`. Uses the project vision document to derive the next increment of work. Emits `sprint_planning_started`, `sprint_planning_complete`, `sprint_max_reached`, and `sprint_vision_fulfilled` run-log events. See [Sprint-Based Planning](guide/autonomous-execution.md#sprint-based-planning).

### Single Source of Truth
A design principle: all orchestrator state, configuration, logs, and task data lives in the [`.genaisys/` directory](#genaisys-directory). There are no hidden state machines or external databases. See [Data Contracts](reference/data-contracts.md).

### Sovereign Orchestration
The core philosophy: Genaisys manages a disciplined software lifecycle with non-negotiable rules, not just code generation. The orchestrator is the authority. See [Vision](project/vision.md).

### Stabilization Exit Gate
A mandatory gate that blocks post-stabilization feature work until all P1 tasks reach zero. Machine-checked in CI and fail-closed in preflight. See [Roadmap](project/roadmap.md).

### State Machine
The 7-phase loop driving the [orchestrator](#orchestrator): gateCheck → preflight → stepExecution → stepOutcome → errorRecovery → progressCheck → sleepAndLoop. See [State Machine](concepts/state-machine.md).

### STATE.json
The `.genaisys/STATE.json` file — runtime state including active task, workflow stage, step counters, and review status. Schema-validated on every read. See [STATE.json Schema](reference/state-json-schema.md).

### Step
A single iteration of the [autopilot](#autopilot) loop — one complete cycle through the [state machine](#state-machine) phases. See [State Machine](concepts/state-machine.md).

### Strict Priority
A [task selection mode](#selection-mode) that always picks the highest-priority open task. Config key: `autopilot.selection_mode: strict_priority`. See [Task Lifecycle](concepts/task-lifecycle.md).

### Subtask
A granular work unit decomposed from a parent [task](#task). Subtasks form a queue processed sequentially, each producing its own [attempt](#attempt) and [review](#review). See [Subtask Decomposition](concepts/subtask-decomposition.md).

### Supervisor
A meta-orchestrator that monitors the [autopilot](#autopilot), detects problems (hangs, repeated failures), and can restart or heal the process. Config section: `supervisor.*`. See [Unattended Operations](guide/unattended-operations.md).

## T

### Task
A work unit in the [backlog](#backlog), defined in `.genaisys/TASKS.md`. Has a priority (P1–P3), category (CORE, QA, SEC, GUI, DOCS), and lifecycle state. See [Task Management](guide/task-management.md).

### Task Spec
A markdown file in `.genaisys/task_specs/` containing the technical specification for a [task](#task) — problem statement, approach, acceptance criteria, and [subtask](#subtask) list. See [Subtask Decomposition](concepts/subtask-decomposition.md).

## V

### Vibe
Mistral's Vibe — one of the supported AI [providers](#provider). Invoked via the `vibe` CLI.

### Vision
The `.genaisys/VISION.md` file — the project's long-term goals and architectural principles. Injected as context into [agent](#agent) prompts. See [Project Setup](guide/project-setup.md).

## W

### Workflow Stage
The current phase of the active [task's](#task) processing: `planning`, `coding`, `reviewing`, `delivering`. Tracked in [STATE.json](#statejson). See [Task Lifecycle](concepts/task-lifecycle.md).
