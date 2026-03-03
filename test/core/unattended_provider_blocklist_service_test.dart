import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/unattended_provider_blocklist_service.dart';

void main() {
  test('UnattendedProviderBlocklistService persists blocked providers', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_provider_blocklist_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    final service = UnattendedProviderBlocklistService();

    final created = service.blockProvider(
      temp.path,
      provider: ' CoDeX ',
      reason: 'agent_command missing',
      errorKind: 'missing_event',
      blockedAt: '2026-02-06T00:00:00Z',
    );
    final duplicate = service.blockProvider(
      temp.path,
      provider: 'codex',
      reason: 'ignored duplicate',
      errorKind: 'missing_event',
    );

    expect(created, isTrue);
    expect(duplicate, isFalse);
    expect(service.isBlocked(temp.path, 'codex'), isTrue);
    expect(service.blockedProviders(temp.path), equals({'codex'}));

    final entry = service.entryFor(temp.path, 'codex');
    expect(entry, isNotNull);
    expect(entry!['provider'], 'codex');
    expect(entry['error_kind'], 'missing_event');
    expect(entry['blocked_at'], '2026-02-06T00:00:00Z');
  });

  test('UnattendedProviderBlocklistService can unblock providers', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_provider_unblock_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    final service = UnattendedProviderBlocklistService();

    final blocked = service.blockProvider(
      temp.path,
      provider: 'codex',
      reason: 'temporary',
      errorKind: 'agent_unavailable',
    );
    expect(blocked, isTrue);
    expect(service.isBlocked(temp.path, 'codex'), isTrue);

    final unblocked = service.unblockProvider(temp.path, provider: 'codex');
    expect(unblocked, isTrue);
    expect(service.isBlocked(temp.path, 'codex'), isFalse);
    expect(service.blockedProviders(temp.path), isEmpty);
  });

  test(
    'UnattendedProviderBlocklistService handles invalid file gracefully',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_provider_blocklist_invalid_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final layout = ProjectLayout(temp.path);
      Directory(layout.auditDir).createSync(recursive: true);
      File(
        layout.unattendedProviderBlocklistPath,
      ).writeAsStringSync('not json');

      final service = UnattendedProviderBlocklistService();
      expect(service.blockedProviders(temp.path), isEmpty);
      expect(service.isBlocked(temp.path, 'codex'), isFalse);
    },
  );
}
