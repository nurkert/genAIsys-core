import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_tasks_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiTasksUseCase.load delegates query to GenaisysApi.listTasks',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      TaskListQuery? lastQuery;
      fakeApi.listTasksHandler =
          (projectRoot, {query = const TaskListQuery()}) {
            lastProjectRoot = projectRoot;
            lastQuery = query;
            return Future.value(
              AppResult.success(
                const AppTaskListDto(
                  total: 1,
                  tasks: [
                    AppTaskDto(
                      id: 'alpha-1',
                      title: 'Alpha',
                      section: 'Backlog',
                      priority: 'p1',
                      category: 'core',
                      status: AppTaskStatus.open,
                    ),
                  ],
                ),
              ),
            );
          };

      final useCase = GuiTasksUseCase(api: fakeApi);
      final result = await useCase.load(
        '/tmp/project',
        query: const TaskListQuery(openOnly: true),
      );

      expect(lastProjectRoot, '/tmp/project');
      expect(lastQuery?.openOnly, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.tasks.single.id, 'alpha-1');
    },
  );
}
