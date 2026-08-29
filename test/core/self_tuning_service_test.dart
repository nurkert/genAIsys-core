import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/services/config_service.dart';
import 'package:genaisys/core/services/self_tuning_service.dart';

import '../support/test_workspace.dart';

void main() {
  test('SelfTuningService applies adjustments when below target', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_tune_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure();

    final configService = ConfigService();
    configService.update(
      workspace.root.path,
      update: const ConfigUpdate(
        autopilotStepSleepSeconds: 2,
        autopilotIdleSleepSeconds: 30,
        autopilotMaxPlanAdd: 4,
        autopilotMaxTaskRetries: 3,
        autopilotSelfTuneWindow: 4,
        autopilotSelfTuneMinSamples: 4,
        autopilotSelfTuneSuccessPercent: 70,
      ),
    );

    final lines = [
      _event('orchestrator_run_step', data: {'idle': false}),
      _event('orchestrator_run_error'),
      _event('orchestrator_run_transient_error'),
      _event('orchestrator_run_permanent_error'),
    ];
    workspace.writeRunLog(lines);

    final service = SelfTuningService(configService: configService);
    final result = service.tune(workspace.root.path);

    expect(result.applied, isTrue);
    final updated = ProjectConfig.load(workspace.root.path);
    expect(updated.autopilotStepSleep.inSeconds, 4);
    expect(updated.autopilotIdleSleep.inSeconds, 40);
    expect(updated.autopilotMaxPlanAdd, 3);
    expect(updated.autopilotMaxTaskRetries, 4);
  });

  test('SelfTuningService skips when insufficient samples', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_tune_empty_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure();

    final configService = ConfigService();
    configService.update(
      workspace.root.path,
      update: const ConfigUpdate(
        autopilotSelfTuneWindow: 4,
        autopilotSelfTuneMinSamples: 4,
      ),
    );

    workspace.writeRunLog(const []);

    final service = SelfTuningService(configService: configService);
    final result = service.tune(workspace.root.path);

    expect(result.applied, isFalse);
    expect(result.reason, 'insufficient_samples');
  });

  test('SelfTuningService keeps max task retries at safe floor', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_tune_floor_');
    addTearDown(workspace.dispose);
    workspace.ensureStructure();

    final configService = ConfigService();
    configService.update(
      workspace.root.path,
      update: const ConfigUpdate(
        autopilotStepSleepSeconds: 2,
        autopilotIdleSleepSeconds: 30,
        autopilotMaxPlanAdd: 4,
        autopilotMaxTaskRetries: 4,
        autopilotSelfTuneWindow: 4,
        autopilotSelfTuneMinSamples: 4,
        autopilotSelfTuneSuccessPercent: 70,
      ),
    );

    final lines = [
      _event('orchestrator_run_step', data: {'idle': false}),
      _event('orchestrator_run_step', data: {'idle': false}),
      _event('orchestrator_run_step', data: {'idle': false}),
      _event('orchestrator_run_step', data: {'idle': false}),
    ];
    workspace.writeRunLog(lines);

    final service = SelfTuningService(configService: configService);
    final result = service.tune(workspace.root.path);

    expect(result.applied, isTrue);
    final updated = ProjectConfig.load(workspace.root.path);
    expect(updated.autopilotMaxTaskRetries, 3);
  });
}

String _event(String event, {Map<String, Object?>? data}) {
  final payload = <String, Object?>{
    'timestamp': '2025-01-01T00:00:00Z',
    'event': event,
  };
  if (data != null) {
    payload['data'] = data;
  }
  return jsonEncode(payload);
}
