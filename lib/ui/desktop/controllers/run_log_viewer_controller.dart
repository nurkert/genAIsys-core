// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/app/app.dart';

enum RunLogFilter { all, errors }

/// View-model for the Reports -> Run Log workspace.
///
/// Keeps file I/O inside core use-cases while providing a UI-friendly API for
/// paging, filtering, and search.
class RunLogViewerController extends ChangeNotifier {
  RunLogViewerController({
    required String projectRootPath,
    ReadRunLogPageUseCase? readUseCase,
    this.pageSize = 240,
  }) : _projectRootPath = projectRootPath.trim(),
       _readUseCase = readUseCase ?? ReadRunLogPageUseCase();

  final String _projectRootPath;
  final ReadRunLogPageUseCase _readUseCase;
  final int pageSize;

  bool _loading = false;
  bool _loadingMore = false;
  String? _errorMessage;

  int? _cursor;
  List<AppRunLogEventDto> _events = const <AppRunLogEventDto>[];
  List<AppRunLogEventDto> _visible = const <AppRunLogEventDto>[];

  String _query = '';
  RunLogFilter _filter = RunLogFilter.all;

  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  String? get errorMessage => _errorMessage;
  bool get hasOlder => _cursor != null;
  List<AppRunLogEventDto> get events => _visible;
  String get query => _query;
  RunLogFilter get filter => _filter;
  int get policyViolationCount =>
      _events.where(RunLogViewerController.isPolicyViolationEvent).length;

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_loading) {
      return;
    }
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _readUseCase.run(_projectRootPath, limit: pageSize);
    if (!result.ok || result.data == null) {
      _loading = false;
      _errorMessage = result.error?.message ?? 'Failed to read run log.';
      notifyListeners();
      return;
    }

    _events = List<AppRunLogEventDto>.unmodifiable(result.data!.events);
    _cursor = result.data!.nextBeforeOffset;
    _recomputeVisible();
    _loading = false;
    notifyListeners();
  }

  Future<void> loadOlder() async {
    final cursor = _cursor;
    if (_loadingMore || cursor == null) {
      return;
    }

    _loadingMore = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _readUseCase.run(
      _projectRootPath,
      limit: pageSize,
      beforeOffset: cursor,
    );

    if (!result.ok || result.data == null) {
      _loadingMore = false;
      _errorMessage = result.error?.message ?? 'Failed to read older logs.';
      notifyListeners();
      return;
    }

    _events = List<AppRunLogEventDto>.unmodifiable(<AppRunLogEventDto>[
      ..._events,
      ...result.data!.events,
    ]);
    _cursor = result.data!.nextBeforeOffset;
    _recomputeVisible();
    _loadingMore = false;
    notifyListeners();
  }

  void setQuery(String value) {
    final normalized = value.trim();
    if (_query == normalized) {
      return;
    }
    _query = normalized;
    _recomputeVisible();
    notifyListeners();
  }

  void setFilter(RunLogFilter filter) {
    if (_filter == filter) {
      return;
    }
    _filter = filter;
    _recomputeVisible();
    notifyListeners();
  }

  void _recomputeVisible() {
    final String q = _query.toLowerCase();
    _visible = List<AppRunLogEventDto>.unmodifiable(
      _events.where((AppRunLogEventDto entry) {
        if (_filter == RunLogFilter.errors && !_isErrorEvent(entry)) {
          return false;
        }
        if (q.isEmpty) {
          return true;
        }
        return _searchText(entry).contains(q);
      }),
    );
  }

  static bool isPolicyViolationEvent(AppRunLogEventDto entry) {
    final String event = entry.event.trim().toLowerCase();
    final String message = (entry.message ?? '').trim().toLowerCase();
    final Map<String, Object?> data = entry.data ?? const <String, Object?>{};
    final String errorClass = (data['error_class']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final String errorKind = (data['error_kind']?.toString() ?? '')
        .trim()
        .toLowerCase();

    final bool explicitPolicyFlag = _toBool(data['policy_violation']);
    if (explicitPolicyFlag) {
      return true;
    }
    if (errorClass == 'policy') {
      return true;
    }
    if (_policyErrorKinds.contains(errorKind)) {
      return true;
    }
    if (_policyEventTokens.any(event.contains)) {
      return true;
    }
    if (message.contains('policy violation')) {
      return true;
    }
    return false;
  }

  static bool _toBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value == null) {
      return false;
    }
    final String normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static const Set<String> _policyErrorKinds = <String>{
    'policy_violation',
    'safe_write',
    'safe_write_scope',
    'shell_allowlist',
    'allowlist',
    'diff_budget',
    'spec_required_files_missing',
    'unattended_not_released',
  };

  static const Set<String> _policyEventTokens = <String>{
    'policy',
    'allowlist',
    'safe_write',
    'quality_gate_blocked',
  };

  bool _isErrorEvent(AppRunLogEventDto entry) {
    final String event = entry.event.toLowerCase();
    return event.contains('error') ||
        event.contains('reject') ||
        event.contains('safety_halt') ||
        event == 'preflight_failed' ||
        event.contains('stuck') ||
        event.contains('timeout');
  }

  String _searchText(AppRunLogEventDto entry) {
    final parts = <String>[
      entry.timestamp ?? '',
      entry.event,
      entry.message ?? '',
      _stringOrEmpty(entry.data?['step_id']),
      _stringOrEmpty(entry.data?['task_id']),
      _stringOrEmpty(entry.data?['subtask_id']),
      _stringOrEmpty(entry.data?['error_class']),
      _stringOrEmpty(entry.data?['error_kind']),
      _stringOrEmpty(entry.data?['decision']),
      _stringOrEmpty(entry.data?['review_decision']),
      _stringOrEmpty(entry.data?['command']),
    ].where((String value) => value.trim().isNotEmpty).toList(growable: false);

    return parts.join(' ').toLowerCase();
  }

  String _stringOrEmpty(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  static String prettyJson(Object? value) {
    if (value == null) {
      return '';
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
