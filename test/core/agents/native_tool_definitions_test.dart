import 'package:test/test.dart';

import 'package:genaisys/core/agents/native_tool_definitions.dart';

void main() {
  group('NativeToolDefinitions', () {
    test('all() returns exactly 4 definitions', () {
      final defs = NativeToolDefinitions.all();
      expect(defs, hasLength(4));
    });

    test('each definition has correct structure', () {
      final defs = NativeToolDefinitions.all();
      final expectedNames = [
        'read_file',
        'write_file',
        'list_directory',
        'run_command',
      ];

      for (var i = 0; i < defs.length; i++) {
        final def = defs[i];
        expect(def['type'], 'function', reason: 'def[$i] type');

        final function_ = def['function'] as Map<String, Object?>;
        expect(function_['name'], expectedNames[i], reason: 'def[$i] name');
        expect(function_['description'], isA<String>(), reason: 'def[$i] desc');

        final params = function_['parameters'] as Map<String, Object?>;
        expect(params['type'], 'object', reason: 'def[$i] params.type');
        expect(
          params['properties'],
          isA<Map<String, Object?>>(),
          reason: 'def[$i] params.properties',
        );
        expect(
          params['required'],
          isA<List<Object?>>(),
          reason: 'def[$i] params.required',
        );
      }
    });

    test('read_file requires path', () {
      final def = NativeToolDefinitions.readFile;
      final function_ = def['function'] as Map<String, Object?>;
      final params = function_['parameters'] as Map<String, Object?>;
      expect(params['required'], contains('path'));
    });

    test('write_file requires path and content', () {
      final def = NativeToolDefinitions.writeFile;
      final function_ = def['function'] as Map<String, Object?>;
      final params = function_['parameters'] as Map<String, Object?>;
      final required = params['required'] as List<Object?>;
      expect(required, contains('path'));
      expect(required, contains('content'));
    });

    test('list_directory requires path', () {
      final def = NativeToolDefinitions.listDirectory;
      final function_ = def['function'] as Map<String, Object?>;
      final params = function_['parameters'] as Map<String, Object?>;
      expect(params['required'], contains('path'));
    });

    test('run_command requires command', () {
      final def = NativeToolDefinitions.runCommand;
      final function_ = def['function'] as Map<String, Object?>;
      final params = function_['parameters'] as Map<String, Object?>;
      expect(params['required'], contains('command'));
    });
  });
}
