// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class AgentCommandEvent {
  const AgentCommandEvent({
    required this.executable,
    required this.arguments,
    required this.runInShell,
    required this.startedAt,
    required this.durationMs,
    required this.timedOut,
    this.workingDirectory,
    this.phase = 'run',
  });

  final String executable;
  final List<String> arguments;
  final bool runInShell;
  final String startedAt;
  final int durationMs;
  final bool timedOut;
  final String? workingDirectory;
  final String phase;

  String get commandLine {
    if (arguments.isEmpty) {
      return executable;
    }
    return '$executable ${arguments.join(' ')}';
  }
}

class AgentRequest {
  AgentRequest({
    required this.prompt,
    this.systemPrompt,
    this.workingDirectory,
    this.environment,
    this.timeout,
  });

  final String prompt;
  final String? systemPrompt;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final Duration? timeout;
}

class AgentResponse {
  const AgentResponse({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.commandEvent,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final AgentCommandEvent? commandEvent;

  bool get ok => exitCode == 0;
}

abstract class AgentRunner {
  Future<AgentResponse> run(AgentRequest request);
}
