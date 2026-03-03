import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_done_task_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiDoneTaskUseCase.run delegates to GenaisysApi.markTaskDone',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      fakeApi.markTaskDoneHandler = (projectRoot) {
        lastProjectRoot = projectRoot;
        return Future.value(
          AppResult.success(const TaskDoneDto(done: true, taskTitle: 'Alpha')),
        );
      };

      final useCase = GuiDoneTaskUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project');

      expect(lastProjectRoot, '/tmp/project');
      expect(result.ok, isTrue);
      expect(result.data!.done, isTrue);
      expect(result.data!.taskTitle, 'Alpha');
    },
  );
}
