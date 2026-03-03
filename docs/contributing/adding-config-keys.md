[Home](../README.md) > [Contributing](./README.md) > Adding Config Keys

# Adding Config Keys

The 3-step pattern for adding a new configuration key to Genaisys.

---

## Steps

### 1. Add a Field Descriptor

Add a `ConfigFieldDescriptor` entry to `lib/core/config/config_field_registry.dart`:

```dart
ConfigFieldDescriptor(
  section: 'autopilot',
  yamlKey: 'my_new_key',
  dartFieldName: 'myNewKey',
  type: ConfigFieldType.int_,
  defaultValue: 10,
  minValue: 1,
  maxValue: 100,
),
```

Field types: `int_`, `bool_`, `string_`, `double_`, `duration`

### 2. Add the Field to ProjectConfig

Add the matching `final` field and constructor parameter to the `ProjectConfig` class:

```dart
final int myNewKey;
```

### 3. (Optional) Add to Presets

If the key is preset-worthy, add it to the relevant presets in `lib/core/config/config_presets.dart`:

```dart
// In the 'overnight' preset:
'autopilot.my_new_key': 50,
```

## That's It

Parsing, schema validation, and defaults are fully automatic. The registry parity test (`config_field_registry_test.dart`) will catch any mismatch between the registry and `ProjectConfig`.

## Validation Constraints

| Constraint | Field | Description |
|-----------|-------|-------------|
| `minValue` | Numeric | Minimum allowed value |
| `maxValue` | Numeric | Maximum allowed value |
| `validValues` | String | Allowed string values (enum) |
| `nullable` | Any | Whether null is accepted |

---

## Related Documentation

- [Configuration Reference](../reference/configuration-reference.md) — All existing keys
- [Configuration Guide](../guide/configuration.md) — How config is used
- [Presets](../reference/presets.md) — Built-in presets
