// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../project_layout.dart';

class ProviderPoolStateEntry {
  const ProviderPoolStateEntry({
    required this.key,
    this.quotaExhaustedUntil,
    this.lastQuotaError,
    this.updatedAt,
    this.consecutiveFailures = 0,
    this.quotaHitCount = 0,
  });

  final String key;
  final DateTime? quotaExhaustedUntil;
  final String? lastQuotaError;
  final String? updatedAt;
  final int consecutiveFailures;
  final int quotaHitCount;

  ProviderPoolStateEntry copyWith({
    DateTime? quotaExhaustedUntil,
    bool clearQuotaExhaustedUntil = false,
    String? lastQuotaError,
    bool clearLastQuotaError = false,
    String? updatedAt,
    int? consecutiveFailures,
    int? quotaHitCount,
  }) {
    return ProviderPoolStateEntry(
      key: key,
      quotaExhaustedUntil: clearQuotaExhaustedUntil
          ? null
          : (quotaExhaustedUntil ?? this.quotaExhaustedUntil),
      lastQuotaError: clearLastQuotaError
          ? null
          : (lastQuotaError ?? this.lastQuotaError),
      updatedAt: updatedAt ?? this.updatedAt,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      quotaHitCount: quotaHitCount ?? this.quotaHitCount,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'key': key,
      'quota_exhausted_until': quotaExhaustedUntil?.toUtc().toIso8601String(),
      'last_quota_error': lastQuotaError,
      'updated_at': updatedAt,
      'consecutive_failures': consecutiveFailures,
      'quota_hit_count': quotaHitCount,
    };
  }
}

class ProviderPoolStateSnapshot {
  const ProviderPoolStateSnapshot({
    required this.cursor,
    required this.entries,
  });

  final int cursor;
  final Map<String, ProviderPoolStateEntry> entries;

  DateTime? quotaUntilFor(String key) {
    final normalized = _normalizePoolKey(key);
    if (normalized.isEmpty) {
      return null;
    }
    return entries[normalized]?.quotaExhaustedUntil;
  }

  ProviderPoolStateSnapshot copyWith({
    int? cursor,
    Map<String, ProviderPoolStateEntry>? entries,
  }) {
    return ProviderPoolStateSnapshot(
      cursor: cursor ?? this.cursor,
      entries: entries ?? this.entries,
    );
  }
}

class ProviderPoolStateService {
  ProviderPoolStateSnapshot load(
    String projectRoot, {
    required List<String> candidateKeys,
    DateTime? now,
  }) {
    final normalizedCandidates = _normalizeCandidates(candidateKeys);
    final currentNow = now?.toUtc() ?? DateTime.now().toUtc();
    final file = File(ProjectLayout(projectRoot).providerPoolStatePath);
    if (!file.existsSync()) {
      return _emptyForCandidates(normalizedCandidates);
    }

    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return _emptyForCandidates(normalizedCandidates);
      }
      final rawCursor = _parseInt(decoded['cursor']) ?? 0;
      final rawEntries = decoded['entries'];
      final entries = <String, ProviderPoolStateEntry>{};
      if (rawEntries is Map) {
        for (final entry in rawEntries.entries) {
          final key = _normalizeKey(entry.key.toString());
          if (key.isEmpty || !normalizedCandidates.contains(key)) {
            continue;
          }
          if (entry.value is! Map) {
            continue;
          }
          final map = Map<String, Object?>.from(entry.value as Map);
          var quotaUntil = _parseDateTime(map['quota_exhausted_until']);
          if (quotaUntil != null && !quotaUntil.isAfter(currentNow)) {
            quotaUntil = null;
          }
          final lastQuotaError = _toStringOrNull(map['last_quota_error']);
          final updatedAt = _toStringOrNull(map['updated_at']);
          final consecutiveFailures =
              _parseInt(map['consecutive_failures']) ?? 0;
          final quotaHitCount = _parseInt(map['quota_hit_count']) ?? 0;
          if (quotaUntil == null &&
              (lastQuotaError == null || lastQuotaError.isEmpty) &&
              consecutiveFailures <= 0 &&
              quotaHitCount <= 0) {
            continue;
          }
          entries[key] = ProviderPoolStateEntry(
            key: key,
            quotaExhaustedUntil: quotaUntil,
            lastQuotaError: lastQuotaError,
            updatedAt: updatedAt,
            consecutiveFailures: consecutiveFailures < 0
                ? 0
                : consecutiveFailures,
            quotaHitCount: quotaHitCount < 0 ? 0 : quotaHitCount,
          );
        }
      }

      final normalizedCursor = _normalizeCursor(
        rawCursor,
        normalizedCandidates.length,
      );
      return ProviderPoolStateSnapshot(
        cursor: normalizedCursor,
        entries: Map<String, ProviderPoolStateEntry>.unmodifiable(entries),
      );
    } catch (_) {
      return _emptyForCandidates(normalizedCandidates);
    }
  }

  ProviderPoolStateSnapshot setQuotaExhausted(
    String projectRoot, {
    required ProviderPoolStateSnapshot state,
    required String candidateKey,
    required DateTime exhaustedUntil,
    String? reason,
  }) {
    final key = _normalizeKey(candidateKey);
    if (key.isEmpty) {
      return state;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final current = state.entries[key] ?? ProviderPoolStateEntry(key: key);
    final nextEntries = <String, ProviderPoolStateEntry>{...state.entries};
    nextEntries[key] = current.copyWith(
      quotaExhaustedUntil: exhaustedUntil.toUtc(),
      lastQuotaError: reason,
      clearLastQuotaError: reason == null || reason.trim().isEmpty,
      updatedAt: now,
    );
    final next = state.copyWith(
      entries: Map<String, ProviderPoolStateEntry>.unmodifiable(nextEntries),
    );
    write(projectRoot, next);
    return next;
  }

  ProviderPoolStateSnapshot clearQuota(
    String projectRoot, {
    required ProviderPoolStateSnapshot state,
    required String candidateKey,
  }) {
    final key = _normalizeKey(candidateKey);
    if (key.isEmpty) {
      return state;
    }
    final current = state.entries[key];
    if (current == null) {
      return state;
    }
    final nextEntries = <String, ProviderPoolStateEntry>{...state.entries};
    nextEntries[key] = current.copyWith(
      clearQuotaExhaustedUntil: true,
      clearLastQuotaError: true,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final next = state.copyWith(
      entries: Map<String, ProviderPoolStateEntry>.unmodifiable(nextEntries),
    );
    write(projectRoot, next);
    return next;
  }

  ProviderPoolStateSnapshot incrementFailure(
    String projectRoot, {
    required ProviderPoolStateSnapshot state,
    required String candidateKey,
  }) {
    final key = _normalizeKey(candidateKey);
    if (key.isEmpty) {
      return state;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final current = state.entries[key] ?? ProviderPoolStateEntry(key: key);
    final nextEntries = <String, ProviderPoolStateEntry>{...state.entries};
    nextEntries[key] = current.copyWith(
      consecutiveFailures: current.consecutiveFailures + 1,
      updatedAt: now,
    );
    final next = state.copyWith(
      entries: Map<String, ProviderPoolStateEntry>.unmodifiable(nextEntries),
    );
    write(projectRoot, next);
    return next;
  }

  ProviderPoolStateSnapshot incrementQuotaHit(
    String projectRoot, {
    required ProviderPoolStateSnapshot state,
    required String candidateKey,
  }) {
    final key = _normalizeKey(candidateKey);
    if (key.isEmpty) {
      return state;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final current = state.entries[key] ?? ProviderPoolStateEntry(key: key);
    final nextEntries = <String, ProviderPoolStateEntry>{...state.entries};
    nextEntries[key] = current.copyWith(
      quotaHitCount: current.quotaHitCount + 1,
      updatedAt: now,
    );
    final next = state.copyWith(
      entries: Map<String, ProviderPoolStateEntry>.unmodifiable(nextEntries),
    );
    write(projectRoot, next);
    return next;
  }

  ProviderPoolStateSnapshot clearFailures(
    String projectRoot, {
    required ProviderPoolStateSnapshot state,
    required String candidateKey,
  }) {
    final key = _normalizeKey(candidateKey);
    if (key.isEmpty) {
      return state;
    }
    final current = state.entries[key];
    if (current == null ||
        (current.consecutiveFailures <= 0 && current.quotaHitCount <= 0)) {
      return state;
    }
    final nextEntries = <String, ProviderPoolStateEntry>{...state.entries};
    nextEntries[key] = current.copyWith(
      consecutiveFailures: 0,
      quotaHitCount: 0,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final next = state.copyWith(
      entries: Map<String, ProviderPoolStateEntry>.unmodifiable(nextEntries),
    );
    write(projectRoot, next);
    return next;
  }

  int failureCount(ProviderPoolStateSnapshot state, String candidateKey) {
    final key = _normalizeKey(candidateKey);
    if (key.isEmpty) {
      return 0;
    }
    return state.entries[key]?.consecutiveFailures ?? 0;
  }

  int quotaHitCount(ProviderPoolStateSnapshot state, String candidateKey) {
    final key = _normalizeKey(candidateKey);
    if (key.isEmpty) {
      return 0;
    }
    return state.entries[key]?.quotaHitCount ?? 0;
  }

  ProviderPoolStateSnapshot setCursor(
    String projectRoot, {
    required ProviderPoolStateSnapshot state,
    required int cursor,
    required int candidateCount,
  }) {
    final normalized = _normalizeCursor(cursor, candidateCount);
    final next = state.copyWith(cursor: normalized);
    write(projectRoot, next);
    return next;
  }

  void write(String projectRoot, ProviderPoolStateSnapshot state) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }
    try {
      final normalizedEntries = <String, Map<String, Object?>>{};
      for (final entry in state.entries.entries) {
        final key = _normalizeKey(entry.key);
        if (key.isEmpty) {
          continue;
        }
        final value = entry.value;
        final quota = value.quotaExhaustedUntil;
        final error = value.lastQuotaError?.trim();
        if ((quota == null || !quota.isAfter(DateTime.now().toUtc())) &&
            (error == null || error.isEmpty) &&
            value.consecutiveFailures <= 0 &&
            value.quotaHitCount <= 0) {
          continue;
        }
        normalizedEntries[key] = value.toJson();
      }

      Directory(layout.auditDir).createSync(recursive: true);
      final file = File(layout.providerPoolStatePath);
      final payload = <String, Object?>{
        'version': 1,
        'cursor': state.cursor,
        'entries': normalizedEntries,
      };
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
    } catch (e) {
      try {
        stderr.writeln(
          '[ProviderPoolStateService] write failed '
          '(error_class=state, error_kind=pool_state_write): $e',
        );
      } catch (_) {}
    }
  }

  ProviderPoolStateSnapshot _emptyForCandidates(List<String> candidateKeys) {
    return ProviderPoolStateSnapshot(
      cursor: _normalizeCursor(0, candidateKeys.length),
      entries: const <String, ProviderPoolStateEntry>{},
    );
  }

  List<String> _normalizeCandidates(List<String> candidateKeys) {
    final output = <String>[];
    final seen = <String>{};
    for (final raw in candidateKeys) {
      final key = _normalizeKey(raw);
      if (key.isEmpty) {
        continue;
      }
      if (seen.add(key)) {
        output.add(key);
      }
    }
    return output;
  }

  int _normalizeCursor(int cursor, int candidateCount) {
    if (candidateCount < 1) {
      return 0;
    }
    if (cursor < 0) {
      return 0;
    }
    return cursor % candidateCount;
  }

  int? _parseInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  DateTime? _parseDateTime(Object? value) {
    final text = _toStringOrNull(value);
    if (text == null) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }

  String? _toStringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  String _normalizeKey(String value) {
    return _normalizePoolKey(value);
  }
}

String _normalizePoolKey(String value) {
  return value.trim().toLowerCase();
}
