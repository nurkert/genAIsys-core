import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/models/code_health_models.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/code_health_reflection_service.dart';

/// Fake [AgentService] that returns a pre-configured response.
class _FakeAgentService extends AgentService {
  _FakeAgentService({required this.responseFactory});

  final AgentServiceResult Function(AgentRequest request) responseFactory;
  AgentRequest? lastRequest;

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    lastRequest = request;
    return responseFactory(request);
  }
}

AgentServiceResult _ok(String stdout) {
  return AgentServiceResult(
    response: AgentResponse(exitCode: 0, stdout: stdout, stderr: ''),
    usedFallback: false,
  );
}

AgentServiceResult _failure() {
  return AgentServiceResult(
    response: AgentResponse(exitCode: 1, stdout: '', stderr: 'error'),
    usedFallback: false,
  );
}

void main() {
  late Directory temp;
  late String projectRoot;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_chr_');
    projectRoot = temp.path;
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  ProjectConfig config({
    bool reflectionEnabled = true,
    int llmBudgetTokens = 4000,
  }) {
    return ProjectConfig(
      codeHealthReflectionEnabled: reflectionEnabled,
      codeHealthLlmBudgetTokens: llmBudgetTokens,
    );
  }

  List<CodeHealthSignal> sampleSignals() {
    return const [
      CodeHealthSignal(
        layer: HealthSignalLayer.static,
        confidence: 0.8,
        finding: 'File lib/big.dart exceeds 500 lines (600)',
        affectedFiles: ['lib/big.dart'],
      ),
      CodeHealthSignal(
        layer: HealthSignalLayer.dejaVu,
        confidence: 0.6,
        finding: 'Hotspot: lib/big.dart touched in 60% of recent deliveries',
        affectedFiles: ['lib/big.dart'],
      ),
    ];
  }

  test('returns empty when triggeringSignals is empty', () async {
    final fake = _FakeAgentService(responseFactory: (_) => _ok(''));
    final service = CodeHealthReflectionService(agentService: fake);

    final result = await service.reflect(
      projectRoot,
      triggeringSignals: [],
      config: config(),
    );

    expect(result, isEmpty);
    expect(fake.lastRequest, isNull);
  });

  test('parses structured response into signals', () async {
    const response = '''
FINDING: God class anti-pattern in big.dart
FILES: lib/big.dart
ACTION: Extract separate concerns into dedicated service classes
CONFIDENCE: 0.85
---
FINDING: Missing abstraction layer for data access
FILES: lib/big.dart, lib/data.dart
ACTION: Introduce a repository interface
CONFIDENCE: 0.7
---
''';

    final fake = _FakeAgentService(responseFactory: (_) => _ok(response));
    final service = CodeHealthReflectionService(agentService: fake);

    final result = await service.reflect(
      projectRoot,
      triggeringSignals: sampleSignals(),
      config: config(),
    );

    expect(result, hasLength(2));

    expect(result[0].layer, HealthSignalLayer.architectureReflection);
    expect(result[0].finding, 'God class anti-pattern in big.dart');
    expect(result[0].affectedFiles, ['lib/big.dart']);
    expect(result[0].suggestedAction, contains('Extract'));
    expect(result[0].confidence, 0.85);

    expect(result[1].affectedFiles, ['lib/big.dart', 'lib/data.dart']);
    expect(result[1].confidence, 0.7);
  });

  test('returns empty on agent failure', () async {
    final fake = _FakeAgentService(responseFactory: (_) => _failure());
    final service = CodeHealthReflectionService(agentService: fake);

    final result = await service.reflect(
      projectRoot,
      triggeringSignals: sampleSignals(),
      config: config(),
    );

    expect(result, isEmpty);
  });

  test('handles malformed response gracefully', () async {
    const response = '''
This is just free-form text without any structured blocks.
The LLM didn't follow the format instructions.
''';

    final fake = _FakeAgentService(responseFactory: (_) => _ok(response));
    final service = CodeHealthReflectionService(agentService: fake);

    final result = await service.reflect(
      projectRoot,
      triggeringSignals: sampleSignals(),
      config: config(),
    );

    expect(result, isEmpty);
  });

  test('prompt includes signal data and file contents', () async {
    // Create a source file for the prompt to include.
    final filePath = '$projectRoot${Platform.pathSeparator}lib';
    Directory(filePath).createSync(recursive: true);
    File(
      '$filePath${Platform.pathSeparator}big.dart',
    ).writeAsStringSync('class Big {}\n');

    final fake = _FakeAgentService(responseFactory: (_) => _ok(''));
    final service = CodeHealthReflectionService(agentService: fake);

    await service.reflect(
      projectRoot,
      triggeringSignals: sampleSignals(),
      config: config(),
    );

    final prompt = fake.lastRequest!.prompt;

    // Verify signal data is included.
    expect(prompt, contains('[static]'));
    expect(prompt, contains('[dejaVu]'));
    expect(prompt, contains('confidence: 0.80'));
    expect(prompt, contains('lib/big.dart'));

    // Verify file content is included.
    expect(prompt, contains('class Big {}'));

    // Verify structured output instructions.
    expect(prompt, contains('FINDING:'));
    expect(prompt, contains('FILES:'));
    expect(prompt, contains('ACTION:'));
    expect(prompt, contains('CONFIDENCE:'));
  });

  test('clamps confidence to 0.0-1.0', () async {
    const response = '''
FINDING: Over-confident finding
FILES: lib/a.dart
ACTION: Fix it
CONFIDENCE: 1.5
---
FINDING: Negative confidence
FILES: lib/b.dart
ACTION: Fix it too
CONFIDENCE: -0.3
---
''';

    final fake = _FakeAgentService(responseFactory: (_) => _ok(response));
    final service = CodeHealthReflectionService(agentService: fake);

    final result = await service.reflect(
      projectRoot,
      triggeringSignals: sampleSignals(),
      config: config(),
    );

    expect(result, hasLength(2));
    expect(result[0].confidence, 1.0);
    expect(result[1].confidence, 0.0);
  });

  test('truncates file content to token budget', () async {
    // Create a large file.
    final filePath = '$projectRoot${Platform.pathSeparator}lib';
    Directory(filePath).createSync(recursive: true);
    // 20000 chars > budget of 100 tokens * 4 * 0.7 = 280 chars
    final largeContent = 'x' * 20000;
    File(
      '$filePath${Platform.pathSeparator}big.dart',
    ).writeAsStringSync(largeContent);

    final fake = _FakeAgentService(responseFactory: (_) => _ok(''));
    final service = CodeHealthReflectionService(agentService: fake);

    await service.reflect(
      projectRoot,
      triggeringSignals: sampleSignals(),
      config: config(llmBudgetTokens: 100), // very small budget
    );

    final prompt = fake.lastRequest!.prompt;
    // The file content should be truncated.
    expect(prompt, contains('(truncated)'));
    // The full 20000 chars should NOT be in the prompt.
    expect(prompt.length, lessThan(20000));
  });

  test('defaults confidence to 0.7 when not specified', () async {
    const response = '''
FINDING: Missing confidence field
FILES: lib/a.dart
ACTION: Add it
---
''';

    final fake = _FakeAgentService(responseFactory: (_) => _ok(response));
    final service = CodeHealthReflectionService(agentService: fake);

    final result = await service.reflect(
      projectRoot,
      triggeringSignals: sampleSignals(),
      config: config(),
    );

    expect(result, hasLength(1));
    expect(result[0].confidence, 0.7);
  });
}
