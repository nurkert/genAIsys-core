import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/services/autopilot/stabilization_exit_gate_service.dart';

void main() {
  test(
    'StabilizationExitGateService keeps feature freeze active when open P1 remains and post-stabilization waves are blocked',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_exit_gate_active_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final tasksPath = '${temp.path}${Platform.pathSeparator}TASKS.md';
      File(tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Close remaining stabilization gap

### Post-Stabilization Feature Wave 1: Native Agent Runtime (Internal)
- [ ] [BLOCKED] [P2] [ARCH] Define native runtime contracts
''');

      final result = StabilizationExitGateService().evaluate(tasksPath);
      expect(result.ok, isTrue);
      expect(result.featureFreezeLifted, isFalse);
      expect(result.openP1Count, 1);
      expect(result.openPostStabilizationUnblockedCount, 0);
      expect(result.errorKind, isNull);
    },
  );

  test(
    'StabilizationExitGateService fails when post-stabilization wave is unblocked before open P1 reaches zero',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_exit_gate_violation_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final tasksPath = '${temp.path}${Platform.pathSeparator}TASKS.md';
      File(tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Close remaining stabilization gap

### Post-Stabilization Feature Wave 2: Self-Upgrade and Dogfooding Release Loop
- [ ] [P2] [CORE] Build release candidate artifact + manifest
''');

      final result = StabilizationExitGateService().evaluate(tasksPath);
      expect(result.ok, isFalse);
      expect(result.featureFreezeLifted, isFalse);
      expect(result.openP1Count, 1);
      expect(result.openPostStabilizationUnblockedCount, 1);
      expect(result.errorKind, 'stabilization_exit_gate');
      expect(result.message, contains('open P1 tasks=1'));
    },
  );

  test(
    'StabilizationExitGateService allows unblocked post-stabilization waves when open P1 reaches zero',
    () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_exit_gate_lifted_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final tasksPath = '${temp.path}${Platform.pathSeparator}TASKS.md';
      File(tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [x] [P1] [CORE] Stabilization done

### Post-Stabilization Feature Wave 3: Multi-Agent Execution
- [ ] [P2] [CORE] Implement workspace manager
''');

      final result = StabilizationExitGateService().evaluate(tasksPath);
      expect(result.ok, isTrue);
      expect(result.featureFreezeLifted, isTrue);
      expect(result.openP1Count, 0);
      expect(result.openPostStabilizationUnblockedCount, 1);
      expect(result.errorKind, isNull);
    },
  );

  test('StabilizationExitGateService fails when TASKS.md is missing', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_exit_missing_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final tasksPath = '${temp.path}${Platform.pathSeparator}TASKS.md';
    final result = StabilizationExitGateService().evaluate(tasksPath);

    expect(result.ok, isFalse);
    expect(result.errorKind, 'tasks_missing');
    expect(result.message, contains('No TASKS.md'));
  });
}
