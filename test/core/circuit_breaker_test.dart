import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/provider_pool_state_service.dart';
import 'package:genaisys/core/services/autopilot/unattended_provider_blocklist_service.dart';

void main() {
  group('ProviderPoolStateService failure tracking', () {
    late Directory temp;
    late ProviderPoolStateService service;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('genaisys_circuit_breaker_');
      Directory(
        ProjectLayout(temp.path).genaisysDir,
      ).createSync(recursive: true);
      Directory(ProjectLayout(temp.path).auditDir).createSync(recursive: true);
      service = ProviderPoolStateService();
    });

    tearDown(() {
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('incrementFailure tracks consecutive failures per provider', () {
      var state = service.load(temp.path, candidateKeys: const ['codex@main']);

      state = service.incrementFailure(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      expect(service.failureCount(state, 'codex@main'), 1);

      state = service.incrementFailure(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      expect(service.failureCount(state, 'codex@main'), 2);
    });

    test('clearFailures resets both failure and quota hit counts', () {
      var state = service.load(temp.path, candidateKeys: const ['codex@main']);

      state = service.incrementFailure(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      state = service.incrementQuotaHit(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      expect(service.failureCount(state, 'codex@main'), 1);
      expect(service.quotaHitCount(state, 'codex@main'), 1);

      state = service.clearFailures(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      expect(service.failureCount(state, 'codex@main'), 0);
      expect(service.quotaHitCount(state, 'codex@main'), 0);
    });

    test('incrementQuotaHit tracks quota hits per provider', () {
      var state = service.load(
        temp.path,
        candidateKeys: const ['gemini@backup'],
      );

      state = service.incrementQuotaHit(
        temp.path,
        state: state,
        candidateKey: 'gemini@backup',
      );
      state = service.incrementQuotaHit(
        temp.path,
        state: state,
        candidateKey: 'gemini@backup',
      );
      state = service.incrementQuotaHit(
        temp.path,
        state: state,
        candidateKey: 'gemini@backup',
      );
      expect(service.quotaHitCount(state, 'gemini@backup'), 3);
    });

    test('failure counts survive persistence round-trip', () {
      var state = service.load(
        temp.path,
        candidateKeys: const ['codex@main', 'gemini@backup'],
      );

      state = service.incrementFailure(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      state = service.incrementFailure(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      state = service.incrementQuotaHit(
        temp.path,
        state: state,
        candidateKey: 'gemini@backup',
      );

      // Reload from disk.
      final reloaded = service.load(
        temp.path,
        candidateKeys: const ['codex@main', 'gemini@backup'],
      );
      expect(service.failureCount(reloaded, 'codex@main'), 2);
      expect(service.quotaHitCount(reloaded, 'gemini@backup'), 1);
    });

    test('failureCount returns 0 for unknown key', () {
      final state = service.load(
        temp.path,
        candidateKeys: const ['codex@main'],
      );
      expect(service.failureCount(state, 'unknown@key'), 0);
      expect(service.quotaHitCount(state, 'unknown@key'), 0);
    });

    test('clearFailures is a no-op when counts are already zero', () {
      var state = service.load(temp.path, candidateKeys: const ['codex@main']);

      final before = state;
      state = service.clearFailures(
        temp.path,
        state: state,
        candidateKey: 'codex@main',
      );
      expect(identical(state, before), isTrue);
    });
  });

  group('UnattendedProviderBlocklistService TTL', () {
    late Directory temp;
    late UnattendedProviderBlocklistService service;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('genaisys_blocklist_ttl_');
      Directory(
        ProjectLayout(temp.path).genaisysDir,
      ).createSync(recursive: true);
      Directory(ProjectLayout(temp.path).auditDir).createSync(recursive: true);
      service = UnattendedProviderBlocklistService();
    });

    tearDown(() {
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('blockProvider sets blocked_until with TTL', () {
      service.blockProvider(
        temp.path,
        provider: 'codex',
        reason: 'test',
        errorKind: 'agent_unavailable',
        ttl: const Duration(minutes: 15),
      );

      final entry = service.entryFor(temp.path, 'codex');
      expect(entry, isNotNull);
      expect(entry!['blocked_until'], isNotNull);

      final blockedUntil = DateTime.parse(entry['blocked_until'] as String);
      final now = DateTime.now().toUtc();
      // Should be roughly 15 minutes in the future.
      expect(
        blockedUntil.isAfter(now.add(const Duration(minutes: 14))),
        isTrue,
      );
    });

    test('blockedProviders excludes providers with expired TTL', () {
      // Write a blocklist entry with TTL in the past.
      final layout = ProjectLayout(temp.path);
      final expired = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final file = File(layout.unattendedProviderBlocklistPath);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'providers': {
            'codex': {
              'provider': 'codex',
              'blocked_at': expired
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
              'blocked_until': expired.toIso8601String(),
              'reason': 'test',
              'error_kind': 'agent_unavailable',
            },
          },
        }),
      );

      final blocked = service.blockedProviders(temp.path);
      expect(blocked, isEmpty);
    });

    test('blockedProviders includes providers with future TTL', () {
      service.blockProvider(
        temp.path,
        provider: 'codex',
        reason: 'test',
        errorKind: 'agent_unavailable',
        ttl: const Duration(hours: 1),
      );

      final blocked = service.blockedProviders(temp.path);
      expect(blocked, contains('codex'));
    });

    test('blockedProviders includes providers without blocked_until field', () {
      // Legacy entries without TTL should still be considered blocked.
      final layout = ProjectLayout(temp.path);
      final file = File(layout.unattendedProviderBlocklistPath);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'providers': {
            'codex': {
              'provider': 'codex',
              'blocked_at': DateTime.now().toUtc().toIso8601String(),
              'reason': 'legacy block',
              'error_kind': 'agent_unavailable',
            },
          },
        }),
      );

      final blocked = service.blockedProviders(temp.path);
      expect(blocked, contains('codex'));
    });

    test('default TTL is 30 minutes', () {
      expect(
        UnattendedProviderBlocklistService.defaultBlockTtl,
        const Duration(minutes: 30),
      );
    });
  });
}
