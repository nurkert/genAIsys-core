import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/agents/agent_registry.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/agents/agent_selector.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('AgentSelector resolves primary from config', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_agent_cfg_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "gemini"
  fallback: "codex"
''');

    final registry = AgentRegistry(
      codex: _FakeRunner('codex'),
      gemini: _FakeRunner('gemini'),
    );
    final selector = AgentSelector(registry: registry);

    final primary = selector.selectPrimary(temp.path);

    expect((primary as _FakeRunner).name, 'gemini');
  });

  test('AgentSelector returns null when fallback missing', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_cfg_missing_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final selector = AgentSelector(
      registry: AgentRegistry(codex: _FakeRunner('codex')),
    );

    final fallback = selector.selectFallback(temp.path);

    expect(fallback, isNull);
  });

  test('AgentSelector returns provider keys for selections', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_cfg_selection_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "gemini"
  fallback: "codex"
''');

    final selector = AgentSelector(
      registry: AgentRegistry(
        codex: _FakeRunner('codex'),
        gemini: _FakeRunner('gemini'),
      ),
    );

    final primary = selector.selectPrimarySelection(temp.path);
    final fallback = selector.selectFallbackSelection(temp.path);

    expect(primary.provider, 'gemini');
    expect((primary.runner as _FakeRunner).name, 'gemini');
    expect(fallback, isNotNull);
    expect(fallback!.provider, 'codex');
    expect((fallback.runner as _FakeRunner).name, 'codex');
  });

  test('AgentSelector promotes primary to front of pool', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_cfg_pool_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  primary: "codex"
  fallback: "gemini"
  pool:
    - "gemini@backup"
    - "codex@default"
    - "unknown@x"
''');

    final selector = AgentSelector(
      registry: AgentRegistry(
        codex: _FakeRunner('codex'),
        gemini: _FakeRunner('gemini'),
      ),
    );

    final result = selector.selectPoolSelections(temp.path);
    final pool = result.selections;

    // Primary (codex) is promoted to front despite appearing second in pool.
    expect(pool.length, 2);
    expect(pool.first.provider, 'codex');
    expect(pool.first.account, 'default');
    expect((pool.first.runner as _FakeRunner).name, 'codex');
    expect(pool.last.provider, 'gemini');
    expect(pool.last.account, 'backup');
    expect((pool.last.runner as _FakeRunner).name, 'gemini');
  });

  test('selectPoolSelections reports unresolved provider names', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_agent_cfg_unresolved_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final layout = ProjectLayout(temp.path);
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync('''
providers:
  pool:
    - "codex@default"
    - "nonexistent@default"
    - "also-missing@alt"
''');

    final selector = AgentSelector(
      registry: AgentRegistry(codex: _FakeRunner('codex')),
    );

    final result = selector.selectPoolSelections(temp.path);

    expect(result.selections.length, 1);
    expect(result.selections.first.provider, 'codex');
    expect(result.unresolvedProviders, ['nonexistent', 'also-missing']);
  });
}

class _FakeRunner implements AgentRunner {
  _FakeRunner(this.name);

  final String name;

  @override
  Future<AgentResponse> run(AgentRequest request) async {
    return const AgentResponse(exitCode: 0, stdout: '', stderr: '');
  }
}
