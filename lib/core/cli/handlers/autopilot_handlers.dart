// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

extension _CliRunnerAutopilotHandlers on CliRunner {
  Future<void> _handleAutopilotStep(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final prompt =
        _readOptionValue(options, '--prompt') ??
        'Advance the roadmap with one minimal, safe, production-grade step.';
    final testSummary = _readOptionValue(options, '--test-summary');
    final overwrite = options.contains('--overwrite');
    final minOpen = _parsePositiveIntOrNull(
      _readOptionValue(options, '--min-open'),
    );
    final maxPlanAdd = _parsePositiveIntOrNull(
      _readOptionValue(options, '--max-plan-add'),
    );

    final result = await _autopilotStep.run(
      root,
      prompt: prompt,
      testSummary: testSummary,
      overwrite: overwrite,
      minOpen: minOpen,
      maxPlanAdd: maxPlanAdd,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotStep(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotStep(this.stdout, data);
  }

  Future<void> _handleAutopilotRun(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final followLogs = !asJson && !options.contains('--quiet');

    final prompt =
        _readOptionValue(options, '--prompt') ??
        'Advance the roadmap with one minimal, safe, production-grade step.';
    final testSummary = _readOptionValue(options, '--test-summary');
    final overwrite = options.contains('--overwrite');
    final stopWhenIdle = options.contains('--stop-when-idle');
    final overrideSafety = options.contains('--override-safety');

    final minOpen = _parsePositiveIntOrNull(
      _readOptionValue(options, '--min-open'),
    );
    final maxPlanAdd = _parsePositiveIntOrNull(
      _readOptionValue(options, '--max-plan-add'),
    );
    final stepSleepSeconds = _parseNonNegativeIntOrNull(
      _readOptionValue(options, '--step-sleep'),
    );
    final idleSleepSeconds = _parseNonNegativeIntOrNull(
      _readOptionValue(options, '--idle-sleep'),
    );
    final maxFailures = _parsePositiveIntOrNull(
      _readOptionValue(options, '--max-failures'),
    );
    final maxTaskRetries = _parsePositiveIntOrNull(
      _readOptionValue(options, '--max-task-retries'),
    );

    final maxStepsValue = _readOptionValue(options, '--max-steps');
    int? maxSteps;
    if (maxStepsValue != null && maxStepsValue.trim().isNotEmpty) {
      final parsed = int.tryParse(maxStepsValue.trim());
      if (parsed == null || parsed < 1) {
        if (asJson) {
          _writeJsonError(
            code: 'invalid_option',
            message: 'Invalid --max-steps value: $maxStepsValue',
          );
        } else {
          this.stderr.writeln('Invalid --max-steps value: $maxStepsValue');
        }
        exitCode = 64;
        return;
      }
      maxSteps = parsed;
    }

    RunLogTailer? tailer;
    if (followLogs) {
      tailer = RunLogTailer(root, out: this.stdout, output: _cliOutput);
      tailer.start();
    }

    AppResult<AutopilotRunDto> result;
    try {
      result = await _autopilotRun.run(
        root,
        prompt: prompt,
        testSummary: testSummary,
        overwrite: overwrite,
        minOpen: minOpen,
        maxPlanAdd: maxPlanAdd,
        stepSleep: stepSleepSeconds == null
            ? null
            : Duration(seconds: stepSleepSeconds),
        idleSleep: idleSleepSeconds == null
            ? null
            : Duration(seconds: idleSleepSeconds),
        maxSteps: maxSteps,
        stopWhenIdle: stopWhenIdle,
        maxFailures: maxFailures,
        maxTaskRetries: maxTaskRetries,
        overrideSafety: overrideSafety,
      );
    } finally {
      if (tailer != null) {
        await tailer.stop();
      }
    }

    if (!result.ok) {
      final error = result.error;
      if (error != null && error.kind == AppErrorKind.invalidInput) {
        if (asJson) {
          _writeJsonError(code: 'invalid_option', message: error.message);
        } else {
          this.stderr.writeln(error.message);
        }
        exitCode = 64;
        return;
      }
    }

    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotRun(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotRun(this.stdout, data);
  }

  Future<void> _handleAutopilotCandidate(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final skipSuites = options.contains('--skip-suites');

    final result = await _autopilotCandidate.run(root, skipSuites: skipSuites);
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotCandidate(this.stdout, data);
      if (!data.passed) {
        exitCode = 1;
      }
      return;
    }
    _textPresenter.writeAutopilotCandidate(this.stdout, data);
    if (!data.passed) {
      exitCode = 1;
    }
  }

  Future<void> _handleAutopilotPilot(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final durationValue =
        _readOptionValue(options, '--duration')?.trim() ?? '2h';
    final duration = _parseDurationOrNull(durationValue);
    if (duration == null || duration.inSeconds < 1) {
      if (asJson) {
        _writeJsonError(
          code: 'invalid_option',
          message: 'Invalid --duration value: $durationValue',
        );
      } else {
        this.stderr.writeln('Invalid --duration value: $durationValue');
      }
      exitCode = 64;
      return;
    }

    final maxCyclesValue =
        _readOptionValue(options, '--max-cycles')?.trim() ?? '120';
    final maxCycles = int.tryParse(maxCyclesValue);
    if (maxCycles == null || maxCycles < 1) {
      if (asJson) {
        _writeJsonError(
          code: 'invalid_option',
          message: 'Invalid --max-cycles value: $maxCyclesValue',
        );
      } else {
        this.stderr.writeln('Invalid --max-cycles value: $maxCyclesValue');
      }
      exitCode = 64;
      return;
    }

    final branch = _readOptionValue(options, '--branch');
    final prompt = _readOptionValue(options, '--prompt');
    final skipCandidate = options.contains('--skip-candidate');
    final autoFixFormatDrift = options.contains('--auto-fix-format-drift');

    final result = await _autopilotPilot.run(
      root,
      duration: duration,
      maxCycles: maxCycles,
      branch: branch,
      prompt: prompt,
      skipCandidate: skipCandidate,
      autoFixFormatDrift: autoFixFormatDrift,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotPilot(this.stdout, data);
      if (!data.passed) {
        exitCode = 1;
      }
      return;
    }
    _textPresenter.writeAutopilotPilot(this.stdout, data);
    if (!data.passed) {
      exitCode = 1;
    }
  }

  Future<void> _handleAutopilotCleanupBranches(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final baseBranch = _readOptionValue(options, '--base');
    final remote = _readOptionValue(options, '--remote');
    final includeRemote = options.contains('--include-remote');
    final dryRun = options.contains('--dry-run');

    final result = await _autopilotCleanupBranches.run(
      root,
      baseBranch: baseBranch,
      remote: remote,
      includeRemote: includeRemote,
      dryRun: dryRun,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotBranchCleanup(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotBranchCleanup(this.stdout, data);
  }

  Future<void> _handleAutopilotFollow(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    if (asJson) {
      _writeJsonError(
        code: 'invalid_option',
        message: '--json is not supported for autopilot follow',
      );
      exitCode = 64;
      return;
    }

    final intervalRaw = _readOptionValue(options, '--status-interval');
    var interval = 5;
    if (intervalRaw != null && intervalRaw.trim().isNotEmpty) {
      final parsed = int.tryParse(intervalRaw.trim());
      if (parsed == null || parsed < 1) {
        this.stderr.writeln('Invalid --status-interval value: $intervalRaw');
        exitCode = 64;
        return;
      }
      interval = parsed;
    }

    final tailer = RunLogTailer(root, out: this.stdout, output: _cliOutput);
    tailer.start();

    final stopSignal = Completer<void>();
    void requestStop([int? code]) {
      if (stopSignal.isCompleted) {
        return;
      }
      if (code != null) {
        exitCode = code;
      }
      stopSignal.complete();
    }

    StreamSubscription? sigintSub;
    sigintSub = ProcessSignal.sigint.watch().listen((_) {
      requestStop(0);
    });

    Timer? statusTimer;
    Future<void> emitStatus() async {
      final result = await _autopilotStatus.load(root);
      if (!result.ok || result.data == null) {
        this.stderr.writeln(
          'Failed to load autopilot status: ${result.error?.message ?? 'unknown error'}',
        );
        requestStop(1);
        return;
      }
      _writeFollowStatus(this.stdout, result.data!);
    }

    await emitStatus();
    if (!stopSignal.isCompleted) {
      statusTimer = Timer.periodic(
        Duration(seconds: interval),
        (_) => emitStatus(),
      );
    }

    await stopSignal.future;
    statusTimer?.cancel();
    await tailer.stop();
    await sigintSub.cancel();
  }

  void _writeFollowStatus(IOSink out, AutopilotStatusDto dto) {
    writeCliFollowStatus(out, dto, output: _cliOutput);
  }

  Future<void> _handleAutopilotStop(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');

    final result = await _autopilotStop.run(root);
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotStop(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotStop(this.stdout, data);
  }

  Future<void> _handleAutopilotSmoke(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final asJson = options.contains('--json');
    final keepProject = !options.contains('--cleanup');

    final result = await _autopilotSmoke.run(keepProject: keepProject);
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotSmoke(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotSmoke(this.stdout, data);
  }

  Future<void> _handleAutopilotSimulate(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final showPatch = options.contains('--show-patch');
    final keepWorkspace = options.contains('--keep-workspace');

    final prompt =
        _readOptionValue(options, '--prompt') ??
        'Advance the roadmap with one minimal, safe, production-grade step.';
    final testSummary = _readOptionValue(options, '--test-summary');
    final overwrite = options.contains('--overwrite');
    final minOpen = _parsePositiveIntOrNull(
      _readOptionValue(options, '--min-open'),
    );
    final maxPlanAdd = _parsePositiveIntOrNull(
      _readOptionValue(options, '--max-plan-add'),
    );

    final result = await _autopilotSimulation.run(
      root,
      prompt: prompt,
      testSummary: testSummary,
      overwrite: overwrite,
      minOpen: minOpen,
      maxPlanAdd: maxPlanAdd,
      keepWorkspace: keepWorkspace,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotSimulation(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotSimulation(
      this.stdout,
      data,
      showPatch: showPatch,
    );
  }

  Future<void> _handleAutopilotImprove(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final runMeta = !options.contains('--no-meta');
    final runEval = !options.contains('--no-eval');
    final runTune = !options.contains('--no-tune');
    final keepWorkspaces = options.contains('--keep-workspaces');

    final result = await _autopilotImprove.run(
      root,
      runMeta: runMeta,
      runEval: runEval,
      runTune: runTune,
      keepWorkspaces: keepWorkspaces,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotImprove(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotImprove(this.stdout, data);
  }

  Future<void> _handleAutopilotHeal(List<String> options) async {
    if (_wantsHelp(options)) {
      _printHelp();
      return;
    }
    final path = _extractPath(options);
    final root = _resolveRoot(path);
    final asJson = options.contains('--json');
    final reason = _readOptionValue(options, '--reason') ?? 'unknown';
    final detail = _readOptionValue(options, '--detail');
    final prompt = _readOptionValue(options, '--prompt');
    final overwrite = options.contains('--overwrite');
    final minOpen = _parsePositiveIntOrNull(
      _readOptionValue(options, '--min-open'),
    );
    final maxPlanAdd = _parsePositiveIntOrNull(
      _readOptionValue(options, '--max-plan-add'),
    );
    final maxTaskRetries = _parsePositiveIntOrNull(
      _readOptionValue(options, '--max-task-retries'),
    );

    final result = await _autopilotHeal.run(
      root,
      reason: reason,
      detail: detail,
      prompt: prompt,
      overwrite: overwrite,
      minOpen: minOpen,
      maxPlanAdd: maxPlanAdd,
      maxTaskRetries: maxTaskRetries,
    );
    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeAutopilotHeal(this.stdout, data);
      return;
    }
    _textPresenter.writeAutopilotHeal(this.stdout, data);
  }
}
