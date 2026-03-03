import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_deactivate_task_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiDeactivateTaskUseCase.run delegates to GenaisysApi.deactivateTask',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      bool? lastKeepReview;
      fakeApi.deactivateTaskHandler = (projectRoot, {keepReview = false}) {
        lastProjectRoot = projectRoot;
        lastKeepReview = keepReview;
        return Future.value(
          AppResult.success(
            const TaskDeactivationDto(
              deactivated: true,
              keepReview: true,
              activeTaskTitle: null,
              activeTaskId: null,
              reviewStatus: 'approved',
              reviewUpdatedAt: '2026-02-04T00:00:00Z',
            ),
          ),
        );
      };

      final useCase = GuiDeactivateTaskUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project', keepReview: true);

      expect(lastProjectRoot, '/tmp/project');
      expect(lastKeepReview, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.deactivated, isTrue);
      expect(result.data!.keepReview, isTrue);
    },
  );
}
