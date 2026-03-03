import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/models/cli_models.dart';
import 'package:genaisys/core/models/workflow_stage.dart';

void main() {
  test('CliErrorResponse parses error json', () {
    final jsonMap =
        jsonDecode('''
{"error":"Missing --prompt for cycle run","code":"missing_prompt"}
''')
            as Map<String, dynamic>;

    final error = CliErrorResponse.tryParse(jsonMap);

    expect(error, isNotNull);
    expect(error!.code, 'missing_prompt');
    expect(error.message, 'Missing --prompt for cycle run');
  });

  test('CliStatusSnapshot parses status json', () {
    final jsonMap =
        jsonDecode('''
{"project_root":"/tmp/project","tasks_total":3,"tasks_open":1,"tasks_blocked":1,"tasks_done":1,"active_task":"Alpha","active_task_id":"alpha-1","review_status":"approved","review_updated_at":"2026-02-03T00:00:00Z","workflow_stage":"execution","cycle_count":2,"last_updated":"2026-02-04T00:00:00Z"}
''')
            as Map<String, dynamic>;

    final snapshot = CliStatusSnapshot.fromJson(jsonMap);

    expect(snapshot.projectRoot, '/tmp/project');
    expect(snapshot.tasksTotal, 3);
    expect(snapshot.tasksOpen, 1);
    expect(snapshot.tasksBlocked, 1);
    expect(snapshot.tasksDone, 1);
    expect(snapshot.activeTask, 'Alpha');
    expect(snapshot.activeTaskId, 'alpha-1');
    expect(snapshot.reviewStatus, 'approved');
    expect(snapshot.reviewUpdatedAt, '2026-02-03T00:00:00Z');
    expect(snapshot.workflowStage, WorkflowStage.execution);
    expect(snapshot.cycleCount, 2);
    expect(snapshot.lastUpdated, '2026-02-04T00:00:00Z');
  });

  test('CliInitResponse parses init json', () {
    final jsonMap =
        jsonDecode('''
{"initialized":true,"genaisys_dir":"/tmp/project/.genaisys"}
''')
            as Map<String, dynamic>;

    final response = CliInitResponse.fromJson(jsonMap);

    expect(response.initialized, isTrue);
    expect(response.genaisysDir, '/tmp/project/.genaisys');
  });

  test('CliSpecInitResponse parses spec init json', () {
    final jsonMap =
        jsonDecode('''
{"created":true,"path":"/tmp/project/.genaisys/task_specs/alpha.md"}
''')
            as Map<String, dynamic>;

    final response = CliSpecInitResponse.fromJson(jsonMap);

    expect(response.created, isTrue);
    expect(response.path, '/tmp/project/.genaisys/task_specs/alpha.md');
  });

  test('CliPlanInitResponse parses plan init json', () {
    final jsonMap =
        jsonDecode('''
{"created":true,"path":"/tmp/project/.genaisys/task_specs/alpha-plan.md"}
''')
            as Map<String, dynamic>;

    final response = CliPlanInitResponse.fromJson(jsonMap);

    expect(response.created, isTrue);
    expect(response.path, '/tmp/project/.genaisys/task_specs/alpha-plan.md');
  });

  test('CliSubtasksInitResponse parses subtasks init json', () {
    final jsonMap =
        jsonDecode('''
{"created":true,"path":"/tmp/project/.genaisys/task_specs/alpha-subtasks.md"}
''')
            as Map<String, dynamic>;

    final response = CliSubtasksInitResponse.fromJson(jsonMap);

    expect(response.created, isTrue);
    expect(
      response.path,
      '/tmp/project/.genaisys/task_specs/alpha-subtasks.md',
    );
  });

  test('CliTasksResponse parses tasks json', () {
    final jsonMap =
        jsonDecode('''
{"tasks":[{"id":"alpha-1","title":"Alpha","section":"Backlog","priority":"p1","category":"core","status":"open"},{"id":"beta-2","title":"Beta","section":"Review","priority":"p2","category":"docs","status":"blocked"}]}
''')
            as Map<String, dynamic>;

    final response = CliTasksResponse.fromJson(jsonMap);

    expect(response.tasks.length, 2);
    expect(response.tasks.first.id, 'alpha-1');
    expect(response.tasks.first.status, CliTaskStatus.open);
    expect(response.tasks.last.status, CliTaskStatus.blocked);
  });

  test('CliReviewStatus parses review status json', () {
    final jsonMap =
        jsonDecode('''
{"review_status":"rejected","review_updated_at":"2026-02-01T00:00:00Z"}
''')
            as Map<String, dynamic>;

    final status = CliReviewStatus.fromJson(jsonMap);

    expect(status.status, 'rejected');
    expect(status.updatedAt, '2026-02-01T00:00:00Z');
  });

  test('CliActivateResponse parses activate json', () {
    final jsonMap =
        jsonDecode('''
{"activated":true,"task":{"id":"alpha-1","title":"Alpha","section":"Backlog","priority":"p1","category":"core","status":"open"}}
''')
            as Map<String, dynamic>;

    final response = CliActivateResponse.fromJson(jsonMap);

    expect(response.activated, isTrue);
    expect(response.task, isNotNull);
    expect(response.task!.id, 'alpha-1');
    expect(response.task!.title, 'Alpha');
  });

  test('CliDeactivateResponse parses deactivate json', () {
    final jsonMap =
        jsonDecode('''
{"deactivated":true,"keep_review":true,"active_task":"(none)","active_task_id":"(none)","review_status":"approved","review_updated_at":"2026-02-04T00:00:00Z"}
''')
            as Map<String, dynamic>;

    final response = CliDeactivateResponse.fromJson(jsonMap);

    expect(response.deactivated, isTrue);
    expect(response.keepReview, isTrue);
    expect(response.activeTask, '(none)');
    expect(response.activeTaskId, '(none)');
    expect(response.reviewStatus, 'approved');
    expect(response.reviewUpdatedAt, '2026-02-04T00:00:00Z');
  });

  test('CliDoneResponse parses done json', () {
    final jsonMap =
        jsonDecode('''
{"done":true,"task_title":"Alpha"}
''')
            as Map<String, dynamic>;

    final response = CliDoneResponse.fromJson(jsonMap);

    expect(response.done, isTrue);
    expect(response.taskTitle, 'Alpha');
  });

  test('CliBlockResponse parses block json', () {
    final jsonMap =
        jsonDecode('''
{"blocked":true,"task_title":"Alpha","reason":"Missing creds"}
''')
            as Map<String, dynamic>;

    final response = CliBlockResponse.fromJson(jsonMap);

    expect(response.blocked, isTrue);
    expect(response.taskTitle, 'Alpha');
    expect(response.reason, 'Missing creds');
  });

  test('CliCycleResponse parses cycle json', () {
    final jsonMap =
        jsonDecode('''
{"cycle_updated":true,"cycle_count":2}
''')
            as Map<String, dynamic>;

    final response = CliCycleResponse.fromJson(jsonMap);

    expect(response.cycleUpdated, isTrue);
    expect(response.cycleCount, 2);
  });

  test('CliCycleRunResponse parses cycle run json', () {
    final jsonMap =
        jsonDecode('''
{"task_cycle_completed":true,"review_recorded":true,"review_decision":"approved","coding_ok":true}
''')
            as Map<String, dynamic>;

    final response = CliCycleRunResponse.fromJson(jsonMap);

    expect(response.taskCycleCompleted, isTrue);
    expect(response.reviewRecorded, isTrue);
    expect(response.reviewDecision, 'approved');
    expect(response.codingOk, isTrue);
  });

  test('CliReviewDecisionResponse parses review decision json', () {
    final jsonMap =
        jsonDecode('''
{"review_recorded":true,"decision":"approved","task_title":"Alpha","note":"Looks good"}
''')
            as Map<String, dynamic>;

    final response = CliReviewDecisionResponse.fromJson(jsonMap);

    expect(response.reviewRecorded, isTrue);
    expect(response.decision, 'approved');
    expect(response.taskTitle, 'Alpha');
    expect(response.note, 'Looks good');
  });

  test('CliReviewClearResponse parses review clear json', () {
    final jsonMap =
        jsonDecode('''
{"review_cleared":true,"review_status":"(none)","review_updated_at":"2026-02-04T00:00:00Z","note":"Reset state"}
''')
            as Map<String, dynamic>;

    final response = CliReviewClearResponse.fromJson(jsonMap);

    expect(response.reviewCleared, isTrue);
    expect(response.reviewStatus, '(none)');
    expect(response.reviewUpdatedAt, '2026-02-04T00:00:00Z');
    expect(response.note, 'Reset state');
  });
}
