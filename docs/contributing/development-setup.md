[Home](../README.md) > [Contributing](./README.md) > Development Setup

# Development Setup

How to clone, build, test, and set up your IDE for Genaisys development.

---

## Prerequisites

- **Dart SDK** >= 3.0
- **Flutter SDK** (for desktop GUI development)
- **Git**
- At least one AI provider CLI installed (for end-to-end testing)

## Clone and Build

```bash
git clone https://github.com/your-org/genaisys.git
cd genaisys

# Get dependencies
dart pub get

# Build the CLI binary
dart compile exe bin/genaisys_cli.dart -o build/genaisys

# Verify
./build/genaisys help
```

## Running Tests

```bash
# Full test suite
dart test

# Specific test file
dart test test/core/services/task_cycle_service_test.dart

# With concurrency limit (if memory is tight)
dart test --concurrency=1
```

**Important**: Never run more than one `flutter test` or `dart test` process at a time. Parallel test shards create O(N*M) child processes that can exhaust system RAM.

## Running the CLI During Development

```bash
dart run bin/genaisys_cli.dart <command> [path] [flags]
```

## IDE Setup

### VS Code

Recommended extensions:
- Dart (official)
- Flutter (official)

### IntelliJ IDEA / Android Studio

Import as a Dart project. The `pubspec.yaml` will be detected automatically.

### Run Configurations

Create a run config for the CLI:
- **Program**: `bin/genaisys_cli.dart`
- **Arguments**: `status .`
- **Working directory**: Your test project path

## Project Structure

```
lib/
  core/           # Business logic (no Flutter imports)
    agents/       # Provider adapters
    cli/          # CLI handlers and presenters
    config/       # Configuration system
    git/          # Git operations
    models/       # Domain models
    policy/       # Safety policies
    services/     # Core services (orchestrator, review, etc.)
    storage/      # Persistence (atomic writes, state)
    app/          # Application boundary (API, DTOs)
  desktop/        # Platform integration (window services)
  ui/             # Flutter desktop GUI
test/
  core/           # Unit and integration tests
bin/
  genaisys_cli.dart  # CLI entry point
```

See [Architecture Overview](../architecture/overview.md) for the full layer diagram and dependency rules.

## Static Analysis

```bash
dart analyze
```

Must report zero issues. No `// ignore` without documented reason.

---

## Related Documentation

- [Code Standards](code-standards.md) — Dart style and conventions
- [Testing Guidelines](testing-guidelines.md) — Test writing rules
- [Architecture Overview](../architecture/overview.md) — Layer diagram
