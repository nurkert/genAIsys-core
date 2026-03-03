import 'package:test/test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_review_actions_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test('GuiReviewActionsUseCase.approve delegates to GenaisysApi', () async {
    final fakeApi = FakeGenaisysApi();
    String? lastProjectRoot;
    String? lastNote;
    fakeApi.approveReviewHandler = (projectRoot, {note}) {
      lastProjectRoot = projectRoot;
      lastNote = note;
      return Future.value(
        AppResult.success(
          const ReviewDecisionDto(
            reviewRecorded: true,
            decision: 'approved',
            taskTitle: 'Alpha',
            note: 'Looks good',
          ),
        ),
      );
    };

    final useCase = GuiReviewActionsUseCase(api: fakeApi);
    final result = await useCase.approve('/tmp/project', note: 'Looks good');

    expect(lastProjectRoot, '/tmp/project');
    expect(lastNote, 'Looks good');
    expect(result.ok, isTrue);
    expect(result.data!.decision, 'approved');
  });

  test('GuiReviewActionsUseCase.reject delegates to GenaisysApi', () async {
    final fakeApi = FakeGenaisysApi();
    fakeApi.rejectReviewHandler = (projectRoot, {note}) {
      return Future.value(
        AppResult.success(
          const ReviewDecisionDto(
            reviewRecorded: true,
            decision: 'rejected',
            taskTitle: 'Alpha',
            note: 'Needs change',
          ),
        ),
      );
    };

    final useCase = GuiReviewActionsUseCase(api: fakeApi);
    final result = await useCase.reject('/tmp/project', note: 'Needs change');

    expect(result.ok, isTrue);
    expect(result.data!.decision, 'rejected');
  });

  test('GuiReviewActionsUseCase.clear delegates to GenaisysApi', () async {
    final fakeApi = FakeGenaisysApi();
    fakeApi.clearReviewHandler = (projectRoot, {note}) {
      return Future.value(
        AppResult.success(
          const ReviewClearDto(
            reviewCleared: true,
            reviewStatus: '(none)',
            reviewUpdatedAt: '(none)',
            note: null,
          ),
        ),
      );
    };

    final useCase = GuiReviewActionsUseCase(api: fakeApi);
    final result = await useCase.clear('/tmp/project');

    expect(result.ok, isTrue);
    expect(result.data!.reviewCleared, isTrue);
  });
}
