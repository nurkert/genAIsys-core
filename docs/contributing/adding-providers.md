[Home](../README.md) > [Contributing](./README.md) > Adding Providers

# Adding Providers

How to implement a new AI provider adapter for Genaisys.

---

## AgentRunner Interface

Every provider implements the `AgentRunner` interface (`lib/core/agents/agent_runner.dart`):

```dart
abstract class AgentRunner {
  String get providerName;
  Future<AgentResponse> run(AgentRequest request);
}
```

## Steps

### 1. Create the Runner

Add a new file in `lib/core/agents/`:

```dart
class MyProviderRunner with AgentRunnerMixin implements AgentRunner {
  @override
  String get providerName => 'my-provider';

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final executable = 'my-provider-cli';
    final args = ['--prompt', '-', '--output-format', 'text'];

    return runWithIdleMonitoring(
      executable, args, request,
      runInShell: false,
    );
  }
}
```

### 2. Register in Agent Registry

Add to `lib/core/agents/agent_registry.dart`:

```dart
'my-provider': MyProviderRunner(),
```

### 3. Add Environment Requirements

Add to `lib/core/agents/agent_environment_requirements.dart`:

```dart
'my-provider': [], // or ['MY_PROVIDER_API_KEY'] if required
```

### 4. Support CLI Config Overrides

Use the `GENAISYS_MY_PROVIDER_CLI_CONFIG_OVERRIDES` environment variable pattern for custom flags.

### 5. Add Idle Monitoring

Use `AgentRunnerMixin.runWithIdleMonitoring()` to detect hung processes. The mixin handles timeout detection and process termination.

### 6. Sanitize Environment

Use `AgentRunnerMixin.sanitizeEnvironment()` to strip env vars that could cause conflicts (like `CLAUDECODE`).

## Testing

- Test that the runner starts and stops cleanly
- Test idle monitoring triggers on timeout
- Test environment sanitization
- Test config overrides are applied

---

## Related Documentation

- [Agent System](../concepts/agent-system.md) — How agents work
- [Providers Guide](../guide/providers.md) — User-facing provider setup
- [Configuration Reference](../reference/configuration-reference.md) — Provider config keys
