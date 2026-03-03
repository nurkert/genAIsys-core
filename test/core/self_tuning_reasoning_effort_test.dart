import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/self_tuning_service.dart';

void main() {
  late Directory temp;
  late ProjectLayout layout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_tune_re_');
    layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    // Enable self-tuning with minimal config.
    File(layout.configPath).writeAsStringSync('''
autopilot:
  self_tune_enabled: true
  self_tune_window: 10
  self_tune_min_samples: 3
  self_tune_success_percent: 70
''');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  /// Writes run-log events with failures first, then successes.
  ///
  /// Since [SelfTuningService._collectOutcomes] reads from the tail of the
  /// log and stops after `window` outcome events, placing failures first
  /// ensures the tail-window accurately reflects the intended ratio.
  void writeRunLogEvents(String logPath, int successes, int failures) {
    final buffer = StringBuffer();
    // Write failures first (older events).
    for (var i = 0; i < failures; i++) {
      buffer.writeln(
        jsonEncode({
          'event': 'orchestrator_run_error',
          'data': {'error_kind': 'test_failed'},
        }),
      );
    }
    // Write successes last (recent events, picked up first by tail-scan).
    for (var i = 0; i < successes; i++) {
      buffer.writeln(
        jsonEncode({
          'event': 'orchestrator_run_step',
          'data': {'idle': false},
        }),
      );
    }
    File(logPath).writeAsStringSync(buffer.toString());
  }

  group('Self-Tuning Reasoning Effort', () {
    test('high success rate lowers default effort from medium to low', () {
      // 95% success rate → should lower effort.
      writeRunLogEvents(layout.runLogPath, 19, 1);

      final service = SelfTuningService();
      service.tune(temp.path);

      final config = ProjectConfig.load(temp.path);
      expect(config.reasoningEffortByCategory['default'], 'low');
    });

    test('low success rate raises default effort from medium to high', () {
      // 30% success rate → should raise effort.
      writeRunLogEvents(layout.runLogPath, 3, 7);

      final service = SelfTuningService();
      service.tune(temp.path);

      final config = ProjectConfig.load(temp.path);
      expect(config.reasoningEffortByCategory['default'], 'high');
    });

    test('moderate success rate does not change effort', () {
      // 70% success rate → no change.
      writeRunLogEvents(layout.runLogPath, 7, 3);

      final service = SelfTuningService();
      service.tune(temp.path);

      final config = ProjectConfig.load(temp.path);
      expect(config.reasoningEffortByCategory['default'], 'medium');
    });

    test('effort does not go below low', () {
      // Set default to low already.
      File(layout.configPath).writeAsStringSync('''
autopilot:
  self_tune_enabled: true
  self_tune_window: 10
  self_tune_min_samples: 3
  self_tune_success_percent: 70
providers:
  reasoning_effort_by_category:
    default: low
''');
      // 95% success → would try to lower, but already at min.
      writeRunLogEvents(layout.runLogPath, 19, 1);

      final service = SelfTuningService();
      service.tune(temp.path);

      final config = ProjectConfig.load(temp.path);
      expect(config.reasoningEffortByCategory['default'], 'low');
    });

    test('effort does not go above high', () {
      // Set default to high already.
      File(layout.configPath).writeAsStringSync('''
autopilot:
  self_tune_enabled: true
  self_tune_window: 10
  self_tune_min_samples: 3
  self_tune_success_percent: 70
providers:
  reasoning_effort_by_category:
    default: high
''');
      // 30% success → would try to raise, but already at max.
      writeRunLogEvents(layout.runLogPath, 3, 7);

      final service = SelfTuningService();
      service.tune(temp.path);

      final config = ProjectConfig.load(temp.path);
      expect(config.reasoningEffortByCategory['default'], 'high');
    });

    test('logs self_tune_reasoning_effort event on change', () {
      // 95% success rate → lower effort, should log event.
      writeRunLogEvents(layout.runLogPath, 19, 1);

      final service = SelfTuningService();
      service.tune(temp.path);

      final content = File(layout.runLogPath).readAsStringSync();
      expect(content, contains('self_tune_reasoning_effort'));
    });
  });
}
