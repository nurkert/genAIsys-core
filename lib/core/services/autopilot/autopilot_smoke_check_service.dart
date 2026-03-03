// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../../agents/agent_registry.dart';
import '../../agents/agent_runner.dart';
import '../../agents/agent_selector.dart';
import '../../project_initializer.dart';
import '../../project_layout.dart';
import '../../storage/atomic_file_write.dart';
import '../../storage/task_store.dart';
import '../../models/task.dart';
import '../../git/git_service.dart';
import '../task_management/activate_service.dart';
import '../agents/analysis_agent_service.dart';
import '../agent_context_service.dart';
import '../pipeline_prompt_assembler.dart';
import '../agents/agent_service.dart';
import '../config_service.dart';
import '../agents/coding_agent_service.dart';
import '../merge_conflict_resolver_service.dart';
import '../orchestrator_step_service.dart';
import '../agents/review_agent_service.dart';
import '../review_bundle_service.dart';
import '../review_service.dart';
import '../agents/spec_agent_service.dart';
import '../strategic_planner_service.dart';
import '../task_cycle_service.dart';
import '../task_management/task_pipeline_service.dart';
import '../vision_backlog_planner_service.dart';
import '../task_management/done_service.dart';
import '../task_management/active_task_resolver.dart';

class AutopilotSmokeCheckResult {
  AutopilotSmokeCheckResult({
    required this.ok,
    required this.projectRoot,
    required this.taskTitle,
    required this.reviewDecision,
    required this.taskDone,
    required this.commitCount,
    required this.failures,
  });

  final bool ok;
  final String projectRoot;
  final String taskTitle;
  final String? reviewDecision;
  final bool taskDone;
  final int commitCount;
  final List<String> failures;
}

class AutopilotSmokeCheckService {
  Future<AutopilotSmokeCheckResult> run({bool keepProject = true}) async {
    final temp = Directory.systemTemp.createTempSync('genaisys_smoke_');
    final root = temp.path;
    try {
      ProjectInitializer(root).ensureStructure(overwrite: true);
      _initGit(root);
      ConfigService().update(
        root,
        update: const ConfigUpdate(
          qualityGateEnabled: false,
          shellAllowlistProfile: 'custom',
          shellAllowlist: ['smoke-agent'],
        ),
      );
      final taskTitle = _writeSmokeTasks(root);
      _commitBootstrapArtifacts(root);

      final agentService = _buildSmokeAgentService(root);
      final gitService = GitService();
      final reviewService = ReviewService();
      final doneService = DoneService(
        gitService: gitService,
        mergeConflictResolver: MergeConflictResolverService(
          agentService: agentService,
        ),
      );

      final pipeline = TaskPipelineService(
        specAgentService: SpecAgentService(agentService: agentService),
        codingAgentService: CodingAgentService(agentService: agentService),
        reviewAgentService: ReviewAgentService(agentService: agentService),
        reviewBundleService: ReviewBundleService(gitService: gitService),
        promptAssembler: PipelinePromptAssembler(
          analysisAgentService: AnalysisAgentService(
            agentService: agentService,
          ),
        ),
        contextService: AgentContextService(),
        activeTaskResolver: ActiveTaskResolver(),
        gitService: gitService,
      );

      final cycle = TaskCycleService(
        taskPipelineService: pipeline,
        reviewService: reviewService,
        gitService: gitService,
        doneService: doneService,
        activeTaskResolver: ActiveTaskResolver(),
        maxReviewRetries: 1,
      );

      final planner = VisionBacklogPlannerService(
        strategicPlanner: StrategicPlannerService(agentService: agentService),
      );

      final stepService = OrchestratorStepService(
        activateService: ActivateService(gitService: gitService),
        taskCycleService: cycle,
        plannerService: planner,
        gitService: gitService,
      );

      final stepResult = await stepService.run(
        root,
        codingPrompt: 'Add a smoke check marker file.',
        testSummary: 'Smoke check: synthetic test evidence.',
        overwriteArtifacts: true,
        minOpenTasks: 1,
        maxPlanAdd: 1,
      );

      final failures = <String>[];
      final reviewDecision = stepResult.reviewDecision;
      if (reviewDecision != 'approve') {
        failures.add('review_not_approved');
      }

      final taskDone = _isTaskDone(root, taskTitle);
      if (!taskDone) {
        failures.add('task_not_done');
      }

      final commitCount = _gitCommitCount(root);
      if (commitCount < 2) {
        failures.add('commit_missing');
      }

      final ok = failures.isEmpty;
      if (ok && !keepProject) {
        temp.deleteSync(recursive: true);
      }

      return AutopilotSmokeCheckResult(
        ok: ok,
        projectRoot: root,
        taskTitle: taskTitle,
        reviewDecision: reviewDecision,
        taskDone: taskDone,
        commitCount: commitCount,
        failures: failures,
      );
    } catch (error) {
      if (!keepProject) {
        try {
          temp.deleteSync(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  void _initGit(String root) {
    _runGit(root, ['init', '-b', 'main']);
    _runGit(root, ['config', 'user.email', 'smoke@genaisys.local']);
    _runGit(root, ['config', 'user.name', 'Genaisys Smoke']);
    File(
      _join(root, '.gitignore'),
    ).writeAsStringSync('.genaisys/\n.remote.git/\n');
    Directory(_join(root, 'lib')).createSync(recursive: true);
    File(_join(root, 'README.md')).writeAsStringSync('# Smoke Project\n');
    File(
      _join(root, 'lib/smoke_marker.txt'),
    ).writeAsStringSync('Smoke check marker file.\n');
    File(_join(root, 'lib/.keep')).writeAsStringSync('');
    _runGit(root, ['add', '-A']);
    _runGit(root, [
      'commit',
      '--no-gpg-sign',
      '-m',
      'chore: init smoke project',
    ]);

    // Delivery preflight expects a remote when auto-push is enabled.
    _runGit(root, ['init', '--bare', '.remote.git']);
    _runGit(root, ['remote', 'add', 'origin', _join(root, '.remote.git')]);
    _runGit(root, ['push', '-u', 'origin', 'main']);
  }

  String _writeSmokeTasks(String root) {
    final layout = ProjectLayout(root);
    final title = 'Smoke check: add marker file';
    final content = StringBuffer()
      ..writeln('# Tasks')
      ..writeln('')
      ..writeln('## Backlog')
      ..writeln('- [ ] [P1] [CORE] $title')
      ..writeln('');
    AtomicFileWrite.writeStringSync(layout.tasksPath, content.toString());
    return title;
  }

  void _commitBootstrapArtifacts(String root) {
    final gitService = GitService();
    gitService.addAll(root);
    if (!gitService.hasChanges(root)) {
      return;
    }
    gitService.commit(root, 'chore: bootstrap genaisys smoke artifacts');
    _runGit(root, ['push']);
  }

  bool _isTaskDone(String root, String title) {
    final layout = ProjectLayout(root);
    final tasks = TaskStore(layout.tasksPath).readTasks();
    for (final task in tasks) {
      if (task.title == title) {
        return task.completion == TaskCompletion.done;
      }
    }
    return false;
  }

  int _gitCommitCount(String root) {
    return GitService().commitCount(root);
  }

  void _runGit(String root, List<String> args) {
    final result = Process.runSync('git', args, workingDirectory: root);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      final message = stderr.isNotEmpty
          ? stderr
          : "git ${args.join(' ')} failed with exit ${result.exitCode}";
      throw StateError(message);
    }
  }

  AgentService _buildSmokeAgentService(String root) {
    final runner = _SmokeAgentRunner(root);
    final registry = AgentRegistry(
      codex: runner,
      gemini: runner,
      claudeCode: runner,
      vibe: runner,
      amp: runner,
    );
    final selector = AgentSelector(registry: registry);
    return AgentService(selector: selector);
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}

class _SmokeAgentRunner implements AgentRunner {
  _SmokeAgentRunner(this.projectRoot);

  final String projectRoot;

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final system = request.systemPrompt?.toLowerCase() ?? '';
    final prompt = request.prompt.toLowerCase();
    if (prompt.contains('answer with approve or reject on the first line')) {
      return _response(
        request,
        stdout:
            'APPROVE\nThe changes in lib/smoke_marker.txt are correct. '
            'The marker file update is minimal and deterministic as expected.',
      );
    }
    if (system.contains('planning agent')) {
      return _response(request, stdout: _plan());
    }
    if (system.contains('specification agent')) {
      return _response(request, stdout: _spec());
    }
    if (system.contains('task decomposition')) {
      return _response(request, stdout: _subtasks());
    }
    if (system.contains('reviewer')) {
      return _response(
        request,
        stdout:
            'APPROVE\nThe changes in lib/smoke_marker.txt are correct. '
            'The marker file update is minimal and deterministic as expected.',
      );
    }
    if (system.contains('product strategist')) {
      return _response(request, stdout: '- Add smoke check marker task');
    }
    if (system.contains('debugging expert')) {
      return _response(request, stdout: 'No issues detected.');
    }
    if (system.contains('merge conflicts')) {
      return _response(request, stdout: 'No conflicts to resolve.');
    }

    _writeSmokeChange();
    return _response(request, stdout: 'Applied smoke check change.');
  }

  AgentResponse _response(
    AgentRequest request, {
    required String stdout,
    int exitCode = 0,
    String stderr = '',
  }) {
    final startedAt = DateTime.now().toUtc();
    return AgentResponse(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      commandEvent: AgentCommandEvent(
        executable: 'smoke-agent',
        arguments: const [],
        runInShell: false,
        startedAt: startedAt.toIso8601String(),
        durationMs: 0,
        timedOut: false,
        workingDirectory: request.workingDirectory,
      ),
    );
  }

  void _writeSmokeChange() {
    final dir = Directory(_join(projectRoot, 'lib'));
    dir.createSync(recursive: true);
    final file = File(_join(projectRoot, 'lib/smoke_marker.txt'));
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final line = 'Smoke check marker at $timestamp\n';
    final existing = file.existsSync()
        ? file.readAsStringSync()
        : 'Smoke check marker file.\n';
    file.writeAsStringSync('$existing$line');
  }

  String _plan() {
    return '''# Plan\n\n## Steps\n1. Add a smoke marker file in lib/ to confirm write access.\n2. Validate the change through review and completion.\n''';
  }

  String _spec() {
    return '''# Spec\n\n## Goal\nCreate a small smoke marker file in lib/.\n\n## Constraints\n- Keep changes minimal and deterministic.\n- Do not modify unrelated files.\n\n## Acceptance\n- A marker file exists in lib/.\n- Review approves the change.\n''';
  }

  String _subtasks() {
    return '''# Subtasks\n\n## Subtasks\n1. Create a smoke marker file in lib/.\n2. Ensure the marker is committed after review approval.\n''';
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}
