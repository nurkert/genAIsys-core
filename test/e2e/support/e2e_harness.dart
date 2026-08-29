import 'dart:io';

import 'package:genaisys/core/agents/agent_registry.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/agent_selector.dart';
import 'package:genaisys/core/git/git_service.dart';
import 'package:genaisys/core/models/project_state.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/task_management/activate_service.dart';
import 'package:genaisys/core/services/agent_context_service.dart';
import 'package:genaisys/core/services/architecture_planning_service.dart';
import 'package:genaisys/core/services/vision_evaluation_service.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/agents/analysis_agent_service.dart';
import 'package:genaisys/core/services/agents/coding_agent_service.dart';
import 'package:genaisys/core/services/pipeline_prompt_assembler.dart';
import 'package:genaisys/core/services/config_service.dart';
import 'package:genaisys/core/services/task_management/done_service.dart';
import 'package:genaisys/core/services/merge_conflict_resolver_service.dart';
import 'package:genaisys/core/services/orchestrator_step_service.dart';
import 'package:genaisys/core/services/agents/review_agent_service.dart';
import 'package:genaisys/core/services/review_bundle_service.dart';
import 'package:genaisys/core/services/review_service.dart';
import 'package:genaisys/core/services/agents/spec_agent_service.dart';
import 'package:genaisys/core/services/strategic_planner_service.dart';
import 'package:genaisys/core/services/task_cycle_service.dart';
import 'package:genaisys/core/services/task_management/task_pipeline_service.dart';
import 'package:genaisys/core/services/task_management/active_task_resolver.dart';
import 'package:genaisys/core/services/vision_backlog_planner_service.dart';
import 'package:genaisys/core/storage/atomic_file_write.dart';
import 'package:genaisys/core/storage/state_store.dart';
import 'package:genaisys/core/storage/task_store.dart';

/// Reusable E2E test harness that creates a real temp project with git,
/// .genaisys/ structure, and configurable stub agents.
///
/// Modelled after [AutopilotSmokeCheckService] — same init, git, and service
/// hierarchy wiring.
///
/// Usage:
/// ```dart
/// final harness = await E2EHarness.create(agentRunner: SuccessAgent(...));
/// harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] My task\n');
/// final result = await harness.runAutopilotStep();
/// // assert on result
/// harness.dispose();
/// ```
class E2EHarness {
  E2EHarness._({
    required this.projectRoot,
    required this.layout,
    required OrchestratorStepService stepService,
    required this.maxReviewRetries,
  }) : _stepService = stepService;

  final String projectRoot;
  final ProjectLayout layout;
  final OrchestratorStepService _stepService;

  /// Configured max review retries for this harness instance.
  final int maxReviewRetries;

  /// Creates a fully initialised E2E harness:
  /// 1. Temp directory with git init + bare remote
  /// 2. .genaisys/ with config.yml, TASKS.md, STATE.json
  /// 3. Shell allowlist configured for stub agents
  /// 4. Full service hierarchy wired with the given [agentRunner]
  ///
  /// For provider failover tests, pass [fallbackRunner] to register a
  /// separate agent on the gemini slot.
  static Future<E2EHarness> create({
    required AgentRunner agentRunner,
    AgentRunner? fallbackRunner,
    String prefix = 'genaisys_e2e_',
    bool qualityGateEnabled = false,
    List<String>? qualityGateCommands,
    int? autopilotMaxFailures,
    int maxReviewRetries = 3,
  }) async {
    final temp = Directory.systemTemp.createTempSync(prefix);
    final root = temp.path;

    // 1. Initialise project structure.
    ProjectInitializer(root).ensureStructure(overwrite: true);

    // 2. Git init with bare remote (same as smoke check).
    _initGit(root);

    // 3. Configure shell allowlist + quality gate.
    ConfigService().update(
      root,
      update: ConfigUpdate(
        qualityGateEnabled: qualityGateEnabled,
        qualityGateCommands: qualityGateCommands,
        shellAllowlistProfile: 'custom',
        shellAllowlist: ['e2e-stub-agent'],
        autopilotMaxFailures: autopilotMaxFailures,
      ),
    );

    // 4. Commit bootstrap artifacts.
    _commitBootstrapArtifacts(root);

    // 4b. Create autopilot lock file so services recognise unattended mode.
    // This is needed for normalizeAfterReject to stash dirty worktree state
    // instead of leaving it for manual resolution.
    _createAutopilotLock(root);

    // 5. Build full service hierarchy.
    final agentService = _buildAgentService(
      root,
      primaryRunner: agentRunner,
      fallbackRunner: fallbackRunner,
    );
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
      maxReviewRetries: maxReviewRetries,
    );

    final planner = VisionBacklogPlannerService(
      strategicPlanner: StrategicPlannerService(agentService: agentService),
    );

    final stepService = OrchestratorStepService(
      activateService: ActivateService(gitService: gitService),
      taskCycleService: cycle,
      plannerService: planner,
      architecturePlanningService: _NoopArchitecturePlanningService(),
      visionEvaluationService: _NoopVisionEvaluationService(),
      gitService: gitService,
      specAgentService: SpecAgentService(agentService: agentService),
    );

    return E2EHarness._(
      projectRoot: root,
      layout: ProjectLayout(root),
      stepService: stepService,
      maxReviewRetries: maxReviewRetries,
    );
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Runs one full orchestrator step (activate → code → review → done).
  Future<OrchestratorStepResult> runAutopilotStep({
    String codingPrompt = 'Implement the task.',
    String? testSummary,
  }) {
    return _stepService.run(
      projectRoot,
      codingPrompt: codingPrompt,
      testSummary: testSummary ?? 'E2E test evidence.',
      overwriteArtifacts: true,
      minOpenTasks: 1,
      maxPlanAdd: 1,
    );
  }

  /// Runs up to [maxSteps] orchestrator steps sequentially, collecting
  /// results. Stops early if no cycle was executed (idle / safety halt).
  Future<List<OrchestratorStepResult>> runAutopilotLoop({
    required int maxSteps,
    String codingPrompt = 'Implement the task.',
    String? testSummary,
  }) async {
    final results = <OrchestratorStepResult>[];
    for (var i = 0; i < maxSteps; i++) {
      try {
        final result = await runAutopilotStep(
          codingPrompt: codingPrompt,
          testSummary: testSummary,
        );
        results.add(result);
        if (!result.executedCycle) {
          break; // Idle — no more tasks to execute.
        }
      } catch (_) {
        // Step failed (e.g. agent crash propagated). Count as an executed
        // step for safety halt purposes but stop the loop.
        break;
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // State readers
  // ---------------------------------------------------------------------------

  ProjectState readState() => StateStore(layout.statePath).read();

  List<Task> readTasks() => TaskStore(layout.tasksPath).readTasks();

  String readRunLog() {
    final file = File(layout.runLogPath);
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  // ---------------------------------------------------------------------------
  // Seeding
  // ---------------------------------------------------------------------------

  /// Overwrites TASKS.md with the given markdown and commits the change.
  ///
  /// The [markdown] should contain task lines (e.g., `- [ ] [P1] [CORE] ...`).
  /// This method automatically prepends `# Tasks\n\n` if the markdown does
  /// not already start with `# Tasks`, as required by the schema validator.
  void seedTasks(String markdown) {
    final normalized = markdown.trimLeft().startsWith('# Tasks')
        ? markdown
        : '# Tasks\n\n$markdown';
    AtomicFileWrite.writeStringSync(layout.tasksPath, normalized);
    _commitIfDirty(projectRoot, 'chore: seed tasks for E2E scenario');
  }

  // ---------------------------------------------------------------------------
  // Git helpers
  // ---------------------------------------------------------------------------

  int gitCommitCount() {
    final result = Process.runSync('git', [
      'rev-list',
      '--count',
      'HEAD',
    ], workingDirectory: projectRoot);
    if (result.exitCode != 0) return 0;
    return int.tryParse(result.stdout.toString().trim()) ?? 0;
  }

  bool isTaskDone(String title) {
    for (final task in readTasks()) {
      if (task.title == title) {
        return task.completion == TaskCompletion.done;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void dispose() {
    final dir = Directory(projectRoot);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Private: git init (mirrors AutopilotSmokeCheckService._initGit)
  // ---------------------------------------------------------------------------

  static void _initGit(String root) {
    _runGit(root, ['init', '-b', 'main']);
    _runGit(root, ['config', 'user.email', 'e2e@genaisys.local']);
    _runGit(root, ['config', 'user.name', 'Genaisys E2E']);

    File(
      _join(root, '.gitignore'),
    ).writeAsStringSync('.genaisys/\n.remote.git/\n');
    Directory(_join(root, 'lib')).createSync(recursive: true);
    File(_join(root, 'README.md')).writeAsStringSync('# E2E Project\n');
    File(
      _join(root, 'lib/e2e_marker.txt'),
    ).writeAsStringSync('E2E marker file.\n');
    File(_join(root, 'lib/.keep')).writeAsStringSync('');

    _runGit(root, ['add', '-A']);
    _runGit(root, ['commit', '--no-gpg-sign', '-m', 'chore: init E2E project']);

    // Bare remote for delivery preflight.
    _runGit(root, ['init', '--bare', '.remote.git']);
    _runGit(root, ['remote', 'add', 'origin', _join(root, '.remote.git')]);
    _runGit(root, ['push', '-u', 'origin', 'main']);
  }

  static void _commitBootstrapArtifacts(String root) {
    _runGit(root, ['add', '-A']);
    final status = Process.runSync('git', [
      'status',
      '--porcelain',
    ], workingDirectory: root);
    if (status.exitCode != 0) {
      final stderr = status.stderr.toString().trim();
      throw StateError(
        stderr.isNotEmpty ? stderr : 'Failed to inspect E2E repo status.',
      );
    }
    if (status.stdout.toString().trim().isEmpty) return;

    _runGit(root, [
      'commit',
      '--no-gpg-sign',
      '-m',
      'chore: bootstrap genaisys E2E artifacts',
    ]);
    _runGit(root, ['push']);
  }

  static void _commitIfDirty(String root, String message) {
    _runGit(root, ['add', '-A']);
    final status = Process.runSync('git', [
      'status',
      '--porcelain',
    ], workingDirectory: root);
    if (status.stdout.toString().trim().isEmpty) return;
    _runGit(root, ['commit', '--no-gpg-sign', '-m', message]);
    _runGit(root, ['push']);
  }

  // ---------------------------------------------------------------------------
  // Private: service wiring
  // ---------------------------------------------------------------------------

  static AgentService _buildAgentService(
    String root, {
    required AgentRunner primaryRunner,
    AgentRunner? fallbackRunner,
  }) {
    // Register stubs for ALL 5 provider slots so the default config pool
    // (codex, gemini, claude-code) never resolves to a real CLI runner.
    final stub = fallbackRunner ?? primaryRunner;
    final registry = AgentRegistry(
      codex: primaryRunner,
      gemini: stub,
      claudeCode: stub,
      vibe: stub,
      amp: stub,
    );
    final selector = AgentSelector(registry: registry);
    return AgentService(selector: selector);
  }

  // ---------------------------------------------------------------------------
  // Private: autopilot lock (unattended mode simulation)
  // ---------------------------------------------------------------------------

  static void _createAutopilotLock(String root) {
    final layout = ProjectLayout(root);
    final lockDir = Directory(layout.locksDir);
    lockDir.createSync(recursive: true);
    final lockFile = File(layout.autopilotLockPath);
    final currentPid = pid;
    final startedAt = DateTime.now().toUtc().toIso8601String();
    lockFile.writeAsStringSync(
      '{"pid":$currentPid,"started_at":"$startedAt","heartbeat":"$startedAt"}',
    );
  }

  // ---------------------------------------------------------------------------
  // Private: git/path utilities
  // ---------------------------------------------------------------------------

  static void _runGit(String root, List<String> args) {
    final result = Process.runSync('git', args, workingDirectory: root);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      final message = stderr.isNotEmpty
          ? stderr
          : "git ${args.join(' ')} failed with exit ${result.exitCode}";
      throw StateError(message);
    }
  }

  static String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}

class _NoopArchitecturePlanningService extends ArchitecturePlanningService {
  @override
  Future<ArchitecturePlanningResult?> planArchitecture(
    String projectRoot,
  ) async {
    return null;
  }
}

class _NoopVisionEvaluationService extends VisionEvaluationService {
  @override
  Future<VisionEvaluationResult?> evaluate(String projectRoot) async {
    return null;
  }
}
