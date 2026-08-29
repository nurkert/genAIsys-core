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
  description: 'What this setting does, in one sentence.',
),
```

Field types: `int_`, `bool_`, `string_`, `double_`, `duration`

`description` is **required in practice**: it is the explanation shown under the setting in
the GUI, and `config_field_documentation_test.dart` fails without one.

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

Parsing, schema validation, defaults, **and the GUI** are fully automatic. The registry parity
test (`config_field_registry_test.dart`) catches any mismatch between the registry and
`ProjectConfig`.

### Why you do not touch the GUI

The settings surface is generated from this registry via `ConfigRegistryService` and
`getConfigSchema`. Your new key is immediately readable, validatable, searchable, and editable
in the desktop app — with the right control picked from its declared type — without adding a
DTO field, an update path, or a form widget.

This was not always true: `AppConfigDto` used to be a hand-maintained subset, and a key that
nobody plumbed through stayed invisible in the GUI. Do not add new keys to that DTO; it remains
only for the list-valued settings the scalar registry cannot express.

### Documentation parity

Add the key to [`configuration-reference.md`](../reference/configuration-reference.md) in the
same delivery. `config_field_documentation_test.dart` fails if a registered key is missing
there.

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
