import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_block_task_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiBlockTaskUseCase.run delegates to GenaisysApi.blockTask',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      String? lastReason;
      fakeApi.blockTaskHandler = (projectRoot, {reason}) {
        lastProjectRoot = projectRoot;
        lastReason = reason;
        return Future.value(
          AppResult.success(
            const TaskBlockedDto(
              blocked: true,
              taskTitle: 'Alpha',
              reason: 'Waiting for credentials',
            ),
          ),
        );
      };

      final useCase = GuiBlockTaskUseCase(api: fakeApi);
      final result = await useCase.run(
        '/tmp/project',
        reason: 'Waiting for credentials',
      );

      expect(lastProjectRoot, '/tmp/project');
      expect(lastReason, 'Waiting for credentials');
      expect(result.ok, isTrue);
      expect(result.data!.blocked, isTrue);
      expect(result.data!.taskTitle, 'Alpha');
      expect(result.data!.reason, 'Waiting for credentials');
    },
  );

  test('GuiBlockTaskUseCase.run forwards null reason when omitted', () async {
    final fakeApi = FakeGenaisysApi();
    String? lastProjectRoot;
    String? lastReason;
    fakeApi.blockTaskHandler = (projectRoot, {reason}) {
      lastProjectRoot = projectRoot;
      lastReason = reason;
      return Future.value(
        AppResult.success(
          const TaskBlockedDto(blocked: true, taskTitle: 'Alpha', reason: null),
        ),
      );
    };

    final useCase = GuiBlockTaskUseCase(api: fakeApi);
    final result = await useCase.run('/tmp/project');

    expect(lastProjectRoot, '/tmp/project');
    expect(lastReason, isNull);
    expect(result.ok, isTrue);
    expect(result.data!.blocked, isTrue);
    expect(result.data!.reason, isNull);
  });
}
