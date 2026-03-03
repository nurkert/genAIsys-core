[Home](../README.md) > [Concepts](./README.md) > Git Workflow

# Git Workflow

Genaisys manages git operations automatically through a branch-per-task workflow with merge, stash, and cleanup capabilities.

---

## Branch-per-Task

Every activated task gets a dedicated [feature branch](../glossary.md#feature-branch):

```
main (base branch)
  └── feat/implement-error-handler    (task branch)
  └── feat/add-integration-tests      (task branch)
```

Branch naming follows the pattern: `{feature_prefix}{task-slug}` where:
- `feature_prefix` defaults to `feat/` (config: `git.feature_prefix`)
- `task-slug` is derived from the task title

### Base Branch

The base branch for merges defaults to `main`. Config key: `git.base_branch`.

## Merge Strategy

When a task is approved and marked done, the changes are merged to the base branch:

| Strategy | Config Value | Behavior |
|----------|-------------|----------|
| Merge commit | `merge` | Creates a merge commit |
| Squash | `squash` | Squashes all commits into one |
| Rebase | `rebase` | Rebases onto base branch |

Config key: `workflow.merge_strategy`

After successful merge, the feature branch is deleted locally. Remote branch deletion is controlled by `git.auto_delete_remote_merged_branches`.

## Auto-Commit and Push

| Config Key | Default | Description |
|-----------|---------|-------------|
| `workflow.auto_commit` | `true` | Automatically commit after coding step |
| `workflow.auto_push` | `true` | Automatically push after commit |
| `workflow.auto_merge` | `false` | Automatically merge on approval |

## Git Sync

During autopilot runs, git sync keeps the local repository up to date:

| Config Key | Default | Description |
|-----------|---------|-------------|
| `git.sync_between_loops` | `true` | Pull/push between autopilot loops |
| `git.sync_strategy` | `rebase` | Sync strategy: `rebase` or `merge` |

## Auto-Stash

When the worktree has uncommitted changes that would conflict with operations:

| Config Key | Default | Description |
|-----------|---------|-------------|
| `git.auto_stash` | `true` | Automatically stash dirty worktree |
| `git.auto_stash_skip_rejected` | `false` | Skip stash for rejected review context |

## Branch Cleanup

Merged feature branches can be cleaned up:

```bash
genaisys autopilot cleanup-branches --include-remote --dry-run
```

The cleanup command:
1. Identifies feature branches merged into the base branch
2. Deletes local branches
3. Optionally deletes remote branches (`--include-remote`)
4. Supports dry-run mode

## Dirty Worktree Recovery

The orchestrator includes defense-in-depth for dirty worktree situations:
- `.genaisys/.gitignore` excludes runtime artifacts (STATE.json, RUN_LOG.jsonl, locks/)
- `_enforceRuntimeGitignore()` untracks already-tracked runtime files (one-time migration)
- `_checkoutWithDirtyRecovery` auto-commits before throwing on checkout failures

---

## Related Documentation

- [Orchestration Lifecycle](orchestration-lifecycle.md) — Where git operations fit
- [Task Lifecycle](task-lifecycle.md) — Branch creation on activation
- [Security Model](security-model.md) — Git metadata protection
- [Configuration Reference](../reference/configuration-reference.md) — All git config keys
