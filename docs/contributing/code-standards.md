[Home](../README.md) > [Contributing](./README.md) > Code Standards

# Code Standards

Dart coding style, conventions, and quality rules for Genaisys.

---

## The Scout Rule

Always leave the code cleaner than you found it. If you see small inconsistencies, unused imports, or minor technical debt in the files you are touching, fix them as part of your task.

## Dart Style

- Follow the official [Dart style guide](https://dart.dev/effective-dart/style)
- Use Dart's strong type system — avoid `dynamic`
- Prefer `final` fields and constructor parameters
- Use named parameters for constructor-heavy classes
- Use `const` constructors wherever possible

## Naming

- Classes: `PascalCase`
- Variables, functions: `camelCase`
- Constants: `camelCase` (Dart convention, not `SCREAMING_CASE`)
- File names: `snake_case.dart`
- Private members: prefix with `_`

## Imports

- Sort imports alphabetically
- Group: dart:*, package:*, relative imports
- Remove unused imports (analyzer will catch this)

## Comments

- Only add comments where the logic isn't self-evident
- Use `///` doc comments for public APIs
- Don't add comments to code you didn't change

## Dependency Hygiene

Think twice before adding a new library:
- Prefer small, focused, internal solutions over heavy external dependencies
- Document the rationale for any new dependency in the PR
- Check the dependency's maintenance status and size

## Error Handling

- Use typed error classes, not string messages
- Prefer `AppResult<T>` at the application boundary
- Don't catch exceptions you can't handle meaningfully
- Only validate at system boundaries (user input, external APIs)

## English Only

All code, comments, logs, task specs, and internal artifacts must be in English.

## Atomic Commits

Keep commits focused:
- A refactoring step is its own commit
- A feature implementation is its own commit
- Don't mix refactoring with feature work

---

## Related Documentation

- [Development Setup](development-setup.md) — Build and test setup
- [Testing Guidelines](testing-guidelines.md) — Test conventions
- [Architecture Overview](../architecture/overview.md) — Layer boundaries
