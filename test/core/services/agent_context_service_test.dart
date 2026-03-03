import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/services/agent_context_service.dart';

void main() {
  late String root;

  setUp(() {
    final temp = Directory.systemTemp.createTempSync('agent_ctx_test_');
    root = temp.path;
    addTearDown(() => temp.deleteSync(recursive: true));
    ProjectInitializer(root).ensureStructure(overwrite: true);
  });

  group('loadCodingPersona', () {
    test('returns persona content even when agent is disabled', () {
      // Disable the security agent in config.
      final configFile = File('$root/.genaisys/config.yml');
      final original = configFile.readAsStringSync();
      configFile.writeAsStringSync(
        original.replaceAll(
          RegExp(r'security:\s*\n\s*enabled:\s*true'),
          'security:\n    enabled: false',
        ),
      );

      // Write a security persona file.
      final promptFile = File('$root/.genaisys/agent_contexts/security.md');
      promptFile.createSync(recursive: true);
      promptFile.writeAsStringSync('SECURITY_PERSONA_MARKER');

      final service = AgentContextService();
      final result = service.loadCodingPersona(root, 'security');

      expect(result, isNotNull);
      expect(result, contains('SECURITY_PERSONA_MARKER'));
    });

    test('returns null when profile does not exist', () {
      final service = AgentContextService();
      final result = service.loadCodingPersona(root, 'nonexistent_agent');

      expect(result, isNull);
    });

    test('returns null when prompt file is empty', () {
      final promptFile = File(
        '$root/.genaisys/agent_contexts/architecture.md',
      );
      promptFile.createSync(recursive: true);
      promptFile.writeAsStringSync('   ');

      final service = AgentContextService();
      final result = service.loadCodingPersona(root, 'architecture');

      expect(result, isNull);
    });

    test('returns content for enabled agent', () {
      final promptFile = File('$root/.genaisys/agent_contexts/core.md');
      promptFile.createSync(recursive: true);
      promptFile.writeAsStringSync('CORE_PERSONA');

      final service = AgentContextService();
      final result = service.loadCodingPersona(root, 'core');

      expect(result, equals('CORE_PERSONA'));
    });
  });

  group('loadSystemPrompt', () {
    test('returns null when agent is disabled', () {
      final configFile = File('$root/.genaisys/config.yml');
      final original = configFile.readAsStringSync();
      configFile.writeAsStringSync(
        original.replaceAll(
          RegExp(r'security:\s*\n\s*enabled:\s*true'),
          'security:\n    enabled: false',
        ),
      );

      final promptFile = File('$root/.genaisys/agent_contexts/security.md');
      promptFile.createSync(recursive: true);
      promptFile.writeAsStringSync('SECURITY_PERSONA_MARKER');

      final service = AgentContextService();
      final result = service.loadSystemPrompt(root, 'security');

      expect(result, isNull);
    });

    test('returns content when agent is enabled', () {
      final promptFile = File('$root/.genaisys/agent_contexts/core.md');
      promptFile.createSync(recursive: true);
      promptFile.writeAsStringSync('CORE_PROMPT');

      final service = AgentContextService();
      final result = service.loadSystemPrompt(root, 'core');

      expect(result, equals('CORE_PROMPT'));
    });
  });
}
