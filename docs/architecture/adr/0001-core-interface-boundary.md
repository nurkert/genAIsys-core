[Home](../../README.md) > [Architecture](../README.md) > [ADR Index](./README.md) > ADR-0001

# ADR-0001: Core Interface Boundary

**Status:** accepted
**Date:** 2026-02-05

## Context

The GUI was coupled to the CLI adapter via stdout/stderr/exit codes. This made it fragile (string parsing), untestable in isolation, and prevented the GUI from using typed results or structured errors. A stable in-process boundary was needed.

## Decision

1. Introduce application boundary in `lib/core/app/` with contracts (`AppResult`, `AppError`, `GenaisysApi`) and GUI-safe DTOs.
2. Add `InProcessGenaisysApi` implementation delegating to core services.
3. Enforce import boundary in CI: no direct `core/cli` imports outside `lib/core/cli/**`.
4. Keep temporary legacy allowlist for pre-existing GUI MVP files.

## Consequences

- New GUI code depends on `lib/core/app/**` only.
- CLI remains interface adapter (argument parsing / presentation).
- Legacy CLI bridge moved to `lib/core/legacy/gui_cli_adapter.dart`.
- `lib/core/core.dart` no longer exports CLI symbols.
