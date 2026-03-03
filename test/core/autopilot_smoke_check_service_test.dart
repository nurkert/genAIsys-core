import 'package:test/test.dart';

import 'package:genaisys/core/services/autopilot/autopilot_smoke_check_service.dart';

void main() {
  test(
    'AutopilotSmokeCheckService passes end-to-end smoke run',
    skip: 'Requires a real agent CLI (codex/claude-code/gemini) and a live '
        'git repo. Run manually with: flutter test '
        'test/core/autopilot_smoke_check_service_test.dart',
    () async {
    final service = AutopilotSmokeCheckService();

    final result = await service.run(keepProject: false);

    expect(result.ok, isTrue);
    expect(result.failures, isEmpty);
    expect(result.reviewDecision, 'approve');
    expect(result.taskDone, isTrue);
    expect(result.commitCount, greaterThanOrEqualTo(2));
    },
  );
}
