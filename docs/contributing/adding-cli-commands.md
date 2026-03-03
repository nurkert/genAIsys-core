[Home](../README.md) > [Contributing](./README.md) > Adding CLI Commands

# Adding CLI Commands

How to add a new command to the Genaisys CLI using the handler + presenter pattern.

---

## Pattern

Every CLI command consists of:
1. **Handler** — Parses arguments, delegates to core services
2. **Presenter** — Formats output as text or JSON

## Steps

### 1. Create the Handler

Add a new file in `lib/core/cli/handlers/`:

```dart
extension MyCommandHandler on GenaisysCliRunner {
  Future<int> _handleMyCommand(ArgResults options) async {
    final String root = _extractRoot(options);
    final bool json = options['json'] as bool? ?? false;

    // Delegate to core service
    final result = await _myService.doSomething(root);

    // Present result
    if (json) {
      _presentJson({'my_field': result.value});
    } else {
      _presentText('Result: ${result.value}');
    }

    return 0; // exit code
  }
}
```

### 2. Register the Command

Add the command to the CLI runner's command dispatch in the main handler.

### 3. Add Flags

Define flags using the `ArgParser`:

```dart
parser.addFlag('json', help: 'Output machine-readable JSON.');
parser.addOption('my-option', help: 'Description of the option.');
```

### 4. Follow the JSON Contract

- Single-line JSON to stdout
- Error format: `{"error": "<message>", "code": "<error_code>"}`
- Existing fields are stable (additive only)
- Use `_presentJson()` for consistent formatting

### 5. Update Documentation

After adding a command:
- Update `docs/reference/cli.md` with syntax, flags, output examples, and exit codes
- Add any new terms to `docs/glossary.md`

---

## Related Documentation

- [CLI Reference](../reference/cli.md) — Existing command documentation
- [Exit Codes](../reference/exit-codes.md) — Exit code conventions
- [Code Standards](code-standards.md) — Dart style rules
