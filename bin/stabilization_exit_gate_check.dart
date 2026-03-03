// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/autopilot/stabilization_exit_gate_service.dart';

void main(List<String> args) {
  final projectRoot = _parseProjectRoot(args);
  final layout = ProjectLayout(projectRoot);
  final result = StabilizationExitGateService().evaluate(layout.tasksPath);

  stdout.writeln(
    jsonEncode(<String, Object?>{
      'project_root': projectRoot,
      ...result.toJson(),
    }),
  );

  exit(result.ok ? 0 : 1);
}

String _parseProjectRoot(List<String> args) {
  for (var i = 0; i < args.length; i += 1) {
    if (args[i] != '--project-root') {
      continue;
    }
    if (i + 1 >= args.length) {
      stderr.writeln('Missing value for --project-root.');
      exit(2);
    }
    return args[i + 1];
  }
  return Directory.current.path;
}
