import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/gui/gui_dashboard_use_case.dart';

import 'support/fake_genaisys_api.dart';

void main() {
  test(
    'GuiDashboardUseCase.load delegates to GenaisysApi.getDashboard',
    () async {
      const healthSnapshot = AppHealthSnapshotDto(
        agent: AppHealthCheckDto(ok: true, message: 'Agent ok'),
        allowlist: AppHealthCheckDto(ok: true, message: 'Allowlist ok'),
        git: AppHealthCheckDto(ok: true, message: 'Git ok'),
        review: AppHealthCheckDto(ok: true, message: 'Review ok'),
      );
      const telemetrySnapshot = AppRunTelemetryDto(
        recentEvents: [],
        errorClass: null,
        errorKind: null,
        errorMessage: null,
        agentExitCode: null,
        agentStderrExcerpt: null,
        lastErrorEvent: null,
      );
      final fakeApi = FakeGenaisysApi();
      String? lastProjectRoot;
      fakeApi.getDashboardHandler = (projectRoot) {
        lastProjectRoot = projectRoot;
        return Future.value(
          AppResult.success(
            const AppDashboardDto(
              status: AppStatusSnapshotDto(
                projectRoot: '/tmp/project',
                tasksTotal: 2,
                tasksOpen: 1,
                tasksDone: 1,
                tasksBlocked: 0,
                activeTaskTitle: 'Alpha',
                activeTaskId: 'alpha-1',
                reviewStatus: 'approved',
                reviewUpdatedAt: '2026-02-04T00:00:00Z',
                cycleCount: 1,
                lastUpdated: '2026-02-04T00:00:00Z',
                workflowStage: 'review',
                health: healthSnapshot,
                telemetry: telemetrySnapshot,
              ),
              review: AppReviewStatusDto(
                status: 'approved',
                updatedAt: '2026-02-04T00:00:00Z',
              ),
            ),
          ),
        );
      };

      final useCase = GuiDashboardUseCase(api: fakeApi);
      final result = await useCase.load('/tmp/project');

      expect(lastProjectRoot, '/tmp/project');
      expect(result.ok, isTrue);
      expect(result.data!.status.activeTaskTitle, 'Alpha');
      expect(result.data!.review.status, 'approved');
    },
  );
}
