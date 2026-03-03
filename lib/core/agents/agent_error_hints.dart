// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

class AgentErrorHints {
  static String hintForExitCode(
    int exitCode, {
    String? executable,
    String? detail,
    String? path,
  }) {
    if (exitCode == 53) {
      final buffer = StringBuffer();
      buffer.writeln('Hint: Agent exceeded its configured turn limit.');
      return buffer.toString().trim();
    }
    if (exitCode != 126 && exitCode != 127) {
      return '';
    }
    final name = (executable == null || executable.trim().isEmpty)
        ? 'agent executable'
        : executable.trim();
    final buffer = StringBuffer();
    if (exitCode == 127) {
      buffer.writeln('Hint: $name was not found on PATH.');
      buffer.writeln('Install the CLI and ensure it is available in PATH.');
    } else {
      buffer.writeln('Hint: $name could not be launched (permission denied).');
      buffer.writeln('Check file permissions and macOS security settings.');
    }
    if (Platform.isMacOS) {
      final lowerDetail = (detail ?? '').toLowerCase();
      if (lowerDetail.contains('operation not permitted') ||
          lowerDetail.contains('permission denied') ||
          lowerDetail.contains('not permitted')) {
        buffer.writeln(
          'On macOS, App Sandbox can block external CLIs. Disable sandboxing '
          'or run the desktop app without sandbox entitlements.',
        );
      } else {
        buffer.writeln(
          'If you are running the GUI build on macOS, the App Sandbox may '
          'block external CLIs. Disable sandboxing or run the CLI build.',
        );
      }
    }
    if (path != null && path.trim().isNotEmpty) {
      buffer.writeln('PATH: $path');
    }
    return buffer.toString().trim();
  }

  static String hintForNativeRunner({
    required int exitCode,
    String? apiBase,
  }) {
    final buffer = StringBuffer();
    if (exitCode == 127) {
      buffer.writeln(
        'Hint: native runner could not connect to the API endpoint.',
      );
      if (apiBase != null && apiBase.isNotEmpty) {
        buffer.writeln('API base: $apiBase');
      }
      buffer.writeln(
        'Ensure the server is running (e.g., `ollama serve`) and '
        'the api_base URL is correct in genaisys.yaml.',
      );
    } else if (exitCode == 1) {
      buffer.writeln(
        'Hint: native runner received an error from the API. '
        'Check api_key, model name, and server health.',
      );
    }
    return buffer.toString().trim();
  }

  static String missingExecutableMessage(String executable, {String? path}) {
    final buffer = StringBuffer();
    buffer.writeln('Agent executable not found: $executable');
    final hint = hintForExitCode(127, executable: executable, path: path);
    if (hint.isNotEmpty) {
      buffer.writeln(hint);
    }
    return buffer.toString().trim();
  }
}
