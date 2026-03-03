// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

class ProviderProcessRequest {
  ProviderProcessRequest({
    required this.prompt,
    this.systemPrompt,
    this.workingDirectory,
    this.environment,
    this.timeout,
    this.metadata = const <String, Object?>{},
  });

  final String prompt;
  final String? systemPrompt;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final Duration? timeout;
  final Map<String, Object?> metadata;

  String composeInput() {
    final system = systemPrompt?.trim();
    if (system == null || system.isEmpty) {
      return prompt;
    }
    return 'System: $system\n\n$prompt';
  }
}

class ProviderProcessCommand {
  const ProviderProcessCommand({
    required this.executable,
    this.arguments = const <String>[],
    this.runInShell = false,
    this.workingDirectory,
    this.environment,
  });

  final String executable;
  final List<String> arguments;
  final bool runInShell;
  final String? workingDirectory;
  final Map<String, String>? environment;

  String get commandLine {
    if (arguments.isEmpty) {
      return executable;
    }
    return '$executable ${arguments.join(' ')}';
  }
}

class ProviderProcessExecution {
  const ProviderProcessExecution({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.startedAt,
    required this.duration,
    this.timedOut = false,
  });

  final ProviderProcessCommand command;
  final int exitCode;
  final String stdout;
  final String stderr;
  final DateTime startedAt;
  final Duration duration;
  final bool timedOut;

  bool get ok => exitCode == 0;
}

class ProviderProcessFailure {
  const ProviderProcessFailure({
    required this.errorClass,
    required this.errorKind,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String errorClass;
  final String errorKind;
  final String message;
  final Map<String, Object?> details;

  Map<String, Object?> toMachineMap() {
    return <String, Object?>{
      ...details,
      'error_class': errorClass,
      'error_kind': errorKind,
      'message': message,
    };
  }
}

class ProviderProcessResponse {
  const ProviderProcessResponse({required this.execution, this.failure});

  final ProviderProcessExecution execution;
  final ProviderProcessFailure? failure;

  bool get ok => execution.ok && failure == null;
}

class ProviderProcessLifecycleContext {
  const ProviderProcessLifecycleContext({
    required this.request,
    required this.command,
    required this.startedAt,
  });

  final ProviderProcessRequest request;
  final ProviderProcessCommand command;
  final DateTime startedAt;
}

class ProviderProcessLifecycleResult extends ProviderProcessLifecycleContext {
  const ProviderProcessLifecycleResult({
    required super.request,
    required super.command,
    required super.startedAt,
    required this.response,
  });

  final ProviderProcessResponse response;
}

abstract class ProviderProcessLifecycleHooks {
  const ProviderProcessLifecycleHooks();

  FutureOr<void> onBeforeStart(ProviderProcessLifecycleContext context) {}

  FutureOr<void> onAfterComplete(ProviderProcessLifecycleResult result) {}

  FutureOr<void> onFailure(ProviderProcessLifecycleResult result) {}
}

abstract class ProviderProcessCommandAssembler {
  ProviderProcessCommand assemble(ProviderProcessRequest request);
}

abstract class ProviderProcessOutputParser {
  ProviderProcessResponse parse(
    ProviderProcessExecution execution, {
    required ProviderProcessRequest request,
    required ProviderProcessCommand command,
  });
}

abstract class ProviderProcessAdapter {
  const ProviderProcessAdapter();

  ProviderProcessCommandAssembler get commandAssembler;
  ProviderProcessOutputParser get outputParser;
  ProviderProcessLifecycleHooks get lifecycleHooks =>
      const _NoopProviderProcessLifecycleHooks();
}

class _NoopProviderProcessLifecycleHooks extends ProviderProcessLifecycleHooks {
  const _NoopProviderProcessLifecycleHooks();
}

abstract class ProviderProcessRunner {
  Future<ProviderProcessResponse> run({
    required ProviderProcessRequest request,
    required ProviderProcessAdapter adapter,
  });
}
