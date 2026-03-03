// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../config/config_field_descriptor.dart';
import '../../config/config_field_registry.dart';
import '../../config/config_presets.dart';
import 'schema_validator_base.dart';

/// Validates the `.genaisys/config.yml` schema.
///
/// Scalar field validation (allowed keys, type checks, range constraints)
/// is driven from [configFieldRegistry]. Complex / list-based fields are
/// validated with hand-coded logic.
class ConfigSchemaValidator extends SchemaValidatorBase {
  static const _artifact = '.genaisys/config.yml';

  void validate(String path) {
    final payload = readRequiredFile(path, artifact: _artifact);
    final decoded = decodeYaml(payload, artifact: _artifact);
    final root = asObjectMap(decoded, artifact: _artifact, field: r'$');

    const rootKeys = {
      'preset',
      'project',
      'providers',
      'git',
      'agents',
      'policies',
      'workflow',
      'autopilot',
      'pipeline',
      'review',
      'reflection',
      'supervisor',
      'vision_evaluation',
    };
    assertOnlyAllowedKeys(
      root,
      allowed: rootKeys,
      artifact: _artifact,
      field: r'$',
    );

    _validatePreset(root, artifact: _artifact);
    _validateProjectSection(root, artifact: _artifact);
    _validateProvidersSection(root, artifact: _artifact);
    _validateAgentsSection(root, artifact: _artifact);
    _validatePoliciesSection(root, artifact: _artifact);

    // Simple flat sections — fully registry-driven.
    _validateFlatSection(root, section: 'git', artifact: _artifact);
    _validateFlatSection(
      root,
      section: 'workflow',
      artifact: _artifact,
      // Legacy keys accepted but not in the registry.
      extraAllowed: {'strictness', 'max_review_retries'},
      extraValidation: (map) {
        optionalString(
          map,
          key: 'strictness',
          artifact: _artifact,
          parent: 'workflow',
        );
        optionalInt(
          map,
          key: 'max_review_retries',
          artifact: _artifact,
          parent: 'workflow',
          minimum: 1,
        );
      },
    );
    _validateFlatSection(root, section: 'review', artifact: _artifact);
    _validateFlatSection(root, section: 'reflection', artifact: _artifact);
    _validateFlatSection(root, section: 'supervisor', artifact: _artifact);
    _validateFlatSection(root, section: 'vision_evaluation', artifact: _artifact);
    _validateFlatSection(root, section: 'pipeline', artifact: _artifact,
      // pipeline has a category-map subsection header that is not a simple key
      extraAllowed: {'context_injection_max_tokens_by_category'},
    );
    _validateAutopilotSection(root, artifact: _artifact);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Registry-driven helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Validates a flat (non-nested) section using the registry.
  ///
  /// [extraAllowed] adds additional accepted keys not in the registry
  /// (e.g. legacy keys, list/map sub-headers).
  /// [extraValidation] runs custom validation for non-registry keys.
  void _validateFlatSection(
    Map<String, Object?> root, {
    required String section,
    required String artifact,
    Set<String> extraAllowed = const {},
    void Function(Map<String, Object?>)? extraValidation,
  }) {
    final map = optionalMap(root, key: section, artifact: artifact);
    if (map == null) return;

    _validateMapFromRegistry(
      map,
      section: section,
      artifact: artifact,
      extraAllowed: extraAllowed,
    );
    extraValidation?.call(map);
  }

  /// Core: iterates registry fields for [section], validates allowed keys +
  /// type constraints.
  void _validateMapFromRegistry(
    Map<String, Object?> map, {
    required String section,
    required String artifact,
    Set<String> extraAllowed = const {},
  }) {
    final fields = registryFieldsForSection(section).toList();
    final allowed = {
      ...fields.map((f) => f.yamlKey),
      ...extraAllowed,
    };
    assertOnlyAllowedKeys(
      map,
      allowed: allowed,
      artifact: artifact,
      field: section,
    );

    for (final field in fields) {
      _validateField(map, field: field, artifact: artifact, parent: section);
    }
  }

  /// Dispatches to the appropriate type validator for a single field.
  void _validateField(
    Map<String, Object?> map, {
    required ConfigFieldDescriptor field,
    required String artifact,
    required String parent,
  }) {
    switch (field.type) {
      case ConfigFieldType.bool_:
        optionalBool(map, key: field.yamlKey, artifact: artifact, parent: parent);
      case ConfigFieldType.int_:
      case ConfigFieldType.duration:
        optionalInt(
          map,
          key: field.yamlKey,
          artifact: artifact,
          parent: parent,
          minimum: field.minValue?.toInt(),
          maximum: field.maxValue?.toInt(),
        );
      case ConfigFieldType.double_:
        _optionalDouble(
          map,
          key: field.yamlKey,
          artifact: artifact,
          parent: parent,
          minimum: field.minValue?.toDouble(),
          maximum: field.maxValue?.toDouble(),
        );
      case ConfigFieldType.string_:
        optionalString(
          map,
          key: field.yamlKey,
          artifact: artifact,
          parent: parent,
          allowed: field.validValues != null
              ? Set<String>.from(field.validValues!)
              : null,
        );
    }
  }

  /// Validates an optional double value (not in [SchemaValidatorBase]).
  void _optionalDouble(
    Map<String, Object?> data, {
    required String key,
    required String artifact,
    String? parent,
    double? minimum,
    double? maximum,
  }) {
    final value = data[key];
    if (value == null) return;
    final field = parent == null ? key : '$parent.$key';
    if (value is! num) {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: field,
        message: 'expected number but found ${value.runtimeType}.',
      );
    }
    final d = value.toDouble();
    if (minimum != null && d < minimum) {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: field,
        message: 'must be >= $minimum.',
      );
    }
    if (maximum != null && d > maximum) {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: field,
        message: 'must be <= $maximum.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Root-level keys
  // ─────────────────────────────────────────────────────────────────────────

  void _validatePreset(
    Map<String, Object?> root, {
    required String artifact,
  }) {
    final value = root['preset'];
    if (value == null) return;
    if (value is! String) {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: 'preset',
        message: 'expected string but found ${value.runtimeType}.',
      );
    }
    final name = value.trim().toLowerCase();
    if (!validPresetNames.contains(name)) {
      throw SchemaValidatorBase.schemaError(
        artifact: artifact,
        field: 'preset',
        message:
            'unknown preset "$name". '
            'Valid presets: ${validPresetNames.join(', ')}.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sections with special structure (not purely flat registry-driven)
  // ─────────────────────────────────────────────────────────────────────────

  void _validateProjectSection(
    Map<String, Object?> root, {
    required String artifact,
  }) {
    const keys = {'name', 'root', 'type', 'user_locale', 'internal_language'};
    final project = optionalMap(root, key: 'project', artifact: artifact);
    if (project == null) return;
    assertOnlyAllowedKeys(
      project,
      allowed: keys,
      artifact: artifact,
      field: 'project',
    );
    for (final k in keys) {
      optionalString(project, key: k, artifact: artifact, parent: 'project');
    }
  }

  void _validateProvidersSection(
    Map<String, Object?> root, {
    required String artifact,
  }) {
    const keys = {
      'primary',
      'fallback',
      'pool',
      'quota_cooldown_seconds',
      'quota_pause_seconds',
      'codex_cli_config_overrides',
      'claude_code_cli_config_overrides',
      'gemini_cli_config_overrides',
      'vibe_cli_config_overrides',
      'amp_cli_config_overrides',
      'reasoning_effort_by_category',
      'native',
    };
    final providers = optionalMap(root, key: 'providers', artifact: artifact);
    if (providers == null) return;
    assertOnlyAllowedKeys(
      providers,
      allowed: keys,
      artifact: artifact,
      field: 'providers',
    );

    // Registry-driven scalar keys.
    for (final field in registryFieldsForSection('providers')) {
      _validateField(
        providers,
        field: field,
        artifact: artifact,
        parent: 'providers',
      );
    }

    // Non-registry keys.
    optionalString(
      providers,
      key: 'primary',
      artifact: artifact,
      parent: 'providers',
    );
    optionalString(
      providers,
      key: 'fallback',
      artifact: artifact,
      parent: 'providers',
    );

    // CLI config override lists.
    for (final listKey in [
      'codex_cli_config_overrides',
      'claude_code_cli_config_overrides',
      'gemini_cli_config_overrides',
      'vibe_cli_config_overrides',
      'amp_cli_config_overrides',
    ]) {
      final value = providers[listKey];
      if (value != null) {
        final list = asList(
          value,
          artifact: artifact,
          field: 'providers.$listKey',
        );
        for (var i = 0; i < list.length; i += 1) {
          final item = list[i];
          if (item is! String || item.trim().isEmpty) {
            throw SchemaValidatorBase.schemaError(
              artifact: artifact,
              field: 'providers.$listKey[$i]',
              message: 'expected non-empty string.',
            );
          }
        }
      }
    }

    // Pool list.
    final pool = providers['pool'];
    if (pool != null) {
      final list = asList(pool, artifact: artifact, field: 'providers.pool');
      for (var i = 0; i < list.length; i += 1) {
        final value = list[i];
        if (value is! String || value.trim().isEmpty) {
          throw SchemaValidatorBase.schemaError(
            artifact: artifact,
            field: 'providers.pool[$i]',
            message: 'expected non-empty string.',
          );
        }
      }
    }
  }

  void _validateAgentsSection(
    Map<String, Object?> root, {
    required String artifact,
  }) {
    final agents = optionalMap(root, key: 'agents', artifact: artifact);
    if (agents == null) return;
    for (final entry in agents.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        throw SchemaValidatorBase.schemaError(
          artifact: artifact,
          field: 'agents',
          message: 'agent key must not be empty.',
        );
      }
      final profile = asObjectMap(
        entry.value,
        artifact: artifact,
        field: 'agents.$key',
      );
      assertOnlyAllowedKeys(
        profile,
        allowed: {'enabled', 'system_prompt'},
        artifact: artifact,
        field: 'agents.$key',
      );
      optionalBool(
        profile,
        key: 'enabled',
        artifact: artifact,
        parent: 'agents.$key',
      );
      optionalString(
        profile,
        key: 'system_prompt',
        artifact: artifact,
        parent: 'agents.$key',
      );
    }
  }

  void _validatePoliciesSection(
    Map<String, Object?> root, {
    required String artifact,
  }) {
    final policies = optionalMap(root, key: 'policies', artifact: artifact);
    if (policies == null) return;

    // Top-level policies keys = registry keys + subsection names + list keys.
    const subsectionKeys = {
      'safe_write',
      'quality_gate',
      'diff_budget',
      'timeouts',
    };
    const listKeys = {'shell_allowlist'};
    final registryKeys =
        registryFieldsForSection('policies').map((f) => f.yamlKey).toSet();
    assertOnlyAllowedKeys(
      policies,
      allowed: {...subsectionKeys, ...listKeys, ...registryKeys},
      artifact: artifact,
      field: 'policies',
    );

    // Registry-driven scalar keys at top level of policies.
    for (final field in registryFieldsForSection('policies')) {
      _validateField(
        policies,
        field: field,
        artifact: artifact,
        parent: 'policies',
      );
    }

    // Shell allowlist (list).
    final shellAllowlist = policies['shell_allowlist'];
    if (shellAllowlist != null) {
      requireStringList(
        shellAllowlist,
        artifact: artifact,
        field: 'policies.shell_allowlist',
      );
    }

    // Subsections with nested maps.
    _validatePoliciesSubsection(
      policies,
      subsection: 'safe_write',
      registrySection: 'policies.safe_write',
      artifact: artifact,
      extraAllowed: {'roots'},
      extraValidation: (map) {
        final roots = map['roots'];
        if (roots != null) {
          requireStringList(
            roots,
            artifact: artifact,
            field: 'policies.safe_write.roots',
          );
        }
      },
    );

    _validatePoliciesSubsection(
      policies,
      subsection: 'quality_gate',
      registrySection: 'policies.quality_gate',
      artifact: artifact,
      extraAllowed: {'commands'},
      extraValidation: (map) {
        final commands = map['commands'];
        if (commands != null) {
          requireStringList(
            commands,
            artifact: artifact,
            field: 'policies.quality_gate.commands',
          );
        }
      },
    );

    _validatePoliciesSubsection(
      policies,
      subsection: 'diff_budget',
      registrySection: 'policies.diff_budget',
      artifact: artifact,
    );

    _validatePoliciesSubsection(
      policies,
      subsection: 'timeouts',
      registrySection: 'policies.timeouts',
      artifact: artifact,
      extraAllowed: {'agent_seconds_by_category'},
    );
  }

  /// Validates a nested subsection under `policies:`.
  void _validatePoliciesSubsection(
    Map<String, Object?> policies, {
    required String subsection,
    required String registrySection,
    required String artifact,
    Set<String> extraAllowed = const {},
    void Function(Map<String, Object?>)? extraValidation,
  }) {
    final raw = policies[subsection];
    if (raw == null) return;
    final map = asObjectMap(
      raw,
      artifact: artifact,
      field: 'policies.$subsection',
    );

    _validateMapFromRegistry(
      map,
      section: registrySection,
      artifact: artifact,
      extraAllowed: extraAllowed,
    );
    extraValidation?.call(map);
  }

  void _validateAutopilotSection(
    Map<String, Object?> root, {
    required String artifact,
  }) {
    final autopilot = optionalMap(root, key: 'autopilot', artifact: artifact);
    if (autopilot == null) return;

    final fields = registryFieldsForSection('autopilot').toList();
    final allowed = fields.map((f) => f.yamlKey).toSet();
    assertOnlyAllowedKeys(
      autopilot,
      allowed: allowed,
      artifact: artifact,
      field: 'autopilot',
    );

    // Conditional planning_audit validation: when disabled, sub-params
    // bypass minimum checks so harmless values (0) don't block config.
    final planningAuditEnabled =
        autopilot['planning_audit_enabled'] as bool? ?? false;

    for (final field in fields) {
      // Skip conditional params when planning_audit is disabled.
      if (!planningAuditEnabled &&
          (field.yamlKey == 'planning_audit_cadence_steps' ||
           field.yamlKey == 'planning_audit_max_add')) {
        continue;
      }
      _validateField(
        autopilot,
        field: field,
        artifact: artifact,
        parent: 'autopilot',
      );
    }
  }
}
