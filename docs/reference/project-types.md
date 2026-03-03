[Home](../README.md) > [Reference](./README.md) > Project Types

# Project Types Reference

Genaisys auto-detects the project language during `genaisys init` and
generates a language-appropriate configuration. This document describes the
supported languages, detection logic, and default configurations.

## Detection Logic

Project type is determined by scanning the project root for well-known
build system marker files. Detection follows a **priority order** -- if
multiple markers are present, the highest-priority match wins:

| Priority | Project Type | Marker Files |
|----------|-------------|--------------|
| 1 | Dart/Flutter | `pubspec.yaml` |
| 2 | Node.js | `package.json` |
| 3 | Python | `pyproject.toml`, `requirements.txt`, `setup.py` |
| 4 | Rust | `Cargo.toml` |
| 5 | Go | `go.mod` |
| 6 | Java | `pom.xml`, `build.gradle`, `build.gradle.kts` |
| -- | Unknown | (no matching markers) |

## Default Configurations per Language

### Dart/Flutter

The default (legacy) configuration. Dart projects use adaptive diff scoping,
which narrows format, analyze, and test commands based on changed file paths.

- **[Quality Gate](../glossary.md#quality-gate) Commands:** `dart format`, `dart analyze`, `dart test`
- **Adaptive by Diff:** Yes
- **[Shell Allowlist](../glossary.md#shell-allowlist) Profile:** `standard`
- **Dependency Bootstrap:** `flutter pub get`

### Node.js

- **Quality Gate Commands:** `npx prettier --check .`, `npx eslint .`, `npm test`
- **Adaptive by Diff:** No
- **Shell Allowlist Profile:** `custom` (base + `npm`, `npx`, `node`)
- **Dependency Bootstrap:** `npm install`

### Python

- **Quality Gate Commands:** `ruff format --check .`, `ruff check .`, `pytest`
- **Adaptive by Diff:** No
- **Shell Allowlist Profile:** `custom` (base + `pip`, `pytest`, `ruff`, `python`, `python3`)
- **Dependency Bootstrap:** None (user manages virtualenv)

### Rust

- **Quality Gate Commands:** `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`
- **Adaptive by Diff:** No
- **Shell Allowlist Profile:** `custom` (base + `cargo`, `rustc`, `rustfmt`)
- **Dependency Bootstrap:** None

### Go

- **Quality Gate Commands:** `gofmt -l .`, `golangci-lint run`, `go test ./...`
- **Adaptive by Diff:** No
- **Shell Allowlist Profile:** `custom` (base + `go`, `golangci-lint`, `gofmt`)
- **Dependency Bootstrap:** None

### Java

- **Quality Gate Commands:** `mvn compile`, `mvn test`
- **Adaptive by Diff:** No
- **Shell Allowlist Profile:** `custom` (base + `mvn`, `gradle`, `java`, `javac`)
- **Dependency Bootstrap:** None

### Unknown

Projects that don't match any known marker files. Quality gate is disabled
by default.

- **Quality Gate:** Disabled
- **[Safe-Write](../glossary.md#safe-write) Roots:** `src`, `lib`, `test`, `docs`, `.genaisys/agent_contexts`, `.github`, `README.md`
- **Shell Allowlist:** Base entries only

## Customization

The generated `config.yml` is a starting point. You can customize any
setting after initialization:

### Changing Quality Gate Commands

Edit `.genaisys/config.yml` under `policies.quality_gate.commands`:

```yaml
policies:
  quality_gate:
    enabled: true
    commands:
      - "npm run lint"
      - "npm run test:ci"
```

### Extending the Shell Allowlist

Add entries under `policies.shell_allowlist`:

```yaml
policies:
  shell_allowlist_profile: "custom"
  shell_allowlist:
    - "rg"
    - "ls"
    - "npm"
    - "npx"
    - "docker compose"
```

### Adjusting Safe-Write Roots

Modify `policies.safe_write.roots` to control which paths agents may write to:

```yaml
policies:
  safe_write:
    enabled: true
    roots:
      - "src"
      - "test"
      - "docs"
      - "package.json"
```

## Base Shell Allowlist

All project types share these base shell allowlist entries for orchestration:

- `rg` -- search
- `ls` -- list files
- `cat` -- read files
- `codex` -- Codex agent CLI
- `gemini` -- Gemini agent CLI
- `claude` -- Claude agent CLI
- `git status`, `git diff`, `git log`, `git show`, `git branch`, `git rev-parse` -- Git read-only operations

---

## Related Documentation

- [Quickstart](../guide/quickstart.md) -- Get started with your first project
- [Project Setup](../guide/project-setup.md) -- Detailed project configuration guide
- [Quality Gates](../concepts/quality-gates.md) -- How quality gates work
- [Configuration Reference](configuration-reference.md) -- All config keys
