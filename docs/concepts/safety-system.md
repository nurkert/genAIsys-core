[Home](../README.md) > [Concepts](./README.md) > Safety System

# Safety System

Genaisys enforces three [policy](../glossary.md#policy) layers to prevent AI agents from causing unintended damage. All policies are [fail-closed](../glossary.md#fail-closed) — uncertain states result in blocking, not permitting.

---

## Safe-Write

**Purpose**: Restrict file writes to explicitly allowed directory roots.

The [Safe-Write](../glossary.md#safe-write) policy validates every file path an agent attempts to write. Writes outside the allowed roots are rejected before reaching the filesystem.

### Violation Categories

| Category | Trigger | Example |
|----------|---------|---------|
| `path_traversal` | `..` traversal beyond project root | `../../etc/passwd` |
| `git_metadata` | `.git/` directory access | `.git/config` |
| `genaisys_control` | Protected `.genaisys/` files | `config.yml`, `RULES.md`, `VISION.md` |
| `genaisys_state` | State file access | `STATE.json` |
| `symlink_escape` | Symlink resolving outside project | `link -> /etc/shadow` |
| `outside_roots` | Path not within any allowed root | `../other-project/src/` |

### Configuration

```yaml
policies:
  safe_write:
    enabled: true
    roots:
      - "lib"
      - "test"
      - "docs"
      - ".genaisys/task_specs"
      - ".genaisys/agent_contexts"
```

The `roots` list defines which directories (relative to project root) agents may write to. Language-specific defaults are generated during `genaisys init`.

### Implementation

`SafeWritePolicy` (`lib/core/policy/safe_write_policy.dart`):
- Validates paths against allowed roots
- Detects path traversal attempts (counting `..` depth)
- Checks for symlink escapes by resolving real paths
- Handles URL-encoded path segments
- Returns structured `SafeWriteViolation` on rejection

## Shell Allowlist

**Purpose**: Restrict which shell commands agents may execute.

The [Shell Allowlist](../glossary.md#shell-allowlist) prevents agents from running arbitrary commands. Only commands matching allowed prefixes are permitted.

### Security Properties

- **No shell operators**: Pipes (`|`), chains (`;`, `&&`, `||`), redirects (`>`, `<`) are rejected
- **No command substitution**: Backticks and `$(...)` are rejected
- **Prefix matching**: The command's executable must match an allowed prefix
- **Tokenized parsing**: Commands are parsed into tokens; only the executable is checked

### Configuration

```yaml
policies:
  shell_allowlist_profile: "standard"  # or "custom"
  shell_allowlist:
    - dart format
    - dart analyze
    - dart test
    - git status
    - git diff
    - git log
```

### Base Allowlist (All Project Types)

All projects include these base entries:
- `rg`, `ls`, `cat` — File reading
- `codex`, `gemini`, `claude` — Agent CLIs
- `git status`, `git diff`, `git log`, `git show`, `git branch`, `git rev-parse` — Git read-only

### Implementation

`ShellAllowlistPolicy` (`lib/core/policy/shell_allowlist_policy.dart`):
- `ShellCommandTokenizer.tryParse()` splits the command into tokens
- Rejects commands with dangerous characters (`;`, `|`, `&`, `` ` ``, `$(`)
- Checks the executable token against allowed prefixes

## Diff Budget

**Purpose**: Limit the size of changes per step to prevent runaway modifications.

The [Diff Budget](../glossary.md#diff-budget) constrains three dimensions of change:

| Constraint | Config Key | Default |
|-----------|-----------|---------|
| Max files changed | `policies.diff_budget.max_files` | 20 |
| Max lines added | `policies.diff_budget.max_additions` | 2000 |
| Max lines deleted | `policies.diff_budget.max_deletions` | 1500 |

### Configuration

```yaml
policies:
  diff_budget:
    max_files: 20
    max_additions: 2000
    max_deletions: 1500
```

### Scope Limits (Cumulative)

The autopilot also tracks cumulative scope across the entire run:

| Config Key | Description |
|-----------|-------------|
| `autopilot.scope_max_files` | Total files changed across all steps |
| `autopilot.scope_max_additions` | Total lines added across all steps |
| `autopilot.scope_max_deletions` | Total lines deleted across all steps |

When cumulative scope limits are hit, the autopilot terminates regardless of remaining step budget.

### Implementation

`DiffBudgetPolicy` (`lib/core/policy/diff_budget_policy.dart`):
- Takes a `DiffBudget` (limits) and `DiffStats` (actual changes)
- Returns boolean pass/fail checking all three constraints

---

## Related Documentation

- [Orchestration Lifecycle](orchestration-lifecycle.md) — Where policies fit in the pipeline
- [Security Model](security-model.md) — Threat model and fail-closed design
- [Quality Gates](quality-gates.md) — Verification after policy checks
- [Configuration Reference](../reference/configuration-reference.md) — All policy config keys
