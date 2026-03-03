import 'dart:io';

import 'package:test/test.dart';
import 'package:genaisys/core/agents/agent_runner.dart';
import 'package:genaisys/core/models/init_orchestration_context.dart';
import 'package:genaisys/core/models/init_orchestration_result.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/agent_service.dart';
import 'package:genaisys/core/services/init_orchestrator_service.dart';

import '../../support/test_workspace.dart';

void main() {
  late TestWorkspace workspace;

  setUp(() {
    workspace = TestWorkspace.create(prefix: 'genaisys_init_orch_');
    workspace.ensureStructure();
  });

  tearDown(() => workspace.dispose());

  InitOrchestrationContext _makeCtx({
    String input = 'Build a task manager app.',
    bool isReinit = false,
    bool overwrite = false,
  }) => InitOrchestrationContext(
    projectRoot: workspace.root.path,
    normalizedInputText: input,
    inputSourcePayload: '<inline>',
    isReinit: isReinit,
    overwrite: overwrite,
  );

  group('happy path', () {
    test('all 6 stages complete and 5 files are written', () async {
      final agent = _FakeAgentService.alwaysApprove();
      final service = InitOrchestratorService(agentService: agent);

      final result = await service.run(
        workspace.root.path,
        ctx: _makeCtx(),
      );

      expect(result.retryCount, 0);
      expect(result.isReinit, isFalse);

      final layout = ProjectLayout(workspace.root.path);
      expect(result.writtenPaths, containsAll([
        layout.visionPath,
        layout.architecturePath,
        layout.tasksPath,
        layout.configPath,
        layout.rulesPath,
      ]));
      expect(result.writtenPaths.length, 5);

      for (final path in result.writtenPaths) {
        expect(File(path).existsSync(), isTrue, reason: '$path should exist');
      }
    });

    test('run-log contains init_orchestration_complete event', () async {
      final agent = _FakeAgentService.alwaysApprove();
      final service = InitOrchestratorService(agentService: agent);

      await service.run(workspace.root.path, ctx: _makeCtx());

      final log = File(workspace.layout.runLogPath).readAsStringSync();
      expect(log, contains('init_orchestration_complete'));
    });

    test('run-log contains init_stage_start x6 and init_stage_complete x6', () async {
      final agent = _FakeAgentService.alwaysApprove();
      final service = InitOrchestratorService(agentService: agent);

      await service.run(workspace.root.path, ctx: _makeCtx());

      final log = File(workspace.layout.runLogPath).readAsStringSync();
      final startCount = 'init_stage_start'.allMatches(log).length;
      final completeCount = 'init_stage_complete'.allMatches(log).length;

      expect(startCount, 6);
      expect(completeCount, 6);
    });
  });

  group('retry on verification reject', () {
    test('reject on attempt 1, approve on attempt 2 → retryCount=1', () async {
      final agent = _FakeAgentService.rejectOnFirstVerification();
      final service = InitOrchestratorService(agentService: agent);

      final result = await service.run(
        workspace.root.path,
        ctx: _makeCtx(),
      );

      expect(result.retryCount, 1);
      expect(result.writtenPaths.length, 5);
    });

    test('reject twice → max retries exceeded, no files written', () async {
      final agent = _FakeAgentService.alwaysReject();
      final service = InitOrchestratorService(agentService: agent);

      final result = await service.run(
        workspace.root.path,
        ctx: _makeCtx(),
      );

      // retryCount exceeds _maxRetries (2) → abort
      expect(result.writtenPaths, isEmpty);
    });

    test('run-log contains init_orchestration_retry event on retry', () async {
      final agent = _FakeAgentService.rejectOnFirstVerification();
      final service = InitOrchestratorService(agentService: agent);

      await service.run(workspace.root.path, ctx: _makeCtx());

      final log = File(workspace.layout.runLogPath).readAsStringSync();
      expect(log, contains('init_orchestration_retry'));
    });
  });

  group('agent failure', () {
    test('failure in vision stage → init_stage_failed, no files written', () async {
      final agent = _FakeAgentService.failOn('vision');
      final service = InitOrchestratorService(agentService: agent);

      final result = await service.run(
        workspace.root.path,
        ctx: _makeCtx(),
      );

      expect(result.writtenPaths, isEmpty);
      final log = File(workspace.layout.runLogPath).readAsStringSync();
      expect(log, contains('init_stage_failed'));
    });
  });

  group('code fence stripping', () {
    test('markdown fences are stripped from artifact files', () async {
      final agent = _FakeAgentService(
        responseFor: (prompt) {
          if (prompt.contains('reviewing')) return 'APPROVE';
          // Simulate an LLM that wraps output in markdown code fences
          return '```markdown\n# Generated Artifact\n\nSome content here.\n```';
        },
      );
      final service = InitOrchestratorService(agentService: agent);

      await service.run(workspace.root.path, ctx: _makeCtx());

      final layout = ProjectLayout(workspace.root.path);
      final visionContent = File(layout.visionPath).readAsStringSync();
      expect(visionContent, isNot(startsWith('```')));
      expect(visionContent, contains('# Generated Artifact'));
      expect(visionContent, isNot(endsWith('```')));
    });

    test('yaml fences are stripped from config artifact', () async {
      final agent = _FakeAgentService(
        responseFor: (prompt) {
          if (prompt.contains('reviewing')) return 'APPROVE';
          if (prompt.contains('config.yml')) {
            return '```yaml\nquality_gate: strict\n```';
          }
          return '# Generated content';
        },
      );
      final service = InitOrchestratorService(agentService: agent);

      await service.run(workspace.root.path, ctx: _makeCtx());

      final layout = ProjectLayout(workspace.root.path);
      final configContent = File(layout.configPath).readAsStringSync();
      expect(configContent, isNot(startsWith('```')));
      expect(configContent, contains('quality_gate: strict'));
    });

    test('output without fences is preserved as-is', () async {
      const cleanContent = '# Clean Artifact\n\nNo fences here.';
      final agent = _FakeAgentService(
        responseFor: (prompt) {
          if (prompt.contains('reviewing')) return 'APPROVE';
          return cleanContent;
        },
      );
      final service = InitOrchestratorService(agentService: agent);

      await service.run(workspace.root.path, ctx: _makeCtx());

      final layout = ProjectLayout(workspace.root.path);
      final visionContent = File(layout.visionPath).readAsStringSync();
      expect(visionContent, cleanContent);
    });

    test('output with preamble before fence is preserved without stripping', () async {
      // If there's text before the fence the whole thing is kept (data safety)
      const withPreamble = 'Here is the content:\n\n```markdown\n# Title\n```';
      final agent = _FakeAgentService(
        responseFor: (prompt) {
          if (prompt.contains('reviewing')) return 'APPROVE';
          return withPreamble;
        },
      );
      final service = InitOrchestratorService(agentService: agent);

      await service.run(workspace.root.path, ctx: _makeCtx());

      final layout = ProjectLayout(workspace.root.path);
      final visionContent = File(layout.visionPath).readAsStringSync();
      // Preamble present → no stripping; content unchanged
      expect(visionContent, withPreamble);
    });
  });

  group('re-init', () {
    test('overwrite:false preserves existing files', () async {
      final layout = ProjectLayout(workspace.root.path);
      const originalContent = '# Original Vision — do not overwrite';
      File(layout.visionPath).writeAsStringSync(originalContent);

      final agent = _FakeAgentService.alwaysApprove();
      final service = InitOrchestratorService(agentService: agent);

      await service.run(
        workspace.root.path,
        ctx: _makeCtx(isReinit: true, overwrite: false),
      );

      expect(File(layout.visionPath).readAsStringSync(), originalContent);
    });

    test('overwrite:true replaces existing files', () async {
      final layout = ProjectLayout(workspace.root.path);
      const originalContent = '# Original Vision — overwrite this';
      File(layout.visionPath).writeAsStringSync(originalContent);

      final agent = _FakeAgentService.alwaysApprove();
      final service = InitOrchestratorService(agentService: agent);

      final result = await service.run(
        workspace.root.path,
        ctx: _makeCtx(isReinit: true, overwrite: true),
      );

      expect(File(layout.visionPath).readAsStringSync(), isNot(originalContent));
      expect(result.writtenPaths, contains(layout.visionPath));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────────

/// Fake [AgentService] controllable by stage keyword matching.
class _FakeAgentService extends AgentService {
  _FakeAgentService({
    required String Function(String prompt) responseFor,
    int Function(String prompt)? exitCodeFor,
  }) : _responseFor = responseFor,
       _exitCodeFor = exitCodeFor ?? ((_) => 0);

  final String Function(String prompt) _responseFor;
  final int Function(String prompt) _exitCodeFor;

  int _verificationCallCount = 0;

  /// All stages approve.
  factory _FakeAgentService.alwaysApprove() => _FakeAgentService(
    responseFor: (prompt) {
      if (prompt.contains('reviewing')) return 'APPROVE';
      return '# Generated content for this stage';
    },
  );

  /// Verification always rejects.
  factory _FakeAgentService.alwaysReject() => _FakeAgentService(
    responseFor: (prompt) {
      if (prompt.contains('reviewing')) {
        return 'REJECT\nThe artifacts need improvement.';
      }
      return '# Generated content';
    },
  );

  /// Verification rejects on first call, approves on second.
  factory _FakeAgentService.rejectOnFirstVerification() {
    var verificationCount = 0;
    return _FakeAgentService(
      responseFor: (prompt) {
        if (prompt.contains('reviewing')) {
          verificationCount += 1;
          if (verificationCount == 1) {
            return 'REJECT\nNeeds more detail.';
          }
          return 'APPROVE';
        }
        return '# Generated content for stage';
      },
    );
  }

  /// Fails (exit 1) when the prompt mentions [stageName].
  factory _FakeAgentService.failOn(String stageName) => _FakeAgentService(
    responseFor: (prompt) => '',
    exitCodeFor: (prompt) {
      // Vision stage prompt mentions 'VISION.md' or 'purpose'
      if (stageName == 'vision' && prompt.contains('purpose')) return 1;
      return 0;
    },
  );

  @override
  Future<AgentServiceResult> run(
    String projectRoot,
    AgentRequest request,
  ) async {
    final exitCode = _exitCodeFor(request.prompt);
    final stdout = exitCode == 0 ? _responseFor(request.prompt) : '';
    return AgentServiceResult(
      response: AgentResponse(
        exitCode: exitCode,
        stdout: stdout,
        stderr: exitCode != 0 ? 'Simulated agent failure' : '',
      ),
      usedFallback: false,
    );
  }
}
