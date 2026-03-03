// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../../project_layout.dart';

class UnattendedProviderBlocklistService {
  /// Default TTL for blocked providers (30 minutes). After this period, the
  /// provider is automatically eligible for recovery without manual intervention.
  static const Duration defaultBlockTtl = Duration(minutes: 30);

  Map<String, Map<String, Object?>> entries(String projectRoot) {
    final file = File(
      ProjectLayout(projectRoot).unattendedProviderBlocklistPath,
    );
    if (!file.existsSync()) {
      return {};
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return {};
      }
      final rawProviders = decoded['providers'];
      if (rawProviders is! Map) {
        return {};
      }
      final output = <String, Map<String, Object?>>{};
      for (final entry in rawProviders.entries) {
        final key = _normalizeProvider(entry.key.toString());
        if (key.isEmpty || entry.value is! Map) {
          continue;
        }
        output[key] = Map<String, Object?>.from(entry.value as Map);
      }
      return output;
    } catch (_) {
      return {};
    }
  }

  Set<String> blockedProviders(String projectRoot) {
    final all = entries(projectRoot);
    final now = DateTime.now().toUtc();
    final active = <String>{};
    for (final entry in all.entries) {
      final blockedUntilRaw = entry.value['blocked_until']?.toString();
      if (blockedUntilRaw != null && blockedUntilRaw.isNotEmpty) {
        final blockedUntil = DateTime.tryParse(blockedUntilRaw)?.toUtc();
        if (blockedUntil != null && !blockedUntil.isAfter(now)) {
          // TTL expired; auto-unblock on next access.
          continue;
        }
      }
      active.add(entry.key);
    }
    return active;
  }

  bool isBlocked(String projectRoot, String provider) {
    final key = _normalizeProvider(provider);
    if (key.isEmpty) {
      return false;
    }
    return blockedProviders(projectRoot).contains(key);
  }

  bool blockProvider(
    String projectRoot, {
    required String provider,
    required String reason,
    required String errorKind,
    String? blockedAt,
    Duration? ttl,
  }) {
    final key = _normalizeProvider(provider);
    if (key.isEmpty) {
      return false;
    }
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return false;
    }

    final current = entries(projectRoot);
    if (current.containsKey(key)) {
      return false;
    }

    final now = DateTime.now().toUtc();
    final effectiveTtl = ttl ?? defaultBlockTtl;
    current[key] = {
      'provider': key,
      'blocked_at': blockedAt ?? now.toIso8601String(),
      'blocked_until': now.add(effectiveTtl).toIso8601String(),
      'reason': reason,
      'error_kind': errorKind,
    };
    return _write(layout, current);
  }

  bool unblockProvider(String projectRoot, {required String provider}) {
    final key = _normalizeProvider(provider);
    if (key.isEmpty) {
      return false;
    }
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return false;
    }
    final current = entries(projectRoot);
    if (!current.containsKey(key)) {
      return false;
    }
    current.remove(key);
    return _write(layout, current);
  }

  Map<String, Object?>? entryFor(String projectRoot, String provider) {
    final key = _normalizeProvider(provider);
    if (key.isEmpty) {
      return null;
    }
    return entries(projectRoot)[key];
  }

  bool _write(
    ProjectLayout layout,
    Map<String, Map<String, Object?>> providers,
  ) {
    try {
      Directory(layout.auditDir).createSync(recursive: true);
      final file = File(layout.unattendedProviderBlocklistPath);
      final payload = <String, Object?>{'version': 1, 'providers': providers};
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      return true;
    } catch (e) {
      try {
        stderr.writeln(
          '[UnattendedProviderBlocklistService] _write failed '
          '(error_class=state, error_kind=blocklist_write): $e',
        );
      } catch (_) {}
      return false;
    }
  }

  String _normalizeProvider(String value) {
    return value.trim().toLowerCase();
  }
}
