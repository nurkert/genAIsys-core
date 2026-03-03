[Home](../README.md) > [Contributing](./README.md) > Testing Guidelines

# Testing Guidelines

CI determinism, resource safety, and testing conventions for Genaisys.

---

## CI Determinism Rule

Tests must pass on clean ephemeral environments (like CI runner containers). Avoid assumptions about:
- Local PATH tools (use mocks or conditional skips)
- Pre-existing git state
- Filesystem timing
- Machine-specific setup

## Resource Safety

**Critical**: Never run more than one `flutter test` or `dart test` process at a time. Parallel test shards spawn multiple child processes and running N shards in parallel creates O(N*M) processes that will exhaust system RAM.

After any OOM incident:
```bash
pkill -f "flutter test"
pkill -f "flutter_tester"
pkill -f "dart:.*frontend"
```

## Test Organization

```
test/
  core/
    services/           # Service unit tests
    policy/             # Policy unit tests
    config/             # Config and registry tests
    cli/                # CLI handler integration tests
    git/                # Git service tests
    agents/             # Agent runner tests
    architecture_imports_test.dart  # Boundary tests
    ui_architecture_boundaries_test.dart
  support/              # Test utilities and helpers
```

## Conventions

- **One test file per source file** where practical
- **Group related tests** with `group()` blocks
- **Descriptive test names**: `'should reject paths outside allowed roots'`
- **Test the contract, not the implementation**: Focus on behavior, not internal state
- **Use `setUp` and `tearDown`** for clean test state

## CLI JSON Tests

- Invoke Dart with `--verbosity=error` to suppress toolchain noise
- Use `test/core/support/cli_json_output_helper.dart` for JSON extraction
- Validate decoded JSON payloads, not raw string equality

## Architecture Boundary Tests

Two tests enforce architectural rules:
- `test/core/architecture_imports_test.dart` — Core never imports UI
- `test/core/ui_architecture_boundaries_test.dart` — UI never imports desktop packages

These must pass for every PR.

## Registry Parity Test

`config_field_registry_test.dart` verifies that every field in `ConfigFieldRegistry` has a matching field in `ProjectConfig`. Run this after adding any config key.

---

## Related Documentation

- [Development Setup](development-setup.md) — Build and run tests
- [Code Standards](code-standards.md) — Dart style rules
- [Architecture Overview](../architecture/overview.md) — Layer boundaries
