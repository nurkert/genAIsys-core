// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import '../config/project_type.dart';
import '../config/quality_gate_profile.dart';
import '../git/git_service.dart';
import '../models/init_orchestration_context.dart';
import '../project_initializer.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';
import 'init_input_service.dart';
import 'init_orchestrator_service.dart';
import 'project_type_detection_service.dart';

class InitResult {
  InitResult({required this.root, required this.genaisysDir});

  final String root;
  final String genaisysDir;
}

class InitService {
  InitService({
    GitService? gitService,
    InitInputService? inputService,
    InitOrchestratorService? orchestratorService,
  }) : _gitService = gitService ?? GitService(),
       _inputService = inputService ?? InitInputService(),
       _orchestratorService =
           orchestratorService ?? InitOrchestratorService();

  final GitService _gitService;
  final InitInputService _inputService;
  final InitOrchestratorService _orchestratorService;

  /// Initializes (or re-initializes) the `.genaisys/` structure using static
  /// default templates.
  ///
  /// This method is synchronous and preserves full backward compatibility.
  /// To use the agent-driven orchestration pipeline, call [initializeFromSource].
  InitResult initialize(String projectRoot, {bool overwrite = false}) {
    final detectedType = ProjectTypeDetectionService().detect(projectRoot);

    // For Dart/Flutter projects, use legacy (null) profile for backward
    // compatibility. For all other types, use the language-specific profile.
    final QualityGateProfile? profile;
    if (detectedType == ProjectType.dartFlutter) {
      profile = null;
    } else {
      profile = QualityGateProfile.forProjectType(detectedType);
    }

    // Detect whether a git remote is configured. When no remote exists,
    // auto_push and auto_merge default to false to prevent delivery failures
    // on local-only repositories.
    final hasRemote = _detectRemote(projectRoot);

    final initializer = ProjectInitializer(projectRoot);
    initializer.ensureStructure(
      overwrite: overwrite,
      profile: profile,
      hasRemote: hasRemote,
    );

    final layout = ProjectLayout(projectRoot);
    final runLog = RunLogStore(layout.runLogPath);
    runLog.append(
      event: 'init',
      message: 'Initialized .genaisys structure',
      data: {
        'root': projectRoot,
        'overwrite': overwrite,
        'has_remote': hasRemote,
      },
    );
    runLog.append(
      event: 'detected_project_type',
      message: 'Detected project type: ${detectedType.configKey}',
      data: {'project_type': detectedType.configKey},
    );

    return InitResult(root: projectRoot, genaisysDir: layout.genaisysDir);
  }

  /// Initializes the project structure and then runs the 6-stage agent-driven
  /// orchestration pipeline using [fromSource] as input.
  ///
  /// When [staticMode] is `true`, the orchestration pipeline is skipped and
  /// only the static template init is performed (same as [initialize]).
  Future<InitResult> initializeFromSource(
    String projectRoot, {
    bool overwrite = false,
    required String fromSource,
    bool staticMode = false,
    int? sprintSize,
  }) async {
    // Static init always runs first to ensure the directory structure exists.
    final result = initialize(projectRoot, overwrite: overwrite);

    if (!staticMode) {
      final layout = ProjectLayout(projectRoot);
      final inputResult = _inputService.autoDetect(fromSource);
      final isReinit = _isReinit(layout);
      final runLog = RunLogStore(layout.runLogPath);
      runLog.append(
        event: 'init_orchestration_start',
        message: 'Starting agent-driven init orchestration',
        data: {
          'from_source': fromSource,
          'is_reinit': isReinit,
          'overwrite': overwrite,
        },
      );
      final ctx = InitOrchestrationContext(
        projectRoot: projectRoot,
        normalizedInputText: inputResult.normalizedText,
        inputSourcePayload: inputResult.sourcePayload,
        isReinit: isReinit,
        overwrite: overwrite,
        sprintSize: sprintSize ?? 8,
      );
      await _orchestratorService.run(projectRoot, ctx: ctx);
    }

    return result;
  }

  /// Returns true when a VISION.md already existed before this init call,
  /// indicating a re-initialization of an existing project.
  bool _isReinit(ProjectLayout layout) {
    try {
      return File(layout.visionPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  bool _detectRemote(String projectRoot) {
    try {
      if (!_gitService.isGitRepo(projectRoot)) {
        return false;
      }
      final remote = _gitService.defaultRemote(projectRoot);
      return remote != null && remote.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
