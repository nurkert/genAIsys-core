import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/models/review_bundle.dart';
import 'package:genaisys/core/services/review_cycle_service.dart';
import 'package:genaisys/core/models/active_task_state.dart';
import 'package:genaisys/core/storage/state_store.dart';

void main() {
  test('ReviewCycleService runs review when changes exist', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_cycle_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);

    final file = File('${temp.path}${Platform.pathSeparator}README.md');
    file.writeAsStringSync('init');
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);

    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);
    final state = stateStore.read().copyWith(
      activeTask: const ActiveTaskState(title: 'Alpha', id: 'alpha-1'),
    );
    stateStore.write(state);

    file.writeAsStringSync('updated');

    final reviewAgent = _FakeReviewAgentService();
    final service = ReviewCycleService(reviewAgentService: reviewAgent);
    final result = await service.run(temp.path);

    expect(result.hasChanges, isTrue);
    expect(result.reviewed, isTrue);
    expect(result.decision, ReviewDecision.approve);
    expect(reviewAgent.calls, 1);

    final updated = stateStore.read();
    expect(updated.reviewStatus, 'approved');
  });

  test('ReviewCycleService skips review when no changes', () async {
    final temp = Directory.systemTemp.createTempSync('genaisys_review_no_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final init = Process.runSync('git', ['init'], workingDirectory: temp.path);
    expect(init.exitCode, 0);
    Process.runSync('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: temp.path);
    Process.runSync('git', [
      'config',
      'commit.gpgsign',
      'false',
    ], workingDirectory: temp.path);
    ProjectInitializer(temp.path).ensureStructure(overwrite: true);
    Process.runSync('git', ['add', '.'], workingDirectory: temp.path);
    final commit = Process.runSync('git', [
      'commit',
      '-m',
      'init',
    ], workingDirectory: temp.path);
    expect(commit.exitCode, 0);
    final layout = ProjectLayout(temp.path);
    final stateStore = StateStore(layout.statePath);

    final reviewAgent = _FakeReviewAgentService();
    final service = ReviewCycleService(reviewAgentService: reviewAgent);
    final result = await service.run(temp.path);

    expect(result.hasChanges, isFalse);
    expect(result.reviewed, isFalse);
    expect(result.decision, isNull);
    expect(reviewAgent.calls, 0);

    final updated = stateStore.read();
    expect(updated.reviewStatus, isNull);
  });
}

class _FakeReviewAgentService extends ReviewAgentService {
  int calls = 0;

  @override
  Future<ReviewAgentResult> reviewBundle(
    String projectRoot, {
    required ReviewBundle bundle,
    ReviewPersona persona = ReviewPersona.general,
    String strictness = 'standard',
    List<String> contractNotes = const [],
  }) async {
    calls += 1;
    return ReviewAgentResult(
      decision: ReviewDecision.approve,
      response: const AgentResponse(
        exitCode: 0,
        stdout: 'APPROVE\nOK',
        stderr: '',
      ),
      usedFallback: false,
    );
  }
}
