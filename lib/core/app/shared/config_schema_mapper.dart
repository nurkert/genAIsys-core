// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../config/config_field_descriptor.dart';
import '../dto/config_schema_dto.dart';

/// Turns the config field registry into a presentable schema.
///
/// Labels are derived from the YAML key rather than stored per field, so a new
/// config key is immediately readable in the UI without anyone writing display
/// text for it. A descriptor that carries an explicit `description` gets it
/// verbatim.
class ConfigSchemaMapper {
  const ConfigSchemaMapper();

  /// Words that must not be title-cased naively.
  static const Map<String, String> _acronyms = <String, String>{
    'ac': 'AC',
    'api': 'API',
    'cli': 'CLI',
    'cpu': 'CPU',
    'hitl': 'HITL',
    'id': 'ID',
    'json': 'JSON',
    'llm': 'LLM',
    'p1': 'P1',
    'p2': 'P2',
    'p3': 'P3',
    'pr': 'PR',
    'qg': 'QG',
    'ttl': 'TTL',
    'ui': 'UI',
    'url': 'URL',
    'yaml': 'YAML',
  };

  ConfigSchemaDto buildSchema({
    required List<ConfigFieldDescriptor> descriptors,
    required Map<String, Object?> values,
  }) {
    final bySection = <String, List<ConfigFieldDto>>{};
    final sectionOrder = <String>[];

    for (final descriptor in descriptors) {
      if (!bySection.containsKey(descriptor.section)) {
        bySection[descriptor.section] = <ConfigFieldDto>[];
        sectionOrder.add(descriptor.section);
      }
      bySection[descriptor.section]!.add(
        toFieldDto(descriptor, values[descriptor.qualifiedKey]),
      );
    }

    final sections = <ConfigSectionDto>[
      for (final path in sectionOrder)
        ConfigSectionDto(
          path: path,
          group: humanize(path.split('.').first),
          label: humanize(path.split('.').last),
          fields: List<ConfigFieldDto>.unmodifiable(bySection[path]!),
        ),
    ];

    return ConfigSchemaDto(
      sections: List<ConfigSectionDto>.unmodifiable(sections),
    );
  }

  ConfigFieldDto toFieldDto(ConfigFieldDescriptor descriptor, Object? value) {
    return ConfigFieldDto(
      qualifiedKey: descriptor.qualifiedKey,
      section: descriptor.section,
      yamlKey: descriptor.yamlKey,
      label: humanize(descriptor.yamlKey),
      description: descriptor.description,
      control: controlFor(descriptor),
      choices: descriptor.validValues == null
          ? null
          : List<String>.unmodifiable(descriptor.validValues!),
      minValue: descriptor.minValue,
      maxValue: descriptor.maxValue,
      nullable: descriptor.nullable,
      deprecated: descriptor.deprecated,
      durationUnit: descriptor.type == ConfigFieldType.duration
          ? descriptor.durationUnit.name
          : null,
      defaultValue: descriptor.defaultValue,
      value: value,
      isModified: value != descriptor.defaultValue,
    );
  }

  ConfigFieldControl controlFor(ConfigFieldDescriptor descriptor) {
    switch (descriptor.type) {
      case ConfigFieldType.bool_:
        return ConfigFieldControl.toggle;
      case ConfigFieldType.duration:
        return ConfigFieldControl.duration;
      case ConfigFieldType.int_:
      case ConfigFieldType.double_:
        return ConfigFieldControl.number;
      case ConfigFieldType.string_:
        return descriptor.validValues == null
            ? ConfigFieldControl.text
            : ConfigFieldControl.choice;
    }
  }

  /// `max_task_retries` → `Max task retries`, `hitl` → `HITL`.
  ///
  /// Only the first word is capitalised, matching how settings labels read in
  /// sentence case; acronyms keep their canonical casing wherever they appear.
  String humanize(String key) {
    final words = key.split(RegExp(r'[_\-\s]+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) {
      return key;
    }

    final rendered = <String>[];
    var first = true;
    for (final word in words) {
      final lower = word.toLowerCase();
      final acronym = _acronyms[lower];
      if (acronym != null) {
        rendered.add(acronym);
      } else if (first) {
        rendered.add(lower[0].toUpperCase() + lower.substring(1));
      } else {
        rendered.add(lower);
      }
      first = false;
    }
    return rendered.join(' ');
  }
}
