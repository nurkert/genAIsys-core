# Contributing to Genaisys

## Quick Start

```bash
git clone https://github.com/nurkert/genaisys.git
cd genaisys
dart pub get
dart test
```


For detailed guides, see [`docs/contributing/`](docs/contributing/).

## Contributor License Agreement

By submitting a pull request you grant Niko Pascal Burkert a perpetual, worldwide, non-exclusive, royalty-free license to use, modify, and distribute your contribution under any license, including commercial licenses.

## Key Rules

- **English only** — all code, comments, commit messages, and documentation
- **Zero analyzer issues** — `dart analyze` must report no errors or warnings
- **Tests required** — every behaviour change must include or update tests
- **No new dependencies** without a written justification in the PR description
- **Atomic commits** — one logical change per commit; refactors in their own commit

## Workflow

1. Open an issue or comment on an existing one before starting work
2. Branch: `feat/<slug>` or `fix/<slug>`
3. Implement → test → `dart analyze` → self-review diff
4. Open a PR with a clear description of *why*, not just *what*

## Agent Guidelines

