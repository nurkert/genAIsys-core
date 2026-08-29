import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/ui/desktop/controllers/run_log_viewer_controller.dart';

void main() {
  test('policyViolationCount detects policy-related run log entries', () async {
    final RunLogViewerController controller = RunLogViewerController(
      projectRootPath: '/tmp/project',
      readUseCase: _FakeReadRunLogPageUseCase(
        AppResult.success(
          const AppRunLogPageDto(
            events: <AppRunLogEventDto>[
              AppRunLogEventDto(
                timestamp: '2026-02-12T10:00:00Z',
                event: 'policy_error',
                message: 'Spec required files missing.',
                data: <String, Object?>{
                  'error_class': 'policy',
                  'error_kind': 'spec_required_files_missing',
                },
              ),
              AppRunLogEventDto(
                timestamp: '2026-02-12T10:01:00Z',
                event: 'quality_gate_blocked',
                message: 'Quality gate blocked by shell allowlist.',
                data: <String, Object?>{'error_kind': 'shell_allowlist'},
              ),
              AppRunLogEventDto(
                timestamp: '2026-02-12T10:02:00Z',
                event: 'task_cycle_end',
                message: 'Policy violation: safe_write blocked',
              ),
              AppRunLogEventDto(
                timestamp: '2026-02-12T10:03:00Z',
                event: 'task_done',
                message: 'Task completed successfully.',
              ),
            ],
          ),
        ),
      ),
    );

    await controller.refresh();

    expect(controller.policyViolationCount, 3);

    controller.setFilter(RunLogFilter.errors);
    controller.setQuery('task');
    expect(controller.policyViolationCount, 3);
  });

  test('isPolicyViolationEvent returns false for non-policy entries', () {
    const AppRunLogEventDto entry = AppRunLogEventDto(
      timestamp: '2026-02-12T11:00:00Z',
      event: 'task_done',
      message: 'Completed without warnings.',
      data: <String, Object?>{'error_class': 'execution'},
    );

    expect(RunLogViewerController.isPolicyViolationEvent(entry), isFalse);
  });
}

class _FakeReadRunLogPageUseCase extends ReadRunLogPageUseCase {
  _FakeReadRunLogPageUseCase(this._result);

  final AppResult<AppRunLogPageDto> _result;

  @override
  Future<AppResult<AppRunLogPageDto>> run(
    String projectRoot, {
    int limit = 200,
    int? beforeOffset,
  }) async {
    return _result;
  }
}
