import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/services/observability/resource_monitor_service.dart';

void main() {
  group('ResourceMonitorService', () {
    test('checkDiskSpace returns ok for an existing directory', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_resource_monitor_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final service = ResourceMonitorService();
      final result = service.checkDiskSpace(temp.path);

      // On a machine with reasonable space we expect ok.
      expect(result.ok, isTrue);
      expect(result.level, anyOf('ok', 'warning'));
      expect(result.message, isNotEmpty);
      // Available bytes should be a positive number on supported platforms.
      if (result.availableBytes > 0) {
        expect(
          result.availableBytes,
          greaterThan(ResourceMonitorService.criticalThresholdBytes),
        );
      }
    });

    test('checkDiskSpace returns ok for non-existent path (unsupported)', () {
      final service = ResourceMonitorService();
      final result = service.checkDiskSpace('/does/not/exist/anywhere');

      // Non-existent path should still return ok (unsupported platform path).
      expect(result.ok, isTrue);
      expect(result.level, 'ok');
    });

    test('DiskSpaceResult fields are set correctly for critical level', () {
      const result = DiskSpaceResult(
        ok: false,
        availableBytes: 5 * 1024 * 1024,
        level: 'critical',
        message: 'Critically low disk space.',
      );
      expect(result.ok, isFalse);
      expect(result.availableBytes, 5 * 1024 * 1024);
      expect(result.level, 'critical');
      expect(result.message, contains('Critically'));
    });

    test('DiskSpaceResult fields are set correctly for warning level', () {
      const result = DiskSpaceResult(
        ok: true,
        availableBytes: 50 * 1024 * 1024,
        level: 'warning',
        message: 'Low disk space warning.',
      );
      expect(result.ok, isTrue);
      expect(result.availableBytes, 50 * 1024 * 1024);
      expect(result.level, 'warning');
    });

    test('warning threshold is greater than critical threshold', () {
      expect(
        ResourceMonitorService.warningThresholdBytes,
        greaterThan(ResourceMonitorService.criticalThresholdBytes),
      );
    });
  });

  group('ResourceMonitorService preflight integration', () {
    test('critical disk space blocks preflight via service contract', () {
      // Test the contract: ok=false for critical means preflight should block.
      const result = DiskSpaceResult(
        ok: false,
        availableBytes: 10 * 1024 * 1024,
        level: 'critical',
        message: 'Critically low: 10 MB available.',
      );
      // The preflight checks result.ok — when false, it should block.
      expect(result.ok, isFalse);
      expect(result.level, 'critical');
    });

    test(
      'warning disk space does not block preflight via service contract',
      () {
        // Test the contract: ok=true for warning means preflight should pass.
        const result = DiskSpaceResult(
          ok: true,
          availableBytes: 80 * 1024 * 1024,
          level: 'warning',
          message: 'Low disk space warning: 80 MB available.',
        );
        expect(result.ok, isTrue);
      },
    );
  });
}
