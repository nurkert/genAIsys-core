import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/init_orchestration_context.dart';

void main() {
  group('InitOrchestrationContext', () {
    test('defaults retry count to zero and keeps stage outputs unset', () {
      final context = InitOrchestrationContext(
        projectRoot: '/tmp/project',
        normalizedInputText: 'normalized input',
        inputSourcePayload: 'stdin',
      );

      expect(context.retryCount, 0);
      expect(context.vision, isNull);
      expect(context.architecture, isNull);
      expect(context.backlog, isNull);
      expect(context.config, isNull);
      expect(context.rules, isNull);
      expect(context.verification, isNull);
      expect(context.isReinit, isFalse);
      expect(context.overwrite, isFalse);
    });

    test('retains constructor-provided re-init fields', () {
      final context = InitOrchestrationContext(
        projectRoot: '/tmp/project',
        normalizedInputText: 'normalized input',
        inputSourcePayload: 'text-file:brief.txt',
        isReinit: true,
        overwrite: true,
        existingVision: 'existing vision',
        existingArchitecture: 'existing architecture',
        existingTasks: 'existing tasks',
        existingConfig: 'existing config',
        existingRules: 'existing rules',
      );

      expect(context.isReinit, isTrue);
      expect(context.overwrite, isTrue);
      expect(context.existingVision, 'existing vision');
      expect(context.existingArchitecture, 'existing architecture');
      expect(context.existingTasks, 'existing tasks');
      expect(context.existingConfig, 'existing config');
      expect(context.existingRules, 'existing rules');
    });

    test('allows staged output updates and retry counter mutations', () {
      final context = InitOrchestrationContext(
        projectRoot: '/tmp/project',
        normalizedInputText: 'normalized input',
        inputSourcePayload: 'inline',
      );

      context.vision = 'vision output';
      context.architecture = 'architecture output';
      context.backlog = 'backlog output';
      context.config = 'config output';
      context.rules = 'rules output';
      context.verification = 'verification output';

      context.incrementRetryCount();
      context.incrementRetryCount();

      expect(context.vision, 'vision output');
      expect(context.architecture, 'architecture output');
      expect(context.backlog, 'backlog output');
      expect(context.config, 'config output');
      expect(context.rules, 'rules output');
      expect(context.verification, 'verification output');
      expect(context.retryCount, 2);

      context.resetRetryCount();
      expect(context.retryCount, 0);
    });
  });
}
