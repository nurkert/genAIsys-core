import 'dart:io';

import 'package:genaisys/core/agents/agent_runner.dart';

// Stub agents for E2E testing.
//
// Each agent implements AgentRunner and produces deterministic output.
// Role is recognised by matching keywords in systemPrompt / prompt,
// following the same convention as _SmokeAgentRunner in
// autopilot_smoke_check_service.dart.
//
// The project root is inferred from AgentRequest.workingDirectory at
// runtime, so agents do not need it at construction time.

/// Always produces valid output for every agent role.
/// Coding: writes a small marker change to lib/e2e_marker.txt.
class SuccessAgent implements AgentRunner {
  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final role = _detectRole(request);
    switch (role) {
      case _AgentRole.acCheck:
        return _response(request, stdout: 'PASS');
      case _AgentRole.reviewer:
        return _response(
          request,
          stdout:
              'APPROVE\nThe changes in lib/e2e_marker.txt are correct. '
              'The marker file update is minimal and deterministic as expected.',
        );
      case _AgentRole.planner:
        return _response(request, stdout: _plan());
      case _AgentRole.spec:
        return _response(request, stdout: _spec());
      case _AgentRole.subtasks:
        return _response(request, stdout: _subtasks());
      case _AgentRole.strategist:
        return _response(request, stdout: '- Add E2E marker task');
      case _AgentRole.analysis:
        return _response(request, stdout: 'No issues detected.');
      case _AgentRole.mergeResolver:
        return _response(request, stdout: 'No conflicts to resolve.');
      case _AgentRole.coding:
        _writeMarkerChange(request.workingDirectory!);
        return _response(request, stdout: 'Applied E2E marker change.');
    }
  }

  static void _writeMarkerChange(String projectRoot) {
    final dir = Directory(_join(projectRoot, 'lib'));
    dir.createSync(recursive: true);
    final file = File(_join(projectRoot, 'lib/e2e_marker.txt'));
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final line = 'E2E marker at $timestamp\n';
    final existing = file.existsSync()
        ? file.readAsStringSync()
        : 'E2E marker file.\n';
    file.writeAsStringSync('$existing$line');
  }

  static String _plan() {
    return '# Plan\n\n## Steps\n'
        '1. Add an E2E marker file in lib/ to confirm write access.\n'
        '2. Validate the change through review and completion.\n';
  }

  static String _spec() {
    return '# Spec\n\n## Goal\n'
        'Create a small E2E marker file in lib/.\n\n'
        '## Constraints\n'
        '- Keep changes minimal and deterministic.\n'
        '- Do not modify unrelated files.\n\n'
        '## Acceptance\n'
        '- A marker file exists in lib/.\n'
        '- Review approves the change.\n';
  }

  static String _subtasks() {
    // Return a valid response without parseable subtask items.
    // The parser requires '## Subtasks' section with numbered/bulleted items.
    // By omitting the section, no subtasks are queued and the task runs
    // as a single-step main task (no subtask decomposition).
    return '# Subtasks\n\n'
        'This task is small enough to complete in a single step.\n'
        'No further decomposition needed.\n';
  }
}

/// Always crashes with a non-zero exit code for every role.
class FailAgent implements AgentRunner {
  @override
  Future<AgentResponse> run(AgentRequest request) async {
    return _response(
      request,
      exitCode: 1,
      stdout: '',
      stderr: 'Simulated agent failure.',
    );
  }
}

/// Rejects the first [failCount] review invocations, then behaves like
/// [SuccessAgent] for everything.
///
/// Coding always succeeds (writes valid marker changes), but the reviewer
/// explicitly returns REJECT for the first [failCount] reviews. This
/// triggers the review-reject → retry flow across multiple orchestrator
/// steps.
class FlakeAgent implements AgentRunner {
  FlakeAgent({required this.failCount});

  final int failCount;
  int _reviewAttempts = 0;

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final role = _detectRole(request);

    // Flake on review calls — coding always succeeds so there's a diff
    // available for the reviewer to evaluate.
    if (role == _AgentRole.reviewer) {
      _reviewAttempts++;
      if (_reviewAttempts <= failCount) {
        return _response(
          request,
          stdout:
              'REJECT\nThe changes in lib/e2e_marker.txt do not meet quality '
              'standards. The marker content needs improvement and does not '
              'follow the expected format for production readiness.',
        );
      }
    }

    // After failCount review rejections, delegate to SuccessAgent logic.
    return SuccessAgent().run(request);
  }
}

/// Produces valid responses for all roles but makes NO file changes
/// during coding, triggering no-diff detection.
class NoOpAgent implements AgentRunner {
  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final role = _detectRole(request);
    switch (role) {
      case _AgentRole.acCheck:
        return _response(request, stdout: 'PASS');
      case _AgentRole.reviewer:
        return _response(
          request,
          stdout:
              'APPROVE\nThe changes in lib/e2e_marker.txt are correct. '
              'The marker file update is minimal and deterministic as expected.',
        );
      case _AgentRole.planner:
        return _response(request, stdout: SuccessAgent._plan());
      case _AgentRole.spec:
        return _response(request, stdout: SuccessAgent._spec());
      case _AgentRole.subtasks:
        return _response(request, stdout: SuccessAgent._subtasks());
      case _AgentRole.strategist:
        return _response(request, stdout: '- Add E2E marker task');
      case _AgentRole.analysis:
        return _response(request, stdout: 'No issues detected.');
      case _AgentRole.mergeResolver:
        return _response(request, stdout: 'No conflicts to resolve.');
      case _AgentRole.coding:
        // Intentionally make no file changes.
        return _response(
          request,
          stdout: 'Applied changes (no actual changes made).',
        );
    }
  }
}

/// Wraps [SuccessAgent] with an artificial delay before each response.
class SlowAgent implements AgentRunner {
  SlowAgent({required this.delay});

  final Duration delay;

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    await Future<void>.delayed(delay);
    return SuccessAgent().run(request);
  }
}

/// Agent that writes syntactically invalid Dart code, triggering a quality
/// gate failure when `dart analyze` runs.
class SyntaxErrorAgent implements AgentRunner {
  @override
  Future<AgentResponse> run(AgentRequest request) async {
    final role = _detectRole(request);
    if (role == _AgentRole.coding) {
      final root = request.workingDirectory!;
      final dir = Directory(_join(root, 'lib'));
      dir.createSync(recursive: true);
      // Write invalid Dart that will fail `dart analyze`.
      final file = File(_join(root, 'lib/bad_code.dart'));
      file.writeAsStringSync(
        '// This file has a syntax error.\n'
        'void main() {\n'
        '  int x = "not an int"; // type error\n'
        '}\n',
      );
      return _response(request, stdout: 'Applied changes with syntax error.');
    }
    // All non-coding roles behave like SuccessAgent.
    return SuccessAgent().run(request);
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

enum _AgentRole {
  acCheck,
  reviewer,
  planner,
  spec,
  subtasks,
  strategist,
  analysis,
  mergeResolver,
  coding,
}

/// Detects the agent role from the request's system prompt and prompt,
/// using the same keyword conventions as the production agent services.
_AgentRole _detectRole(AgentRequest request) {
  final system = request.systemPrompt?.toLowerCase() ?? '';
  final prompt = request.prompt.toLowerCase();

  // AC self-check: must be detected before the generic 'reviewer' check
  // because the system prompt also contains the word 'reviewer'.
  if (system.contains('pass or fail')) {
    return _AgentRole.acCheck;
  }
  if (prompt.contains('answer with approve or reject on the first line')) {
    return _AgentRole.reviewer;
  }
  if (system.contains('planning agent')) {
    return _AgentRole.planner;
  }
  if (system.contains('specification agent')) {
    return _AgentRole.spec;
  }
  if (system.contains('task decomposition')) {
    return _AgentRole.subtasks;
  }
  if (system.contains('reviewer')) {
    return _AgentRole.reviewer;
  }
  if (system.contains('product strategist')) {
    return _AgentRole.strategist;
  }
  if (system.contains('debugging expert')) {
    return _AgentRole.analysis;
  }
  if (system.contains('merge conflicts')) {
    return _AgentRole.mergeResolver;
  }
  return _AgentRole.coding;
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
      executable: 'e2e-stub-agent',
      arguments: const [],
      runInShell: false,
      startedAt: startedAt.toIso8601String(),
      durationMs: 0,
      timedOut: false,
      workingDirectory: request.workingDirectory,
    ),
  );
}

String _join(String left, String right) {
  if (left.endsWith(Platform.pathSeparator)) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}
