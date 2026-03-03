import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_spec_artifacts_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiSpecArtifactsUseCase delegates plan/spec/subtasks initialization',
    () async {
      final fakeApi = FakeGenaisysApi();
      var planCalled = false;
      var specCalled = false;
      var subtasksCalled = false;

      fakeApi.initializePlanHandler = (projectRoot, {overwrite = false}) {
        planCalled = true;
        return Future.value(
          AppResult.success(
            const SpecInitializationDto(
              created: true,
              path: '/tmp/project/.genaisys/task_specs/alpha-plan.md',
            ),
          ),
        );
      };
      fakeApi.initializeSpecHandler = (projectRoot, {overwrite = false}) {
        specCalled = true;
        return Future.value(
          AppResult.success(
            const SpecInitializationDto(
              created: true,
              path: '/tmp/project/.genaisys/task_specs/alpha.md',
            ),
          ),
        );
      };
      fakeApi.initializeSubtasksHandler = (projectRoot, {overwrite = false}) {
        subtasksCalled = true;
        return Future.value(
          AppResult.success(
            const SpecInitializationDto(
              created: true,
              path: '/tmp/project/.genaisys/task_specs/alpha-subtasks.md',
            ),
          ),
        );
      };

      final useCase = GuiSpecArtifactsUseCase(api: fakeApi);
      final plan = await useCase.initializePlan('/tmp/project');
      final spec = await useCase.initializeSpec('/tmp/project');
      final subtasks = await useCase.initializeSubtasks('/tmp/project');

      expect(planCalled, isTrue);
      expect(specCalled, isTrue);
      expect(subtasksCalled, isTrue);
      expect(plan.ok, isTrue);
      expect(spec.ok, isTrue);
      expect(subtasks.ok, isTrue);
    },
  );
}
