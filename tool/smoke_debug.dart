import 'package:flutter/foundation.dart';
import 'package:genaisys/core/services/autopilot/autopilot_smoke_check_service.dart';

Future<void> main() async {
  final result = await AutopilotSmokeCheckService().run(keepProject: true);
  // Intentionally simple, this is a local debugging helper.
  debugPrint('ok=${result.ok}');
  debugPrint('root=${result.projectRoot}');
  debugPrint('task=${result.taskTitle}');
  debugPrint('review=${result.reviewDecision}');
  debugPrint('taskDone=${result.taskDone}');
  debugPrint('commitCount=${result.commitCount}');
  debugPrint('failures=${result.failures}');
}
