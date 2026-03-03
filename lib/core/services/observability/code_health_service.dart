// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../../config/project_config.dart';
import '../../models/code_health_models.dart';
import '../../models/task.dart';
import '../../project_layout.dart';
import '../../storage/health_ledger_store.dart';
import '../../storage/run_log_store.dart';
import '../../storage/task_store.dart';
import '../code_health_reflection_service.dart';
import '../deja_vu_detector_service.dart';
import '../static_code_metrics_service.dart';
import '../task_management/task_write_service.dart';

/// Composes Layer 1 (static metrics) + Layer 2 (deja-vu) + Layer 3
/// (architecture reflection) + policy engine.
///
/// Runs after each successful task delivery to detect code health issues
/// and optionally create refactoring tasks.
class CodeHealthService {
  CodeHealthService({
    StaticCodeMetricsService? staticMetrics,
    DejaVuDetectorService? dejaVu,
    CodeHealthReflectionService? reflection,
    TaskWriteService? taskWriteService,
    HealthLedgerStore? ledgerStore,
  }) : _staticMetrics = staticMetrics ?? StaticCodeMetricsService(),
       _dejaVu = dejaVu,
       _reflection = reflection,
       _taskWriteService = taskWriteService ?? TaskWriteService(),
       _externalLedgerStore = ledgerStore;

  final StaticCodeMetricsService _staticMetrics;
  final DejaVuDetectorService? _dejaVu;
  final CodeHealthReflectionService? _reflection;
  final TaskWriteService _taskWriteService;
  final HealthLedgerStore? _externalLedgerStore;

  /// Evaluate code health after a delivery.
  ///
  /// Returns a report with signals, confidence, and whether a task was created.
  Future<CodeHealthReport> evaluateDelivery(
    String projectRoot, {
    required List<String> touchedFiles,
    required String? taskId,
    required String? taskTitle,
    required ProjectConfig config,
  }) async {
    if (!config.codeHealthEnabled) {
      return CodeHealthReport.empty;
    }

    if (touchedFiles.isEmpty) {
      return CodeHealthReport.empty;
    }

    final layout = ProjectLayout(projectRoot);
    final ledgerStore =
        _externalLedgerStore ?? HealthLedgerStore(layout.healthLedgerPath);
    final runLogStore = RunLogStore(layout.runLogPath);

    // Layer 1: Static metrics on touched files.
    final metrics = _staticMetrics.analyze(projectRoot, touchedFiles);

    // Record to ledger.
    ledgerStore.append(
      DeliveryHealthEntry(
        taskId: taskId,
        taskTitle: taskTitle,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        files: metrics,
      ),
    );

    final layer1Signals = _staticMetrics.evaluate(
      metrics,
      maxFileLines: config.codeHealthMaxFileLines,
      maxMethodLines: config.codeHealthMaxMethodLines,
      maxNestingDepth: config.codeHealthMaxNestingDepth,
      maxParameterCount: config.codeHealthMaxParameterCount,
    );

    // Layer 2: Deja-vu detection.
    final dejaVuService =
        _dejaVu ?? DejaVuDetectorService(ledgerStore: ledgerStore);
    final layer2Signals = dejaVuService.detect(
      projectRoot,
      windowSize: config.codeHealthHotspotWindow,
      hotspotThreshold: config.codeHealthHotspotThreshold,
      patchClusterMin: config.codeHealthPatchClusterMin,
    );

    // Layer 3: Architecture Reflection (LLM).
    var layer3Signals = const <CodeHealthSignal>[];
    if (layer2Signals.isNotEmpty && config.codeHealthReflectionEnabled) {
      try {
        final reflectionService = _reflection ?? CodeHealthReflectionService();
        layer3Signals = await reflectionService.reflect(
          projectRoot,
          triggeringSignals: [...layer1Signals, ...layer2Signals],
          config: config,
        );
      } catch (_) {
        // Best-effort: don't block health evaluation on LLM failure.
      }
    }

    // Combine signals.
    final allSignals = [...layer1Signals, ...layer2Signals, ...layer3Signals];

    if (allSignals.isEmpty) {
      _emitRunLogEvent(runLogStore, taskId: taskId, signalCount: 0);
      return CodeHealthReport.empty;
    }

    // Compute combined confidence and priority.
    final layersWithSignals = <HealthSignalLayer>{};
    var maxConfidence = 0.0;
    for (final signal in allSignals) {
      layersWithSignals.add(signal.layer);
      if (signal.confidence > maxConfidence) {
        maxConfidence = signal.confidence;
      }
    }

    final combinedConfidence = maxConfidence;
    final priority = _computePriority(layersWithSignals, maxConfidence);

    // Policy: check if we should create a task.
    final shouldCreate = _shouldCreateTask(
      config: config,
      combinedConfidence: combinedConfidence,
      priority: priority,
      projectRoot: projectRoot,
    );

    if (shouldCreate && config.codeHealthAutoCreateTasks) {
      _createRefactoringTask(
        projectRoot,
        signals: allSignals,
        priority: priority,
      );
    }

    _emitRunLogEvent(
      runLogStore,
      taskId: taskId,
      signalCount: allSignals.length,
      combinedConfidence: combinedConfidence,
      priority: priority,
      taskCreated: shouldCreate && config.codeHealthAutoCreateTasks,
    );

    return CodeHealthReport(
      signals: allSignals,
      combinedConfidence: combinedConfidence,
      recommendedPriority: priority,
      shouldCreateTask: shouldCreate,
    );
  }

  /// Confidence → Priority mapping.
  static TaskPriority _computePriority(
    Set<HealthSignalLayer> layersWithSignals,
    double maxConfidence,
  ) {
    // 2+ layers with signals → P1.
    if (layersWithSignals.length >= 2) return TaskPriority.p1;
    // 1 layer with confidence ≥ 0.7 → P2.
    if (maxConfidence >= 0.7) return TaskPriority.p2;
    // Otherwise → P3.
    return TaskPriority.p3;
  }

  bool _shouldCreateTask({
    required ProjectConfig config,
    required double combinedConfidence,
    required TaskPriority priority,
    required String projectRoot,
  }) {
    // Below minimum confidence → log only.
    if (combinedConfidence < config.codeHealthMinConfidence) {
      return false;
    }

    // Check refactor ratio cap against current backlog.
    try {
      final layout = ProjectLayout(projectRoot);
      final tasks = TaskStore(layout.tasksPath).readTasks();
      final openTasks = tasks.where((t) => t.completion == TaskCompletion.open);
      final refactorTasks = openTasks.where(
        (t) => t.category == TaskCategory.refactor,
      );
      final total = openTasks.length;
      if (total > 0) {
        final ratio = refactorTasks.length / total;
        if (ratio >= config.codeHealthMaxRefactorRatio) {
          return false;
        }
      }
    } catch (_) {
      // Best-effort: if we can't read tasks, don't block on it.
    }

    return true;
  }

  void _createRefactoringTask(
    String projectRoot, {
    required List<CodeHealthSignal> signals,
    required TaskPriority priority,
  }) {
    final affectedFiles = <String>{};
    for (final signal in signals) {
      affectedFiles.addAll(signal.affectedFiles);
    }
    final fileList = affectedFiles.take(5).join(', ');
    final title =
        'Refactor code health issues in $fileList'
        '${affectedFiles.length > 5 ? ' and ${affectedFiles.length - 5} more' : ''}';

    try {
      _taskWriteService.createTask(
        projectRoot,
        title: title,
        priority: priority,
        category: TaskCategory.refactor,
      );
    } on StateError {
      // Duplicate task — expected if similar signals were already detected.
    }
  }

  void _emitRunLogEvent(
    RunLogStore runLogStore, {
    String? taskId,
    required int signalCount,
    double? combinedConfidence,
    TaskPriority? priority,
    bool taskCreated = false,
  }) {
    runLogStore.append(
      event: 'code_health_evaluation',
      data: <String, Object?>{
        'task_id': ?taskId,
        'signal_count': signalCount,
        'combined_confidence': ?combinedConfidence,
        if (priority != null) 'recommended_priority': priority.name,
        'task_created': taskCreated,
      },
    );
  }
}
