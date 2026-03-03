import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/error_pattern_registry_service.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_errpat_');
    layout = ProjectLayout(temp.path);
    Directory(layout.auditDir).createSync(recursive: true);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  group('ErrorPatternRegistryService', () {
    test('load returns empty list when no registry exists', () {
      final service = ErrorPatternRegistryService();
      final entries = service.load(temp.path);
      expect(entries, isEmpty);
    });

    test('save and load round-trip preserves entries', () {
      final service = ErrorPatternRegistryService();
      final entries = [
        ErrorPatternEntry(
          errorKind: 'test_failed',
          count: 3,
          lastSeen: '2026-01-01T00:00:00Z',
          resolutionStrategy: 'Fix assertions',
          autoResolvedCount: 1,
        ),
      ];
      service.save(temp.path, entries);

      final loaded = service.load(temp.path);
      expect(loaded.length, 1);
      expect(loaded[0].errorKind, 'test_failed');
      expect(loaded[0].count, 3);
      expect(loaded[0].resolutionStrategy, 'Fix assertions');
      expect(loaded[0].autoResolvedCount, 1);
    });

    test('mergeObservations creates new entries', () {
      final service = ErrorPatternRegistryService();
      service.mergeObservations(
        temp.path,
        errorKindCounts: {'no_diff': 2, 'timeout': 1},
      );

      final loaded = service.load(temp.path);
      expect(loaded.length, 2);
      final noDiff = loaded.firstWhere((e) => e.errorKind == 'no_diff');
      expect(noDiff.count, 2);
      final timeout = loaded.firstWhere((e) => e.errorKind == 'timeout');
      expect(timeout.count, 1);
    });

    test('mergeObservations increments existing entry counts', () {
      final service = ErrorPatternRegistryService();
      service.mergeObservations(temp.path, errorKindCounts: {'no_diff': 2});
      service.mergeObservations(temp.path, errorKindCounts: {'no_diff': 3});

      final loaded = service.load(temp.path);
      expect(loaded.length, 1);
      expect(loaded[0].count, 5);
    });

    test('recordAutoResolution increments auto_resolved_count', () {
      final service = ErrorPatternRegistryService();
      service.mergeObservations(temp.path, errorKindCounts: {'test_failed': 1});
      service.recordAutoResolution(temp.path, 'test_failed');

      final loaded = service.load(temp.path);
      expect(loaded[0].autoResolvedCount, 1);
    });

    test('recordResolutionStrategy sets strategy', () {
      final service = ErrorPatternRegistryService();
      service.mergeObservations(temp.path, errorKindCounts: {'timeout': 1});
      service.recordResolutionStrategy(
        temp.path,
        'timeout',
        'Reduce scope of task',
      );

      final loaded = service.load(temp.path);
      expect(loaded[0].resolutionStrategy, 'Reduce scope of task');
    });

    test(
      'unresolvablePatterns returns entries above threshold without strategy',
      () {
        final service = ErrorPatternRegistryService();
        final entries = [
          ErrorPatternEntry(
            errorKind: 'no_diff',
            count: 6,
            lastSeen: '2026-01-01T00:00:00Z',
          ),
          ErrorPatternEntry(
            errorKind: 'timeout',
            count: 6,
            lastSeen: '2026-01-01T00:00:00Z',
            resolutionStrategy: 'Reduce scope',
          ),
          ErrorPatternEntry(
            errorKind: 'test_failed',
            count: 2,
            lastSeen: '2026-01-01T00:00:00Z',
          ),
        ];
        service.save(temp.path, entries);

        final unresolvable = service.unresolvablePatterns(temp.path);
        expect(unresolvable.length, 1);
        expect(unresolvable[0].errorKind, 'no_diff');
      },
    );

    test('knownResolutionFor returns strategy when available', () {
      final service = ErrorPatternRegistryService();
      final entries = [
        ErrorPatternEntry(
          errorKind: 'timeout',
          count: 3,
          lastSeen: '2026-01-01T00:00:00Z',
          resolutionStrategy: 'Reduce scope of task',
        ),
      ];
      service.save(temp.path, entries);

      expect(
        service.knownResolutionFor(temp.path, 'timeout'),
        'Reduce scope of task',
      );
      expect(service.knownResolutionFor(temp.path, 'unknown'), isNull);
    });

    test('load handles corrupted JSON gracefully', () {
      final service = ErrorPatternRegistryService();
      File(layout.errorPatternRegistryPath).writeAsStringSync('not json');

      final entries = service.load(temp.path);
      expect(entries, isEmpty);
    });
  });
}
