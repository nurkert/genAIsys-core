// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/foundation.dart';

import '../../../core/app/app.dart';

/// Drives the settings surface from the config schema.
///
/// Every setting is applied the moment it is changed — there is no save step to
/// forget. A rejected value is rolled back to what is actually on disk and
/// surfaced as an inline error, so the UI never shows a value the engine did
/// not accept.
class ConfigSettingsController extends ChangeNotifier {
  ConfigSettingsController({
    required this.projectRoot,
    GetConfigSchemaUseCase? getSchema,
    SetConfigValuesUseCase? setValues,
    ResetConfigValuesUseCase? resetValues,
  }) : _getSchema = getSchema ?? GetConfigSchemaUseCase(),
       _setValues = setValues ?? SetConfigValuesUseCase(),
       _resetValues = resetValues ?? ResetConfigValuesUseCase();

  final String projectRoot;
  final GetConfigSchemaUseCase _getSchema;
  final SetConfigValuesUseCase _setValues;
  final ResetConfigValuesUseCase _resetValues;

  ConfigSchemaDto? _schema;
  bool _loading = false;
  String? _loadError;
  bool _configMissing = false;
  String _query = '';
  String? _selectedGroup;
  final Map<String, String> _fieldErrors = <String, String>{};
  final Set<String> _pendingKeys = <String>{};

  ConfigSchemaDto? get schema => _schema;
  bool get isLoading => _loading;
  String? get loadError => _loadError;

  /// True when the project simply has no `config.yml` yet, as opposed to a
  /// genuine failure. The two deserve different wording: one is a state the
  /// user can fix by initializing the project, the other is an error.
  bool get isConfigMissing => _configMissing;
  String get query => _query;

  /// Distinct top-level groups, in schema order.
  List<String> get groups {
    final schema = _schema;
    if (schema == null) {
      return const <String>[];
    }
    final seen = <String>{};
    final ordered = <String>[];
    for (final section in schema.sections) {
      if (seen.add(section.group)) {
        ordered.add(section.group);
      }
    }
    return ordered;
  }

  /// The group currently shown. Falls back to the first available group.
  String? get selectedGroup {
    final available = groups;
    if (available.isEmpty) {
      return null;
    }
    final selected = _selectedGroup;
    if (selected != null && available.contains(selected)) {
      return selected;
    }
    return available.first;
  }

  /// Total settings that differ from their default, across all groups.
  int get modifiedCount => _schema?.modifiedCount ?? 0;

  bool isPending(String qualifiedKey) => _pendingKeys.contains(qualifiedKey);

  String? errorFor(String qualifiedKey) => _fieldErrors[qualifiedKey];

  /// True while a search is narrowing the view. Search spans every group, so
  /// the group navigation is bypassed while it is active.
  bool get isSearching => _query.trim().isNotEmpty;

  /// Sections to render: the selected group, or search hits across all groups.
  List<ConfigSectionDto> get visibleSections {
    final schema = _schema;
    if (schema == null) {
      return const <ConfigSectionDto>[];
    }

    if (!isSearching) {
      final group = selectedGroup;
      return schema.sections.where((s) => s.group == group).toList();
    }

    final needle = _query.trim().toLowerCase();
    final matches = <ConfigSectionDto>[];
    for (final section in schema.sections) {
      final fields = section.fields
          .where((f) => _matches(f, section, needle))
          .toList();
      if (fields.isNotEmpty) {
        matches.add(
          ConfigSectionDto(
            path: section.path,
            group: section.group,
            label: section.label,
            fields: fields,
          ),
        );
      }
    }
    return matches;
  }

  /// Number of settings matching the current search, across all groups.
  int get searchResultCount =>
      visibleSections.fold(0, (sum, s) => sum + s.fields.length);

  bool _matches(ConfigFieldDto field, ConfigSectionDto section, String needle) {
    return field.label.toLowerCase().contains(needle) ||
        field.qualifiedKey.toLowerCase().contains(needle) ||
        section.label.toLowerCase().contains(needle) ||
        section.group.toLowerCase().contains(needle) ||
        (field.description?.toLowerCase().contains(needle) ?? false);
  }

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    _configMissing = false;
    notifyListeners();

    final result = await _getSchema.run(projectRoot);
    _loading = false;
    if (result.ok && result.data != null) {
      _schema = result.data;
      _loadError = null;
      _configMissing = false;
    } else {
      _configMissing = result.error?.kind == AppErrorKind.notFound;
      _loadError = result.error?.message ?? 'Could not load settings.';
    }
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    notifyListeners();
  }

  void selectGroup(String group) {
    if (_selectedGroup == group) {
      return;
    }
    _selectedGroup = group;
    _query = '';
    notifyListeners();
  }

  /// Applies one setting immediately.
  ///
  /// The row is marked pending while the write is in flight so the control
  /// cannot be driven into an inconsistent state, and the schema is reloaded
  /// afterwards so what is displayed is always what is on disk.
  Future<void> setValue(String qualifiedKey, Object? value) async {
    if (_pendingKeys.contains(qualifiedKey)) {
      return;
    }
    _pendingKeys.add(qualifiedKey);
    _fieldErrors.remove(qualifiedKey);
    notifyListeners();

    final result = await _setValues.run(
      projectRoot,
      values: <String, Object?>{qualifiedKey: value},
    );

    _pendingKeys.remove(qualifiedKey);
    if (!result.ok) {
      _fieldErrors[qualifiedKey] =
          result.error?.message ?? 'This value was rejected.';
      notifyListeners();
      return;
    }
    await _reloadPreservingView();
  }

  Future<void> resetField(String qualifiedKey) async {
    if (_pendingKeys.contains(qualifiedKey)) {
      return;
    }
    _pendingKeys.add(qualifiedKey);
    _fieldErrors.remove(qualifiedKey);
    notifyListeners();

    final result = await _resetValues.run(
      projectRoot,
      qualifiedKeys: <String>[qualifiedKey],
    );

    _pendingKeys.remove(qualifiedKey);
    if (!result.ok) {
      _fieldErrors[qualifiedKey] =
          result.error?.message ?? 'Could not restore the default.';
      notifyListeners();
      return;
    }
    await _reloadPreservingView();
  }

  /// Restores every modified setting in the currently visible sections.
  Future<void> resetVisible() async {
    final keys = visibleSections
        .expand((s) => s.fields)
        .where((f) => f.isModified)
        .map((f) => f.qualifiedKey)
        .toList();
    if (keys.isEmpty) {
      return;
    }

    _pendingKeys.addAll(keys);
    notifyListeners();

    final result = await _resetValues.run(projectRoot, qualifiedKeys: keys);

    _pendingKeys.removeAll(keys);
    if (!result.ok) {
      for (final key in keys) {
        _fieldErrors[key] =
            result.error?.message ?? 'Could not restore the default.';
      }
      notifyListeners();
      return;
    }
    await _reloadPreservingView();
  }

  Future<void> _reloadPreservingView() async {
    final result = await _getSchema.run(projectRoot);
    if (result.ok && result.data != null) {
      _schema = result.data;
    }
    notifyListeners();
  }
}
