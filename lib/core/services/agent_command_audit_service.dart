// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../agents/agent_runner.dart';
import '../project_layout.dart';
import '../storage/run_log_store.dart';

class AgentCommandAuditService {
  void record(
    String projectRoot, {
    required String runner,
    required String attempt,
    required bool usedFallback,
    required AgentRequest request,
    required AgentResponse response,
    required AgentCommandEvent command,
  }) {
    final layout = ProjectLayout(projectRoot);
    if (!Directory(layout.genaisysDir).existsSync()) {
      return;
    }

    final payload = <String, Object?>{
      'root': projectRoot,
      'runner': runner,
      'attempt': attempt,
      'phase': command.phase,
      'used_fallback': usedFallback,
      'command_executable': command.executable,
      'command_arguments': command.arguments,
      'command_line': command.commandLine,
      'run_in_shell': command.runInShell,
      'working_directory':
          command.workingDirectory ?? request.workingDirectory ?? '',
      'timeout_seconds': request.timeout?.inSeconds,
      'started_at': command.startedAt,
      'duration_ms': command.durationMs,
      'timed_out': command.timedOut,
      'exit_code': response.exitCode,
      'ok': response.ok,
      'stdout_excerpt': _excerpt(response.stdout),
      'stderr_excerpt': _excerpt(response.stderr),
    };

    RunLogStore(layout.runLogPath).append(
      event: 'agent_command',
      message: response.ok ? 'Agent command completed' : 'Agent command failed',
      data: payload,
    );

    _appendAuditEntry(layout, payload);
  }

  void _appendAuditEntry(ProjectLayout layout, Map<String, Object?> payload) {
    final dir = Directory(layout.auditDir);
    dir.createSync(recursive: true);
    final file = File(_join(layout.auditDir, 'agent_commands.jsonl'));
    final entry = <String, Object?>{
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      ...payload,
    };
    file.writeAsStringSync('${jsonEncode(entry)}\n', mode: FileMode.append);
  }

  String _excerpt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    const maxLength = 300;
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength)}...';
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}
