import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_next_task_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiNextTaskUseCase.load delegates section filter to GenaisysApi.getNextTask',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      String? lastSection;
      fakeApi.getNextTaskHandler = (projectRoot, {sectionFilter}) {
        lastProjectRoot = projectRoot;
        lastSection = sectionFilter;
        return Future.value(
          AppResult.success(
            const AppTaskDto(
              id: 'alpha-1',
              title: 'Alpha',
              section: 'Backlog',
              priority: 'p1',
              category: 'core',
              status: AppTaskStatus.open,
            ),
          ),
        );
      };

      final useCase = GuiNextTaskUseCase(api: fakeApi);
      final result = await useCase.load(
        '/tmp/project',
        sectionFilter: 'Backlog',
      );

      expect(lastProjectRoot, '/tmp/project');
      expect(lastSection, 'Backlog');
      expect(result.ok, isTrue);
      expect(result.data!.id, 'alpha-1');
    },
  );
}
