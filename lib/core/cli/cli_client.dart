// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'models/cli_models.dart';
import 'cli_exit_status.dart';
import 'cli_json_decoder.dart';
import 'cli_process_runner.dart';

class CliClientResult<T> {
  const CliClientResult({
    required this.status,
    required this.stdout,
    required this.stderr,
    required this.data,
    required this.error,
  });

  final CliExitStatus status;
  final String stdout;
  final String stderr;
  final T? data;
  final CliErrorResponse? error;

  bool get ok => status == CliExitStatus.success && data != null;
}

class CliCommandResult {
  const CliCommandResult({
    required this.status,
    required this.stdout,
    required this.stderr,
    required this.message,
  });

  final CliExitStatus status;
  final String stdout;
  final String stderr;
  final String message;

  bool get ok => status == CliExitStatus.success;
}

class CliClient {
  CliClient({CliProcessRunner? runner, CliJsonDecoder? decoder})
    : _runner = runner ?? CliProcessRunner(),
      _decoder = decoder ?? const CliJsonDecoder();

  final CliProcessRunner _runner;
  final CliJsonDecoder _decoder;

  Future<CliClientResult<CliStatusSnapshot>> status(String projectRoot) {
    return _runJson([
      'status',
      '--json',
      projectRoot,
    ], (json) => CliStatusSnapshot.fromJson(json));
  }

  Future<CliClientResult<CliTasksResponse>> tasks(
    String projectRoot, {
    List<String> options = const [],
  }) {
    return _runJson(
      _withJsonFlag(['tasks', ...options, projectRoot]),
      (json) => CliTasksResponse.fromJson(json),
    );
  }

  Future<CliClientResult<CliTaskItem>> next(
    String projectRoot, {
    List<String> options = const [],
  }) {
    return _runJson(
      _withJsonFlag(['next', ...options, projectRoot]),
      (json) => CliTaskItem.fromJson(json),
    );
  }

  Future<CliClientResult<CliReviewStatus>> reviewStatus(String projectRoot) {
    return _runJson([
      'review',
      'status',
      '--json',
      projectRoot,
    ], (json) => CliReviewStatus.fromJson(json));
  }

  Future<CliCommandResult> activate(
    String projectRoot, {
    String? id,
    String? title,
  }) {
    if (id != null && title != null) {
      throw ArgumentError('Use only one of id or title');
    }
    final args = <String>['activate'];
    if (id != null && id.trim().isNotEmpty) {
      args.addAll(['--id', id]);
    }
    if (title != null && title.trim().isNotEmpty) {
      args.addAll(['--title', title]);
    }
    args.add(projectRoot);
    return _runCommand(args);
  }

  Future<CliClientResult<CliActivateResponse>> activateJson(
    String projectRoot, {
    String? id,
    String? title,
  }) {
    if (id != null && title != null) {
      throw ArgumentError('Use only one of id or title');
    }
    final args = <String>['activate'];
    if (id != null && id.trim().isNotEmpty) {
      args.addAll(['--id', id]);
    }
    if (title != null && title.trim().isNotEmpty) {
      args.addAll(['--title', title]);
    }
    args.add(projectRoot);
    return _runJson(
      _withJsonFlag(args),
      (json) => CliActivateResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> deactivate(
    String projectRoot, {
    bool keepReview = false,
  }) {
    final args = <String>['deactivate'];
    if (keepReview) {
      args.add('--keep-review');
    }
    args.add(projectRoot);
    return _runCommand(args);
  }

  Future<CliClientResult<CliDeactivateResponse>> deactivateJson(
    String projectRoot, {
    bool keepReview = false,
  }) {
    final args = <String>['deactivate'];
    if (keepReview) {
      args.add('--keep-review');
    }
    args.add(projectRoot);
    return _runJson(
      _withJsonFlag(args),
      (json) => CliDeactivateResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> reviewApprove(String projectRoot, {String? note}) {
    return _runReviewDecision('approve', projectRoot, note: note);
  }

  Future<CliClientResult<CliReviewDecisionResponse>> reviewApproveJson(
    String projectRoot, {
    String? note,
  }) {
    return _runReviewDecisionJson(
      'approve',
      projectRoot,
      note: note,
      parser: (json) => CliReviewDecisionResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> reviewReject(String projectRoot, {String? note}) {
    return _runReviewDecision('reject', projectRoot, note: note);
  }

  Future<CliClientResult<CliReviewDecisionResponse>> reviewRejectJson(
    String projectRoot, {
    String? note,
  }) {
    return _runReviewDecisionJson(
      'reject',
      projectRoot,
      note: note,
      parser: (json) => CliReviewDecisionResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> reviewClear(String projectRoot, {String? note}) {
    return _runReviewDecision('clear', projectRoot, note: note);
  }

  Future<CliClientResult<CliReviewClearResponse>> reviewClearJson(
    String projectRoot, {
    String? note,
  }) {
    return _runReviewDecisionJson(
      'clear',
      projectRoot,
      note: note,
      parser: (json) => CliReviewClearResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> init(String projectRoot, {bool overwrite = false}) {
    final args = <String>['init'];
    if (overwrite) {
      args.add('--overwrite');
    }
    args.add(projectRoot);
    return _runCommand(args);
  }

  Future<CliClientResult<CliInitResponse>> initJson(
    String projectRoot, {
    bool overwrite = false,
  }) {
    final args = <String>['init'];
    if (overwrite) {
      args.add('--overwrite');
    }
    args.add(projectRoot);
    return _runJson(
      _withJsonFlag(args),
      (json) => CliInitResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> planInit(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _runSpecInit('plan', projectRoot, overwrite: overwrite);
  }

  Future<CliClientResult<CliPlanInitResponse>> planInitJson(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _runSpecInitJson(
      'plan',
      projectRoot,
      overwrite: overwrite,
      parser: (json) => CliPlanInitResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> specInit(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _runSpecInit('spec', projectRoot, overwrite: overwrite);
  }

  Future<CliClientResult<CliSpecInitResponse>> specInitJson(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _runSpecInitJson(
      'spec',
      projectRoot,
      overwrite: overwrite,
      parser: (json) => CliSpecInitResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> subtasksInit(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _runSpecInit('subtasks', projectRoot, overwrite: overwrite);
  }

  Future<CliClientResult<CliSubtasksInitResponse>> subtasksInitJson(
    String projectRoot, {
    bool overwrite = false,
  }) {
    return _runSpecInitJson(
      'subtasks',
      projectRoot,
      overwrite: overwrite,
      parser: (json) => CliSubtasksInitResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> done(String projectRoot) {
    return _runCommand(['done', projectRoot]);
  }

  Future<CliClientResult<CliDoneResponse>> doneJson(String projectRoot) {
    return _runJson(
      _withJsonFlag(['done', projectRoot]),
      (json) => CliDoneResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> block(String projectRoot, {String? reason}) {
    final args = <String>['block'];
    if (reason != null && reason.trim().isNotEmpty) {
      args.addAll(['--reason', reason]);
    }
    args.add(projectRoot);
    return _runCommand(args);
  }

  Future<CliClientResult<CliBlockResponse>> blockJson(
    String projectRoot, {
    String? reason,
  }) {
    final args = <String>['block'];
    if (reason != null && reason.trim().isNotEmpty) {
      args.addAll(['--reason', reason]);
    }
    args.add(projectRoot);
    return _runJson(
      _withJsonFlag(args),
      (json) => CliBlockResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> cycle(String projectRoot) {
    return _runCommand(['cycle', projectRoot]);
  }

  Future<CliClientResult<CliCycleResponse>> cycleJson(String projectRoot) {
    return _runJson(
      _withJsonFlag(['cycle', projectRoot]),
      (json) => CliCycleResponse.fromJson(json),
    );
  }

  Future<CliCommandResult> cycleRun(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) {
    final args = <String>['cycle', 'run', '--prompt', prompt];
    if (testSummary != null && testSummary.trim().isNotEmpty) {
      args.addAll(['--test-summary', testSummary]);
    }
    if (overwrite) {
      args.add('--overwrite');
    }
    args.add(projectRoot);
    return _runCommand(args);
  }

  Future<CliClientResult<CliCycleRunResponse>> cycleRunJson(
    String projectRoot, {
    required String prompt,
    String? testSummary,
    bool overwrite = false,
  }) {
    final args = <String>['cycle', 'run', '--prompt', prompt];
    if (testSummary != null && testSummary.trim().isNotEmpty) {
      args.addAll(['--test-summary', testSummary]);
    }
    if (overwrite) {
      args.add('--overwrite');
    }
    args.add(projectRoot);
    return _runJson(
      _withJsonFlag(args),
      (json) => CliCycleRunResponse.fromJson(json),
    );
  }

  Future<CliClientResult<T>> _runJson<T>(
    List<String> args,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final result = await _runner.run(args);
    final json = _decoder.decodeFirstJsonLine(result.stdout);
    final error = json == null ? null : CliErrorResponse.tryParse(json);
    final data = json == null || error != null ? null : parser(json);
    return CliClientResult<T>(
      status: result.status,
      stdout: result.stdout,
      stderr: result.stderr,
      data: data,
      error: error,
    );
  }

  Future<CliCommandResult> _runCommand(List<String> args) async {
    final result = await _runner.run(args);
    return CliCommandResult(
      status: result.status,
      stdout: result.stdout,
      stderr: result.stderr,
      message: _firstNonEmptyLine(result.stdout),
    );
  }

  Future<CliCommandResult> _runReviewDecision(
    String decision,
    String projectRoot, {
    String? note,
  }) {
    final args = <String>['review', decision];
    if (note != null && note.trim().isNotEmpty) {
      args.addAll(['--note', note]);
    }
    args.add(projectRoot);
    return _runCommand(args);
  }

  Future<CliClientResult<T>> _runReviewDecisionJson<T>(
    String decision,
    String projectRoot, {
    String? note,
    required T Function(Map<String, dynamic>) parser,
  }) {
    final args = <String>['review', decision];
    if (note != null && note.trim().isNotEmpty) {
      args.addAll(['--note', note]);
    }
    args.add(projectRoot);
    return _runJson(_withJsonFlag(args), parser);
  }

  Future<CliCommandResult> _runSpecInit(
    String kind,
    String projectRoot, {
    required bool overwrite,
  }) {
    final args = <String>[kind, 'init'];
    if (overwrite) {
      args.add('--overwrite');
    }
    args.add(projectRoot);
    return _runCommand(args);
  }

  Future<CliClientResult<T>> _runSpecInitJson<T>(
    String kind,
    String projectRoot, {
    required bool overwrite,
    required T Function(Map<String, dynamic>) parser,
  }) {
    final args = <String>[kind, 'init'];
    if (overwrite) {
      args.add('--overwrite');
    }
    args.add(projectRoot);
    return _runJson(_withJsonFlag(args), parser);
  }

  List<String> _withJsonFlag(List<String> args) {
    if (args.contains('--json')) {
      return args;
    }
    return [...args, '--json'];
  }

  String _firstNonEmptyLine(String output) {
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }
}
