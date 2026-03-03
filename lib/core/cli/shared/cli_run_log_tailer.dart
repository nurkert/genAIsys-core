// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../output/cli_output.dart';
import '../../project_layout.dart';

/// Tails the run-log file and emits formatted lines to [out].
///
/// Used by `autopilot run --follow` and `autopilot follow` to stream
/// important orchestrator events to the terminal in real time.
class RunLogTailer {
  RunLogTailer(
    this.projectRoot, {
    required this.out,
    CliOutput? output,
  }) : output = output ?? CliOutput.plain;

  final String projectRoot;
  final IOSink out;
  final CliOutput output;
  Timer? _timer;
  int _offset = 0;
  String _buffer = '';
  bool _running = false;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _offset = _fileExists ? _fileLength : 0;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _poll();
    });
  }

  Future<void> stop() async {
    if (!_running) {
      return;
    }
    _running = false;
    _timer?.cancel();
    await _poll(flush: true);
  }

  String get _logPath => ProjectLayout(projectRoot).runLogPath;

  bool get _fileExists => File(_logPath).existsSync();

  int get _fileLength {
    try {
      return File(_logPath).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _poll({bool flush = false}) async {
    if (!_fileExists) {
      return;
    }
    final length = _fileLength;
    if (length <= _offset) {
      if (flush && _buffer.isNotEmpty) {
        _emit(_buffer.trim());
        _buffer = '';
      }
      return;
    }
    RandomAccessFile? raf;
    try {
      raf = File(_logPath).openSync(mode: FileMode.read);
      raf.setPositionSync(_offset);
      final bytes = raf.readSync(length - _offset);
      _offset = length;
      final chunk = utf8.decode(bytes);
      _buffer += chunk;
      final lines = _buffer.split('\n');
      if (!flush && lines.isNotEmpty) {
        _buffer = lines.removeLast();
      } else {
        _buffer = '';
      }
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        _emit(_formatLine(trimmed));
      }
    } catch (_) {
      // Ignore transient read errors.
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
  }

  void _emit(String? line) {
    if (line == null || line.isEmpty) {
      return;
    }
    out.writeln(line);
  }

  /// Returns `null` for events that should be filtered out.
  String? _formatLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return null;
      }

      final event = decoded['event']?.toString() ?? '';
      if (!output.isImportantEvent(event)) {
        return null;
      }

      final rawTs = decoded['timestamp']?.toString() ?? '';
      final ts = rawTs.isNotEmpty ? _parseTs(rawTs) : '';
      final message = decoded['message']?.toString() ?? '';

      final raw = decoded['data'];
      final dataMap = raw is Map ? raw : const <Object?, Object?>{};

      final stepIndex = dataMap['step_index']?.toString();
      final taskTitle = dataMap['task_id']?.toString() ??
          dataMap['task_title']?.toString() ??
          message;
      final agent = dataMap['agent']?.toString() ?? '';
      final decision = dataMap['decision']?.toString() ?? '';
      final branch = dataMap['branch']?.toString() ?? '';
      final outcome = dataMap['outcome']?.toString() ?? '';
      final reason = dataMap['reason']?.toString() ??
          dataMap['error_kind']?.toString() ??
          '';

      // HITL events need raw data map access — handle before general dispatch.
      if (event == 'hitl_gate_opened' || event == 'hitl_gate_resolved') {
        final pfx = ts.isEmpty ? '' : '$ts  ';
        final gateEvt = dataMap['event']?.toString() ?? '';
        final gateDecision = dataMap['decision']?.toString() ?? '';
        if (output.isRich) {
          if (event == 'hitl_gate_opened') {
            return '$pfx${output.yellow('⏸')}  ${output.bold('HITL')}  awaiting decision  $gateEvt';
          } else {
            return '$pfx${output.green('▶')}  ${output.bold('HITL')}  decision: $gateDecision';
          }
        } else {
          if (event == 'hitl_gate_opened') {
            return '${pfx}hitl.gate_open   event=$gateEvt';
          } else {
            return '${pfx}hitl.gate_done   decision=$gateDecision';
          }
        }
      }

      return output.isRich
          ? _formatRich(
              ts,
              event,
              stepIndex,
              taskTitle,
              agent,
              decision,
              branch,
              outcome,
              reason,
            )
          : _formatLog(
              ts,
              event,
              stepIndex,
              taskTitle,
              agent,
              decision,
              branch,
              outcome,
              reason,
            );
    } catch (_) {
      return null;
    }
  }

  String? _formatRich(
    String ts,
    String event,
    String? step,
    String task,
    String agent,
    String decision,
    String branch,
    String outcome,
    String reason,
  ) {
    final prefix = ts.isEmpty ? '' : '$ts  ';
    switch (event) {
      case 'orchestrator_run_step_start':
        final stepPart = step != null ? 'step $step  ${output.bullet}  ' : '';
        final agentPart = agent.isNotEmpty ? '  ${output.dim(agent)}' : '';
        return '$prefix${output.run}  $stepPart$task$agentPart';
      case 'orchestrator_run_step_outcome':
        final success = outcome == 'success';
        final sym = success ? output.ok : output.fail;
        final label = success
            ? output.green('step done')
            : output.red('step done');
        return '$prefix$sym  $label';
      case 'review_decision':
        final approved = decision.toLowerCase().contains('approv');
        final sym = approved ? output.ok : output.fail;
        final label = decision.toUpperCase();
        final colored = approved ? output.green(label) : output.red(label);
        return '$prefix$sym  $colored';
      case 'git_delivery_completed':
        final branchPart =
            branch.isNotEmpty ? '  ${output.dim(branch)}' : '';
        return '$prefix${output.ok}  ${output.green('pushed')}$branchPart';
      case 'preflight_failed':
        final reasonPart = reason.isNotEmpty ? ': $reason' : '';
        return '$prefix${output.fail}  '
            '${output.red('preflight failed$reasonPart')}';
      case 'orchestrator_run_safety_halt':
        return '$prefix${output.fail}  ${output.red('SAFETY HALT')}';
      case 'orchestrator_run_stopped':
        return '$prefix${output.dim('run stopped')}';
      case 'coding_agent_started':
        return null; // omit in rich mode
      default:
        return null;
    }
  }

  String? _formatLog(
    String ts,
    String event,
    String? step,
    String task,
    String agent,
    String decision,
    String branch,
    String outcome,
    String reason,
  ) {
    final prefix = ts.isEmpty ? '' : '$ts  ';
    final stepPart = step != null ? 'step=$step ' : '';
    switch (event) {
      case 'orchestrator_run_step_start':
        final agentPart = agent.isNotEmpty ? ' agent=$agent' : '';
        return '${prefix}step.start    ${stepPart}task="$task"$agentPart';
      case 'orchestrator_run_step_outcome':
        final outPart = outcome.isNotEmpty ? ' outcome=$outcome' : '';
        return ('${prefix}step.done     $stepPart$outPart').trimRight();
      case 'review_decision':
        return '${prefix}review.done   ${stepPart}decision=$decision';
      case 'git_delivery_completed':
        final branchPart = branch.isNotEmpty ? 'branch=$branch' : '';
        return ('${prefix}git.push      $branchPart').trimRight();
      case 'preflight_failed':
        final reasonPart = reason.isNotEmpty ? ' reason=$reason' : '';
        return '${prefix}preflight.fail$reasonPart';
      case 'orchestrator_run_safety_halt':
        return '${prefix}safety.halt';
      case 'orchestrator_run_stopped':
        return '${prefix}run.stopped';
      case 'coding_agent_started':
        final agentPart = agent.isNotEmpty ? ' agent=$agent' : '';
        return '${prefix}agent.start$agentPart';
      default:
        return null;
    }
  }

  String _parseTs(String isoStr) {
    try {
      return output.timestamp(DateTime.parse(isoStr));
    } catch (_) {
      return isoStr;
    }
  }
}
