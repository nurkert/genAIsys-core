import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_activate_task_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiActivateTaskUseCase.run delegates to GenaisysApi.activateTask',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      String? lastId;
      String? lastTitle;
      fakeApi.activateTaskHandler = (projectRoot, {id, title}) {
        lastProjectRoot = projectRoot;
        lastId = id;
        lastTitle = title;
        return Future.value(
          AppResult.success(
            const TaskActivationDto(
              activated: true,
              task: AppTaskDto(
                id: 'alpha-1',
                title: 'Alpha',
                section: 'Backlog',
                priority: 'p1',
                category: 'core',
                status: AppTaskStatus.open,
              ),
            ),
          ),
        );
      };

      final useCase = GuiActivateTaskUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project', id: 'alpha-1');

      expect(lastProjectRoot, '/tmp/project');
      expect(lastId, 'alpha-1');
      expect(lastTitle, isNull);
      expect(result.ok, isTrue);
      expect(result.data!.activated, isTrue);
      expect(result.data!.task?.id, 'alpha-1');
    },
  );
}
