import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/models/task.dart';
import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/agents/analysis_agent_service.dart';
import 'package:genaisys/core/services/pipeline_prompt_assembler.dart';
import 'package:genaisys/core/services/required_files_enforcer.dart';

void main() {
  group('PipelinePromptAssembler', () {
    test('preserves base prompt at the start of result', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );

      final temp = Directory.systemTemp.createTempSync('assembler_base_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        requiredFiles: const [],
        requiredFilesMode: RequiredFilesMode.anyOf,
      );

      expect(result, startsWith('Do the task'));
      // No forensic/failure/required-files sections when none are provided.
      expect(result, isNot(contains('FORENSIC GUIDANCE')));
      expect(result, isNot(contains('FAILURE ANALYSIS')));
      expect(result, isNot(contains('REQUIRED FILE TARGETS')));
    });

    test('injects forensic guidance section', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );

      final temp = Directory.systemTemp.createTempSync('assembler_forensic_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        forensicGuidance: 'Avoid null pointer in line 42',
        requiredFiles: const [],
        requiredFilesMode: RequiredFilesMode.anyOf,
      );

      expect(result, contains('FORENSIC GUIDANCE'));
      expect(result, contains('Avoid null pointer in line 42'));
    });

    test('injects failure analysis when review rejected', () async {
      final analysis = _FakeAnalysisAgentService();
      final assembler = PipelinePromptAssembler(
        analysisAgentService: analysis,
      );

      final temp = Directory.systemTemp.createTempSync('assembler_reject_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        reviewStatus: 'rejected',
        lastError: 'Test failure in foo_test.dart',
        activeTaskTitle: 'Fix the foo module',
        requiredFiles: const [],
        requiredFilesMode: RequiredFilesMode.anyOf,
      );

      expect(result, contains('FAILURE ANALYSIS & STRATEGY'));
      expect(result, contains('Analyzed: Fix the foo module'));
      expect(analysis.lastTaskTitle, 'Fix the foo module');
    });

    test('injects required files block (allOf mode)', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );

      final temp = Directory.systemTemp.createTempSync('assembler_required_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        requiredFiles: ['lib/core/service.dart', 'test/core/test.dart'],
        requiredFilesMode: RequiredFilesMode.allOf,
      );

      expect(result, contains('REQUIRED FILE TARGETS'));
      expect(result, contains('MUST include changes to the following'));
      expect(result, contains('lib/core/service.dart'));
      expect(result, contains('test/core/test.dart'));
    });

    test('injects required files block (anyOf mode)', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );

      final temp = Directory.systemTemp.createTempSync('assembler_anyof_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        requiredFiles: ['lib/core/service.dart'],
        requiredFilesMode: RequiredFilesMode.anyOf,
      );

      expect(result, contains('at least one of the following'));
    });

    test('does not inject empty forensic guidance', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );

      final temp = Directory.systemTemp.createTempSync('assembler_empty_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        forensicGuidance: '   ',
        requiredFiles: const [],
        requiredFilesMode: RequiredFilesMode.anyOf,
      );

      expect(result, isNot(contains('FORENSIC GUIDANCE')));
    });
  });

  group('retry-context injection', () {
    test('no retry block when retryCount is 0', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );
      final temp = Directory.systemTemp.createTempSync('assembler_retry0_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        requiredFiles: const [],
        requiredFilesMode: RequiredFilesMode.anyOf,
        retryCount: 0,
      );

      expect(result, isNot(contains('RETRY ATTEMPT')));
      expect(result, startsWith('Do the task'));
    });

    test('injects retry block at start of prompt when retryCount >= 1', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );
      final temp = Directory.systemTemp.createTempSync('assembler_retry1_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        requiredFiles: const [],
        requiredFilesMode: RequiredFilesMode.anyOf,
        retryCount: 2,
      );

      expect(result, startsWith('⚠ RETRY ATTEMPT 2'));
      expect(result, contains('Do the task'));
    });

    test('aggregates up to 3 recent reject notes in prompt', () async {
      final assembler = PipelinePromptAssembler(
        analysisAgentService: _NoopAnalysisAgentService(),
      );
      final temp = Directory.systemTemp.createTempSync('assembler_agg_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);
      final config = ProjectConfig.load(temp.path);

      // Write 4 reject events; only the last 3 should appear.
      final runLog = File(layout.runLogPath);
      for (final note in ['old note', 'note 1', 'note 2', 'note 3']) {
        runLog.writeAsStringSync(
          '${jsonEncode({'event': 'review_reject', 'data': {'note': note}})}\n',
          mode: FileMode.append,
        );
      }

      final result = await assembler.assemble(
        'Do the task',
        projectRoot: temp.path,
        config: config,
        resolvedCategory: TaskCategory.core,
        layout: layout,
        requiredFiles: const [],
        requiredFilesMode: RequiredFilesMode.anyOf,
        retryCount: 1,
      );

      expect(result, contains('note 1'));
      expect(result, contains('note 2'));
      expect(result, contains('note 3'));
      expect(result, isNot(contains('old note')));
    });
  });

  group('readLatestReviewRejectNote', () {
    test('returns note from latest review_reject event', () {
      final temp = Directory.systemTemp.createTempSync('assembler_note_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final entry = jsonEncode({
        'event': 'review_reject',
        'data': {'note': 'Missing test coverage'},
      });
      File(layout.runLogPath).writeAsStringSync('$entry\n');

      final assembler = PipelinePromptAssembler();
      final note = assembler.readLatestReviewRejectNote(layout);
      expect(note, 'Missing test coverage');
    });

    test('returns null when no review_reject events', () {
      final temp = Directory.systemTemp.createTempSync('assembler_no_note_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final entry = jsonEncode({
        'event': 'task_cycle_complete',
        'data': {'task': 'done'},
      });
      File(layout.runLogPath).writeAsStringSync('$entry\n');

      final assembler = PipelinePromptAssembler();
      final note = assembler.readLatestReviewRejectNote(layout);
      expect(note, isNull);
    });

    test('returns null when run log does not exist', () {
      final temp = Directory.systemTemp.createTempSync('assembler_no_log_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final layout = ProjectLayout(temp.path);

      final assembler = PipelinePromptAssembler();
      final note = assembler.readLatestReviewRejectNote(layout);
      expect(note, isNull);
    });
  });

  group('readRecentReviewRejectNotes', () {
    test('returns notes in chronological order', () {
      final temp = Directory.systemTemp.createTempSync('assembler_recent_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final runLog = File(layout.runLogPath);
      for (final note in ['first', 'second', 'third']) {
        runLog.writeAsStringSync(
          '${jsonEncode({'event': 'review_reject', 'data': {'note': note}})}\n',
          mode: FileMode.append,
        );
      }

      final assembler = PipelinePromptAssembler();
      final notes = assembler.readRecentReviewRejectNotes(layout, limit: 3);
      expect(notes, equals(['first', 'second', 'third']));
    });

    test('respects limit parameter', () {
      final temp = Directory.systemTemp.createTempSync('assembler_limit_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      final runLog = File(layout.runLogPath);
      for (final note in ['a', 'b', 'c', 'd']) {
        runLog.writeAsStringSync(
          '${jsonEncode({'event': 'review_reject', 'data': {'note': note}})}\n',
          mode: FileMode.append,
        );
      }

      final assembler = PipelinePromptAssembler();
      final notes = assembler.readRecentReviewRejectNotes(layout, limit: 2);
      expect(notes, hasLength(2));
      expect(notes, equals(['c', 'd']));
    });

    test('returns empty list when no reject events', () {
      final temp = Directory.systemTemp.createTempSync('assembler_empty_notes_');
      addTearDown(() => temp.deleteSync(recursive: true));
      ProjectInitializer(temp.path).ensureStructure(overwrite: true);
      final layout = ProjectLayout(temp.path);

      File(layout.runLogPath).writeAsStringSync(
        '${jsonEncode({'event': 'task_start', 'data': {}})}\n',
      );

      final assembler = PipelinePromptAssembler();
      final notes = assembler.readRecentReviewRejectNotes(layout);
      expect(notes, isEmpty);
    });
  });
}

class _NoopAnalysisAgentService extends AnalysisAgentService {
  @override
  Future<String> analyzeFailure(
    String projectRoot, {
    required String taskTitle,
    required String failureContext,
    String? lastAttemptOutput,
  }) async {
    return '';
  }
}

class _FakeAnalysisAgentService extends AnalysisAgentService {
  String? lastTaskTitle;
  String? lastFailureContext;

  @override
  Future<String> analyzeFailure(
    String projectRoot, {
    required String taskTitle,
    required String failureContext,
    String? lastAttemptOutput,
  }) async {
    lastTaskTitle = taskTitle;
    lastFailureContext = failureContext;
    return 'Analyzed: $taskTitle\nStrategy: Fix it.';
  }
}
