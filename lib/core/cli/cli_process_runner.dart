// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'cli_exit_status.dart';

class CliProcessResult {
  const CliProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;
  CliExitStatus get status => cliExitStatusFromCode(exitCode);
}

class CliProcessRunner {
  CliProcessRunner({this.executable = 'genaisys'});

  final String executable;

  Future<CliProcessResult> run(
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return CliProcessResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  }
}
