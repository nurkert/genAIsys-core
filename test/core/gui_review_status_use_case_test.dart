import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_review_status_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiReviewStatusUseCase.load delegates to GenaisysApi.getReviewStatus',
    () async {
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      fakeApi.getReviewStatusHandler = (projectRoot) {
        lastProjectRoot = projectRoot;
        return Future.value(
          AppResult.success(
            const AppReviewStatusDto(
              status: 'approved',
              updatedAt: '2026-02-04T00:00:00Z',
            ),
          ),
        );
      };

      final useCase = GuiReviewStatusUseCase(api: fakeApi);
      final result = await useCase.load('/tmp/project');

      expect(lastProjectRoot, '/tmp/project');
      expect(result.ok, isTrue);
      expect(result.data!.status, 'approved');
    },
  );
}
