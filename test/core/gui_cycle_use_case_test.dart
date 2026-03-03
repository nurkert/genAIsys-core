import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_cycle_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test('GuiCycleUseCase.tick delegates to GenaisysApi.cycle', () async {
    final fakeApi = FakeGenaisysApi();
    String? lastProjectRoot;
    fakeApi.cycleHandler = (projectRoot) {
      lastProjectRoot = projectRoot;
      return Future.value(
        AppResult.success(
          const CycleTickDto(cycleUpdated: true, cycleCount: 2),
        ),
      );
    };

    final useCase = GuiCycleUseCase(api: fakeApi);
    final result = await useCase.tick('/tmp/project');

    expect(lastProjectRoot, '/tmp/project');
    expect(result.ok, isTrue);
    expect(result.data!.cycleCount, 2);
  });

  test('GuiCycleUseCase.run delegates to GenaisysApi.runTaskCycle', () async {
    final fakeApi = FakeGenaisysApi();
    String? lastPrompt;
    String? lastSummary;
    bool? lastOverwrite;
    fakeApi.runTaskCycleHandler =
        (projectRoot, {required prompt, testSummary, overwrite = false}) {
          lastPrompt = prompt;
          lastSummary = testSummary;
          lastOverwrite = overwrite;
          return Future.value(
            AppResult.success(
              const TaskCycleExecutionDto(
                taskCycleCompleted: true,
                reviewRecorded: true,
                reviewDecision: 'approve',
                codingOk: true,
              ),
            ),
          );
        };

    final useCase = GuiCycleUseCase(api: fakeApi);
    final result = await useCase.run(
      '/tmp/project',
      prompt: 'Implement next step',
      testSummary: 'all green',
      overwrite: true,
    );

    expect(lastPrompt, 'Implement next step');
    expect(lastSummary, 'all green');
    expect(lastOverwrite, isTrue);
    expect(result.ok, isTrue);
    expect(result.data!.taskCycleCompleted, isTrue);
  });
}
