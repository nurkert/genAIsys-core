[Home](../README.md) > [Guides](./README.md) > Quickstart

# Quickstart Guide

Get your project under AI-assisted [orchestration](../glossary.md#orchestrator) in minutes. This guide walks through every step from installation to delivering your first completed task.

---

## Contents

- [Prerequisites](#prerequisites)
- [Step 1: Install Genaisys](#step-1-install-genaisys)
- [Step 2: Initialize Your Project](#step-2-initialize-your-project)
- [Step 3: Configure Provider Credentials](#step-3-configure-provider-credentials)
- [Step 4: Add Tasks to TASKS.md](#step-4-add-tasks-to-tasksmd)
- [Step 5: Run Your First Cycle](#step-5-run-your-first-cycle)
- [Step 6: Review the Output](#step-6-review-the-output)
- [Step 7: Deliver and Continue](#step-7-deliver-and-continue)

---

## Prerequisites

- Git repository (Genaisys requires a git-initialized project)
- At least one AI [provider](../glossary.md#provider) configured (Codex, Gemini, or Claude CLI installed and authenticated)
- Dart SDK (to build and run Genaisys)

## Supported Project Types

Genaisys auto-detects your project language during initialization:

| Project Type | Detected By          |
|-------------|----------------------|
| Dart/Flutter | `pubspec.yaml`      |
| Node.js      | `package.json`      |
| Python       | `pyproject.toml`, `requirements.txt`, `setup.py` |
| Rust         | `Cargo.toml`        |
| Go           | `go.mod`            |
| Java         | `pom.xml`, `build.gradle`, `build.gradle.kts` |

Each detected type generates appropriate [quality gate](../glossary.md#quality-gate) commands (linter, formatter, test runner) and [shell allowlist](../glossary.md#shell-allowlist) entries.

---

## Step 1: Install Genaisys

Clone the Genaisys repository and compile the CLI:

```bash
git clone https://github.com/your-org/genaisys.git
cd genaisys
dart compile exe bin/genaisys.dart -o genaisys

# Move to a directory on your PATH
mv genaisys ~/.local/bin/
```

Verify the installation:

```bash
genaisys help
```

---

## Step 2: Initialize Your Project

Navigate to your project and run `genaisys init`:

```bash
cd /path/to/your-project
genaisys init
```

This creates the [`.genaisys/` directory](../glossary.md#genaisys-directory) structure:

```
.genaisys/
  config.yml          # Project configuration (quality gate, policies, provider settings)
  STATE.json          # Orchestrator state (active task, cycle count, review status)
  VISION.md           # Project vision document (edit with your project goals)
  RULES.md            # Project rules for the AI agents
  TASKS.md            # Task backlog (add your tasks here)
  RUN_LOG.jsonl       # Machine-readable run log
  agent_contexts/     # Architecture context files for agent prompts
  task_specs/         # Generated specs, plans, and subtasks per task
  attempts/           # Incident bundles and heal artifacts
  workspaces/         # Temporary simulation/eval workspaces
  locks/              # Process locks for autopilot
  audit/              # Error patterns, provider state, trend snapshots
  evals/              # Evaluation harness results
  releases/           # Release candidate and stable snapshots
```

To verify the project is healthy:

```bash
genaisys health --json
```

---

## Step 3: Configure Provider Credentials

Genaisys delegates coding and review work to AI [providers](../glossary.md#provider). Configure at least one provider by installing its CLI tool and authenticating:

**Codex (OpenAI):**

```bash
codex auth
```

**Gemini (Google):**

```bash
export GEMINI_API_KEY="your-key-here"
```

**Claude (Anthropic):**

```bash
claude auth
```

Then update `.genaisys/config.yml` to specify your provider:

```yaml
providers:
  primary: codex          # or: gemini, claude-code
  fallback: gemini        # optional fallback provider
  pool:
    - codex@default
    - gemini@default
```

See [Providers Guide](providers.md) for detailed setup of all five supported providers.

---

## Step 4: Add Tasks to TASKS.md

Open `.genaisys/TASKS.md` and add your [tasks](../glossary.md#task). Tasks use a checkbox-based Markdown format:

```markdown
# Backlog

## Phase 1: Foundation

- [ ] [P1] [CORE] Implement user authentication module
- [ ] [P2] [CORE] Add database migration scripts
- [ ] [P2] [QA] Write integration tests for auth module
- [ ] [P3] [GUI] Create login page component
```

Task format: `- [ ] [Priority] [Category] Title`

- **Priority:** `P1` (critical), `P2` (important), `P3` (nice-to-have)
- **Category:** `CORE`, `QA`, `SEC`, `GUI`, `DOCS`, etc.
- **Status:** `- [ ]` (open), `- [x]` (done), `- [b]` (blocked)

Verify your tasks are recognized:

```bash
genaisys tasks --open
```

See [Task Management](task-management.md) for the full task format specification.

---

## Step 5: Run Your First Cycle

The simplest way to run a single orchestration cycle is with `autopilot step`:

```bash
genaisys autopilot step --json
```

This performs a complete cycle:
1. Activates the next open task (highest [priority](../glossary.md#priority) first)
2. Generates a spec and plan for the task
3. Runs the coding [agent](../glossary.md#agent) with the task specification
4. Reviews the agent's output
5. On approval: delivers the changes and marks the task done
6. On rejection: retries or blocks the task

To run with human-readable output:

```bash
genaisys autopilot step
```

---

## Step 6: Review the Output

Check the project status after the cycle:

```bash
genaisys status
```

Inspect what the agent changed:

```bash
git log --oneline -5
```

Review the [run log](../glossary.md#run-log) for detailed events:

```bash
tail -5 .genaisys/RUN_LOG.jsonl
```

If the review rejected the changes:

```bash
genaisys review status --json
```

---

## Step 7: Deliver and Continue

After a successful cycle, the task is marked done in `TASKS.md` automatically. To continue:

### Option A: Single steps (interactive)

```bash
genaisys autopilot step
```

### Option B: Batch run (supervised)

```bash
genaisys autopilot run --max-steps 10 --stop-when-idle
```

### Option C: Continuous run (unattended)

```bash
genaisys autopilot supervisor start --profile overnight
```

Check supervisor status at any time:

```bash
genaisys autopilot supervisor status --json
```

Stop the supervisor when done:

```bash
genaisys autopilot supervisor stop --reason batch_complete
```

---

## Manual Workflow

For more control, you can drive each step individually:

```bash
# 1. See what task is next
genaisys next

# 2. Activate it
genaisys activate

# 3. Generate spec and plan
genaisys spec init
genaisys plan init

# 4. Run a coding cycle with a prompt
genaisys cycle run --prompt "Implement the feature as specified in the plan."

# 5. Review the result
genaisys review status
genaisys review approve --note "Looks good"

# 6. Mark as done
genaisys done

# 7. Deactivate (ready for next task)
genaisys deactivate
```

See [Manual Workflow](manual-workflow.md) for the complete attended flow.

---

## Configuration Tuning

After your first cycles, you may want to tune `.genaisys/config.yml`:

### Quality Gate

```yaml
policies:
  quality_gate:
    enabled: true
    commands:
      - "npm run lint"
      - "npm run test:ci"
```

### Diff Budget

```yaml
policies:
  diff_budget:
    max_files: 20
    max_additions: 2000
    max_deletions: 1500
```

### Autopilot Settings

```yaml
autopilot:
  max_failures: 5           # Stop after N consecutive failures
  max_task_retries: 3       # Block task after N rejections
  step_sleep_seconds: 2     # Pause between productive steps
  idle_sleep_seconds: 30    # Pause when idle
```

### Validate Your Configuration

```bash
genaisys config validate
```

See [Configuration Guide](configuration.md) for all tuning options.

---

## Troubleshooting

### "No open tasks found"

All tasks in TASKS.md are either done or blocked. Add new tasks or unblock existing ones.

### Review keeps rejecting

```bash
genaisys autopilot diagnostics
```

Consider adjusting review strictness:

```yaml
review:
  strictness: "lenient"    # "strict" | "standard" | "lenient"
```

### Provider not responding

```bash
genaisys health --json
```

Check that the provider CLI is installed and authenticated.

### Quality gate failures

Run the quality gate commands manually to identify the issue, then fix or update your config.

See [Troubleshooting](troubleshooting.md) for comprehensive error resolution.

---

## Related Documentation

- [Project Setup](project-setup.md) — Detailed initialization and structure
- [Configuration Guide](configuration.md) — All config options explained
- [Providers](providers.md) — Setup for all five AI providers
- [CLI Reference](../reference/cli.md) — Complete command reference
- [Unattended Operations](unattended-operations.md) — Server deployment and overnight runs
- [Project Types](../reference/project-types.md) — Language-specific configuration details
