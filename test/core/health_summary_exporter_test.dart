import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/services/observability/health_summary_exporter_service.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('genaisys_health_');
    projectRoot = tempDir.path;
    Directory(
      '$projectRoot${Platform.pathSeparator}.genaisys',
    ).createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('exports health.json with required fields', () {
    final exporter = HealthSummaryExporterService();
    final startedAt = DateTime.utc(2026, 1, 1, 12, 0, 0);

    exporter.export(
      projectRoot: projectRoot,
      sessionId: 'test-session-001',
      profile: 'overnight',
      pid: 42,
      startedAt: startedAt,
      totalSteps: 10,
      consecutiveFailures: 0,
      lastHaltReason: null,
      status: 'running',
    );

    final healthPath =
        '$projectRoot${Platform.pathSeparator}.genaisys${Platform.pathSeparator}health.json';
    final file = File(healthPath);
    expect(file.existsSync(), isTrue);

    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(decoded['status'], 'running');
    expect(decoded['session_id'], 'test-session-001');
    expect(decoded['profile'], 'overnight');
    expect(decoded['pid'], 42);
    expect(decoded['total_steps'], 10);
    expect(decoded['consecutive_failures'], 0);
    expect(decoded['health_grade'], isA<String>());
    expect(decoded['health_score'], isA<num>());
    expect(decoded['timestamp'], isA<String>());
    expect(decoded['uptime_seconds'], isA<int>());
    // null fields should be absent.
    expect(decoded.containsKey('last_halt_reason'), isFalse);
  });

  test('exports halted status with halt reason', () {
    final exporter = HealthSummaryExporterService();

    exporter.export(
      projectRoot: projectRoot,
      sessionId: 'test-session-002',
      profile: 'pilot',
      pid: 99,
      startedAt: DateTime.now().toUtc(),
      totalSteps: 5,
      consecutiveFailures: 3,
      lastHaltReason: 'restart_budget_exhausted',
      status: 'halted',
    );

    final healthPath =
        '$projectRoot${Platform.pathSeparator}.genaisys${Platform.pathSeparator}health.json';
    final decoded =
        jsonDecode(File(healthPath).readAsStringSync()) as Map<String, dynamic>;
    expect(decoded['status'], 'halted');
    expect(decoded['last_halt_reason'], 'restart_budget_exhausted');
    expect(decoded['consecutive_failures'], 3);
  });

  test('overwrites previous health.json atomically', () {
    final exporter = HealthSummaryExporterService();

    exporter.export(
      projectRoot: projectRoot,
      sessionId: 'first',
      status: 'running',
    );
    exporter.export(
      projectRoot: projectRoot,
      sessionId: 'second',
      status: 'halted',
    );

    final healthPath =
        '$projectRoot${Platform.pathSeparator}.genaisys${Platform.pathSeparator}health.json';
    final decoded =
        jsonDecode(File(healthPath).readAsStringSync()) as Map<String, dynamic>;
    expect(decoded['session_id'], 'second');
    expect(decoded['status'], 'halted');
  });
}
