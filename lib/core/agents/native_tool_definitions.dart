// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// OpenAI-compatible tool definitions for the native agent loop.
///
/// Each definition follows the OpenAI function-calling JSON schema so that any
/// `/chat/completions`-compatible endpoint (Ollama, vLLM, etc.) can use them.
class NativeToolDefinitions {
  NativeToolDefinitions._();

  static const readFile = <String, Object?>{
    'type': 'function',
    'function': {
      'name': 'read_file',
      'description':
          'Read the contents of a file relative to the project root.',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description':
                'File path relative to the project root (e.g. "lib/main.dart").',
          },
        },
        'required': ['path'],
      },
    },
  };

  static const writeFile = <String, Object?>{
    'type': 'function',
    'function': {
      'name': 'write_file',
      'description':
          'Write content to a file relative to the project root. '
          'Parent directories are created automatically.',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description':
                'File path relative to the project root (e.g. "lib/main.dart").',
          },
          'content': {
            'type': 'string',
            'description': 'The full file content to write.',
          },
        },
        'required': ['path', 'content'],
      },
    },
  };

  static const listDirectory = <String, Object?>{
    'type': 'function',
    'function': {
      'name': 'list_directory',
      'description':
          'List files and directories relative to the project root.',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description':
                'Directory path relative to the project root (e.g. "lib/"). '
                'Use "." for the project root.',
          },
          'depth': {
            'type': 'integer',
            'description': 'Maximum recursion depth (1-3, default 1).',
          },
        },
        'required': ['path'],
      },
    },
  };

  static const runCommand = <String, Object?>{
    'type': 'function',
    'function': {
      'name': 'run_command',
      'description':
          'Execute a shell command in the project directory. '
          'Only commands from the allowed list are permitted.',
      'parameters': {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description':
                'The shell command to execute '
                '(e.g. "dart analyze", "flutter test test/foo_test.dart").',
          },
        },
        'required': ['command'],
      },
    },
  };

  /// All tool definitions as an unmodifiable list.
  static List<Map<String, Object?>> all() {
    return const [readFile, writeFile, listDirectory, runCommand];
  }
}
