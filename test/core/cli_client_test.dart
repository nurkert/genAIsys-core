import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_client.dart';
import 'package:genaisys/core/cli/cli_json_decoder.dart';
import 'package:genaisys/core/cli/cli_process_runner.dart';
import 'package:genaisys/core/cli/models/cli_models.dart';

class FakeCliProcessRunner extends CliProcessRunner {
  FakeCliProcessRunner(this._responses);

  final Map<String, CliProcessResult> _responses;

  @override
  Future<CliProcessResult> run(
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final key = args.join(' ');
    return _responses[key] ??
        const CliProcessResult(exitCode: 1, stdout: '', stderr: 'not found');
  }
}

void main() {
  test('CliClient.status parses status json output', () async {
    final runner = FakeCliProcessRunner({
      'status --json /tmp/project': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"project_root":"/tmp/project","tasks_total":1,"tasks_open":1,"tasks_blocked":0,"tasks_done":0,"active_task":"(none)","active_task_id":"(none)","review_status":"(none)","review_updated_at":"(none)","workflow_stage":"idle","cycle_count":0,"last_updated":"2026-02-04T00:00:00Z"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.status('/tmp/project');

    expect(result.ok, isTrue);
    expect(result.data, isA<CliStatusSnapshot>());
    expect(result.data!.projectRoot, '/tmp/project');
    expect(result.error, isNull);
  });

  test('CliClient.status parses json error payload', () async {
    final runner = FakeCliProcessRunner({
      'status --json /tmp/project': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No STATE.json found at: /tmp/project/.genaisys/STATE.json","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.status('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(
      result.error!.message,
      'No STATE.json found at: /tmp/project/.genaisys/STATE.json',
    );
  });

  test('CliClient.tasks adds json flag when missing', () async {
    final runner = FakeCliProcessRunner({
      'tasks --open /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"tasks":[{"id":"alpha-1","title":"Alpha","section":"Backlog","priority":"p1","category":"core","status":"open"}]}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.tasks('/tmp/project', options: ['--open']);

    expect(result.ok, isTrue);
    expect(result.data, isA<CliTasksResponse>());
    expect(result.data!.tasks.first.id, 'alpha-1');
  });

  test('CliClient.activate passes id and returns message', () async {
    final runner = FakeCliProcessRunner({
      'activate --id alpha-1 /tmp/project': const CliProcessResult(
        exitCode: 0,
        stdout: 'Activated: Alpha',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.activate('/tmp/project', id: 'alpha-1');

    expect(result.ok, isTrue);
    expect(result.message, 'Activated: Alpha');
  });

  test('CliClient.activateJson parses success payload with task', () async {
    final runner = FakeCliProcessRunner({
      'activate --id alpha-1 /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"activated":true,"task":{"id":"alpha-1","title":"Alpha","section":"Backlog","priority":"p1","category":"core","status":"open"}}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.activateJson('/tmp/project', id: 'alpha-1');

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.activated, isTrue);
    expect(result.data!.task, isNotNull);
    expect(result.data!.task!.id, 'alpha-1');
  });

  test('CliClient.activateJson parses success payload without task', () async {
    final runner = FakeCliProcessRunner({
      'activate /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout: '{"activated":false,"task":null}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.activateJson('/tmp/project');

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.activated, isFalse);
    expect(result.data!.task, isNull);
  });

  test('CliClient.activateJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'activate /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No STATE.json found at: /tmp/project/.genaisys/STATE.json","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.activateJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(
      result.error!.message,
      'No STATE.json found at: /tmp/project/.genaisys/STATE.json',
    );
  });

  test('CliClient.activateJson throws on id and title together', () {
    final client = CliClient(
      runner: FakeCliProcessRunner(const {}),
      decoder: const CliJsonDecoder(),
    );

    expect(
      () => client.activateJson('/tmp/project', id: 'alpha-1', title: 'Alpha'),
      throwsArgumentError,
    );
  });

  test('CliClient.deactivateJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'deactivate --keep-review /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"deactivated":true,"keep_review":true,"active_task":"(none)","active_task_id":"(none)","review_status":"approved","review_updated_at":"2026-02-04T00:00:00Z"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.deactivateJson(
      '/tmp/project',
      keepReview: true,
    );

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.deactivated, isTrue);
    expect(result.data!.keepReview, isTrue);
    expect(result.data!.activeTask, '(none)');
    expect(result.data!.activeTaskId, '(none)');
    expect(result.data!.reviewStatus, 'approved');
    expect(result.data!.reviewUpdatedAt, '2026-02-04T00:00:00Z');
  });

  test('CliClient.deactivateJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'deactivate /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No STATE.json found at: /tmp/project/.genaisys/STATE.json","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.deactivateJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(
      result.error!.message,
      'No STATE.json found at: /tmp/project/.genaisys/STATE.json',
    );
  });

  test('CliClient.reviewApprove passes note', () async {
    final runner = FakeCliProcessRunner({
      'review approve --note Looks good /tmp/project': const CliProcessResult(
        exitCode: 0,
        stdout: 'Review approved for: Alpha',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.reviewApprove(
      '/tmp/project',
      note: 'Looks good',
    );

    expect(result.ok, isTrue);
    expect(result.message, 'Review approved for: Alpha');
  });

  test('CliClient.reviewApproveJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'review approve --note Looks good /tmp/project --json':
          const CliProcessResult(
            exitCode: 0,
            stdout:
                '{"review_recorded":true,"decision":"approved","task_title":"Alpha","note":"Looks good"}',
            stderr: '',
          ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.reviewApproveJson(
      '/tmp/project',
      note: 'Looks good',
    );

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.reviewRecorded, isTrue);
    expect(result.data!.decision, 'approved');
    expect(result.data!.taskTitle, 'Alpha');
    expect(result.data!.note, 'Looks good');
  });

  test('CliClient.reviewApproveJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'review approve /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.reviewApproveJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });

  test('CliClient.reviewRejectJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'review reject --note Still failing /tmp/project --json':
          const CliProcessResult(
            exitCode: 0,
            stdout:
                '{"review_recorded":true,"decision":"rejected","task_title":"Alpha","note":"Still failing"}',
            stderr: '',
          ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.reviewRejectJson(
      '/tmp/project',
      note: 'Still failing',
    );

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.reviewRecorded, isTrue);
    expect(result.data!.decision, 'rejected');
    expect(result.data!.taskTitle, 'Alpha');
    expect(result.data!.note, 'Still failing');
  });

  test('CliClient.reviewRejectJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'review reject /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.reviewRejectJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });

  test('CliClient.reviewClearJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'review clear --note Reset state /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"review_cleared":true,"review_status":"(none)","review_updated_at":"2026-02-04T00:00:00Z","note":"Reset state"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.reviewClearJson(
      '/tmp/project',
      note: 'Reset state',
    );

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.reviewCleared, isTrue);
    expect(result.data!.reviewStatus, '(none)');
    expect(result.data!.reviewUpdatedAt, '2026-02-04T00:00:00Z');
    expect(result.data!.note, 'Reset state');
  });

  test('CliClient.reviewClearJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'review clear /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout: '{"error":"No review state to clear.","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.reviewClearJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No review state to clear.');
  });

  test('CliClient.initJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'init --overwrite /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"initialized":true,"genaisys_dir":"/tmp/project/.genaisys"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.initJson('/tmp/project', overwrite: true);

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.initialized, isTrue);
    expect(result.data!.genaisysDir, '/tmp/project/.genaisys');
  });

  test('CliClient.initJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'init /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout: '{"error":"Permission denied","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.initJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'Permission denied');
  });

  test('CliClient.specInit supports overwrite', () async {
    final runner = FakeCliProcessRunner({
      'spec init --overwrite /tmp/project': const CliProcessResult(
        exitCode: 0,
        stdout: 'Created: /tmp/project/.genaisys/task_specs/alpha.md',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.specInit('/tmp/project', overwrite: true);

    expect(result.ok, isTrue);
    expect(
      result.message,
      'Created: /tmp/project/.genaisys/task_specs/alpha.md',
    );
  });

  test('CliClient.planInitJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'plan init --overwrite /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"created":true,"path":"/tmp/project/.genaisys/task_specs/alpha-plan.md"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.planInitJson('/tmp/project', overwrite: true);

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.created, isTrue);
    expect(
      result.data!.path,
      '/tmp/project/.genaisys/task_specs/alpha-plan.md',
    );
  });

  test('CliClient.planInitJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'plan init /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.planInitJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });

  test('CliClient.specInitJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'spec init --overwrite /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"created":true,"path":"/tmp/project/.genaisys/task_specs/alpha.md"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.specInitJson('/tmp/project', overwrite: true);

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.created, isTrue);
    expect(result.data!.path, '/tmp/project/.genaisys/task_specs/alpha.md');
  });

  test('CliClient.specInitJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'spec init /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.specInitJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });

  test('CliClient.subtasksInitJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'subtasks init --overwrite /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"created":true,"path":"/tmp/project/.genaisys/task_specs/alpha-subtasks.md"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.subtasksInitJson(
      '/tmp/project',
      overwrite: true,
    );

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.created, isTrue);
    expect(
      result.data!.path,
      '/tmp/project/.genaisys/task_specs/alpha-subtasks.md',
    );
  });

  test('CliClient.subtasksInitJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'subtasks init /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.subtasksInitJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });

  test('CliClient.doneJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'done /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout: '{"done":true,"task_title":"Alpha"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.doneJson('/tmp/project');

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.done, isTrue);
    expect(result.data!.taskTitle, 'Alpha');
  });

  test('CliClient.doneJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'done /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.doneJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });

  test('CliClient.block passes reason', () async {
    final runner = FakeCliProcessRunner({
      'block --reason Missing creds /tmp/project': const CliProcessResult(
        exitCode: 0,
        stdout: 'Blocked: Alpha',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.block('/tmp/project', reason: 'Missing creds');

    expect(result.ok, isTrue);
    expect(result.message, 'Blocked: Alpha');
  });

  test('CliClient.blockJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'block --reason Missing creds /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"blocked":true,"task_title":"Alpha","reason":"Missing creds"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.blockJson(
      '/tmp/project',
      reason: 'Missing creds',
    );

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.blocked, isTrue);
    expect(result.data!.taskTitle, 'Alpha');
    expect(result.data!.reason, 'Missing creds');
  });

  test('CliClient.blockJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'block /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.blockJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });

  test('CliClient.cycle runs cycle command', () async {
    final runner = FakeCliProcessRunner({
      'cycle /tmp/project': const CliProcessResult(
        exitCode: 0,
        stdout: 'Cycle updated to 2',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.cycle('/tmp/project');

    expect(result.ok, isTrue);
    expect(result.message, 'Cycle updated to 2');
  });

  test('CliClient.cycleJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'cycle /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout: '{"cycle_updated":true,"cycle_count":2}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.cycleJson('/tmp/project');

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.cycleUpdated, isTrue);
    expect(result.data!.cycleCount, 2);
  });

  test('CliClient.cycleJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'cycle /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No STATE.json found at: /tmp/project/.genaisys/STATE.json","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.cycleJson('/tmp/project');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(
      result.error!.message,
      'No STATE.json found at: /tmp/project/.genaisys/STATE.json',
    );
  });

  test('CliClient.cycleRun runs cycle run command', () async {
    final runner = FakeCliProcessRunner({
      'cycle run --prompt Do work /tmp/project': const CliProcessResult(
        exitCode: 0,
        stdout: 'Task cycle completed.',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.cycleRun('/tmp/project', prompt: 'Do work');

    expect(result.ok, isTrue);
    expect(result.message, 'Task cycle completed.');
  });

  test('CliClient.cycleRun adds test summary and overwrite', () async {
    final runner = FakeCliProcessRunner({
      'cycle run --prompt Do work --test-summary Tests ok --overwrite /tmp/project':
          const CliProcessResult(
            exitCode: 0,
            stdout: 'Task cycle completed.',
            stderr: '',
          ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.cycleRun(
      '/tmp/project',
      prompt: 'Do work',
      testSummary: 'Tests ok',
      overwrite: true,
    );

    expect(result.ok, isTrue);
  });

  test('CliClient.cycleRunJson parses success payload', () async {
    final runner = FakeCliProcessRunner({
      'cycle run --prompt Do work /tmp/project --json': const CliProcessResult(
        exitCode: 0,
        stdout:
            '{"task_cycle_completed":true,"review_recorded":true,"review_decision":"approved","coding_ok":true}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.cycleRunJson('/tmp/project', prompt: 'Do work');

    expect(result.ok, isTrue);
    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.taskCycleCompleted, isTrue);
    expect(result.data!.reviewRecorded, isTrue);
    expect(result.data!.reviewDecision, 'approved');
    expect(result.data!.codingOk, isTrue);
  });

  test('CliClient.cycleRunJson parses error payload', () async {
    final runner = FakeCliProcessRunner({
      'cycle run --prompt Do work /tmp/project --json': const CliProcessResult(
        exitCode: 2,
        stdout:
            '{"error":"No active task set. Use: activate","code":"state_error"}',
        stderr: '',
      ),
    });
    final client = CliClient(runner: runner, decoder: const CliJsonDecoder());

    final result = await client.cycleRunJson('/tmp/project', prompt: 'Do work');

    expect(result.ok, isFalse);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
    expect(result.error!.code, 'state_error');
    expect(result.error!.message, 'No active task set. Use: activate');
  });
}
