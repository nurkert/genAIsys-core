import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_initialize_project_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiInitializeProjectUseCase.run delegates to GenaisysApi.initializeProject',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      bool? lastOverwrite;
      fakeApi.initializeProjectHandler = (projectRoot, {overwrite = false}) {
        lastProjectRoot = projectRoot;
        lastOverwrite = overwrite;
        return Future.value(
          AppResult.success(
            const ProjectInitializationDto(
              initialized: true,
              genaisysDir: '/tmp/project/.genaisys',
            ),
          ),
        );
      };

      final useCase = GuiInitializeProjectUseCase(api: fakeApi);
      final result = await useCase.run('/tmp/project', overwrite: true);

      expect(lastProjectRoot, '/tmp/project');
      expect(lastOverwrite, isTrue);
      expect(result.ok, isTrue);
      expect(result.data!.initialized, isTrue);
      expect(result.data!.genaisysDir, '/tmp/project/.genaisys');
    },
  );
}
