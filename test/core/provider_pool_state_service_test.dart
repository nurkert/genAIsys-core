import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/provider_pool_state_service.dart';

void main() {
  test('ProviderPoolStateService persists quota and cursor state', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_provider_pool_state_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);

    final service = ProviderPoolStateService();
    var state = service.load(
      temp.path,
      candidateKeys: const ['codex@main', 'gemini@backup'],
    );

    state = service.setQuotaExhausted(
      temp.path,
      state: state,
      candidateKey: 'codex@main',
      exhaustedUntil: DateTime.now().toUtc().add(const Duration(seconds: 120)),
      reason: 'rate limit',
    );
    state = service.setCursor(
      temp.path,
      state: state,
      cursor: 3,
      candidateCount: 2,
    );

    final file = File(layout.providerPoolStatePath);
    expect(file.existsSync(), isTrue);

    final reloaded = service.load(
      temp.path,
      candidateKeys: const ['codex@main', 'gemini@backup'],
    );
    expect(reloaded.cursor, 1);
    expect(reloaded.quotaUntilFor('codex@main'), isNotNull);
    expect(reloaded.quotaUntilFor('gemini@backup'), isNull);
  });

  test('ProviderPoolStateService drops expired quota entries on load', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_provider_pool_expired_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    Directory(layout.auditDir).createSync(recursive: true);
    File(layout.providerPoolStatePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'cursor': 0,
        'entries': {
          'codex@main': {
            'key': 'codex@main',
            'quota_exhausted_until': '2000-01-01T00:00:00Z',
            'last_quota_error': 'old',
            'updated_at': '2000-01-01T00:00:00Z',
          },
        },
      }),
    );

    final service = ProviderPoolStateService();
    final state = service.load(
      temp.path,
      candidateKeys: const ['codex@main', 'gemini@backup'],
    );

    expect(state.quotaUntilFor('codex@main'), isNull);
  });
}
