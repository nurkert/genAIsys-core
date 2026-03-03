// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../config/project_config.dart';
import '../models/task.dart';
import '../project_layout.dart';
import 'agents/analysis_agent_service.dart';
import 'architecture_context_service.dart';
import 'error_pattern_registry_service.dart';
import 'required_files_enforcer.dart';

/// Assembles the augmented coding prompt by injecting contextual sections
/// (forensic guidance, failure analysis, required-files block, error patterns,
/// impact analysis, architecture context) into the base prompt.
///
/// Dependencies: [AnalysisAgentService], [ErrorPatternRegistryService],
/// [ArchitectureContextService]. All other inputs are passed as parameters.
class PipelinePromptAssembler {
  PipelinePromptAssembler({
    AnalysisAgentService? analysisAgentService,
    ErrorPatternRegistryService? errorPatternRegistryService,
    ArchitectureContextService? architectureContextService,
  }) : _analysisAgentService = analysisAgentService ?? AnalysisAgentService(),
       _errorPatternRegistryService =
           errorPatternRegistryService ?? ErrorPatternRegistryService(),
       _architectureContextService =
           architectureContextService ?? ArchitectureContextService();

  final AnalysisAgentService _analysisAgentService;
  final ErrorPatternRegistryService _errorPatternRegistryService;
  final ArchitectureContextService _architectureContextService;

  /// Builds the fully augmented coding prompt from [codingPrompt] by appending
  /// context sections based on the current state and configuration.
  Future<String> assemble(
    String codingPrompt, {
    required String projectRoot,
    required ProjectConfig config,
    required TaskCategory resolvedCategory,
    required ProjectLayout layout,
    String? forensicGuidance,
    String? reviewStatus,
    String? lastError,
    String? activeTaskTitle,
    required List<String> requiredFiles,
    required RequiredFilesMode requiredFilesMode,
    int retryCount = 0,
    List<String> completedSubtaskTitles = const [],
  }) async {
    // Retry-context block: prepend before all other content so it is the
    // first thing the coding agent reads.
    var effectiveCodingPrompt = codingPrompt;
    if (retryCount >= 1) {
      final notes = readRecentReviewRejectNotes(layout, limit: 3);
      final retryBlock = _buildRetryContextBlock(retryCount, notes);
      effectiveCodingPrompt = '$retryBlock\n\n$codingPrompt';
    }
    var finalPrompt = effectiveCodingPrompt;

    // Forensic guidance injection (from previous forensic recovery).
    final trimmedForensic = forensicGuidance?.trim();
    if (trimmedForensic != null && trimmedForensic.isNotEmpty) {
      finalPrompt =
          '''
$finalPrompt

### FORENSIC GUIDANCE (from automated failure analysis)
$trimmedForensic

Apply this guidance to avoid repeating the previous failure pattern.
''';
    }

    if (reviewStatus == 'rejected') {
      final reviewNote = readLatestReviewRejectNote(layout);
      final fallback =
          lastError ?? 'Review rejected without specific error message.';
      final failureContext = reviewNote == null || reviewNote.trim().isEmpty
          ? fallback
          : reviewNote.trim();
      final analysis = await _analysisAgentService.analyzeFailure(
        projectRoot,
        taskTitle: activeTaskTitle ?? 'Unknown Task',
        failureContext: failureContext,
      );
      finalPrompt =
          '''
$effectiveCodingPrompt

### FAILURE ANALYSIS & STRATEGY
$analysis

Please follow the above strategy to resolve the issues.
''';
    }

    if (requiredFiles.isNotEmpty) {
      final requiredMessage = requiredFilesMode == RequiredFilesMode.allOf
          ? 'Your final git diff MUST include changes to the following required files:'
          : 'Your final git diff MUST include changes to at least one of the following target paths:';
      finalPrompt =
          '''
$finalPrompt

### REQUIRED FILE TARGETS (FROM TASK SPEC OR CURRENT SUBTASK)
$requiredMessage
${requiredFiles.map((path) => '- `$path`').join('\n')}

Do not invent alternate paths. If you cannot comply, output a short BLOCK reason.
''';
    }

    // Error pattern injection.
    if (config.pipelineErrorPatternInjectionEnabled) {
      final errorPatterns = _errorPatternRegistryService.formatForPrompt(
        projectRoot,
      );
      if (errorPatterns.isNotEmpty) {
        finalPrompt =
            '''
$finalPrompt

### KNOWN ERROR PATTERNS (from recent runs)
$errorPatterns

Avoid repeating these patterns in your implementation.
''';
      }
    }

    // Impact analysis injection.
    if (config.pipelineImpactAnalysisEnabled && requiredFiles.isNotEmpty) {
      final impactContext = _architectureContextService.assembleImpactContext(
        projectRoot,
        requiredFiles,
      );
      if (impactContext.isNotEmpty) {
        finalPrompt =
            '''
$finalPrompt

### IMPACT ANALYSIS
$impactContext

Consider these dependencies when making changes.
''';
      }
    }

    // Previously completed subtasks injection (Feature A).
    if (completedSubtaskTitles.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('### PREVIOUSLY COMPLETED SUBTASKS (THIS TASK)');
      for (final title in completedSubtaskTitles) {
        buffer.writeln('- ✓ $title');
      }
      buffer.writeln(
          'Do NOT re-implement the above. Build on top of them.\n---');
      finalPrompt = '$finalPrompt\n\n${buffer.toString()}';
    }

    // Lessons learned injection (Feature G).
    if (config.pipelineLessonsLearnedEnabled) {
      final lessons = _readLessonsLearned(layout);
      if (lessons != null && lessons.trim().isNotEmpty) {
        final trimmedLessons = lessons.length > 2000
            ? lessons.substring(lessons.length - 2000)
            : lessons;
        finalPrompt =
            '''
$finalPrompt

### LESSONS LEARNED (from past forensic recovery)
$trimmedLessons
---''';
      }
    }

    // Architecture context injection.
    if (config.pipelineContextInjectionEnabled) {
      final categoryBudget = config.contextInjectionMaxTokensForCategory(
        resolvedCategory.name,
      );
      final archContext = _architectureContextService.assemble(
        projectRoot,
        maxChars: categoryBudget,
      );
      if (archContext.isNotEmpty) {
        finalPrompt =
            '''
$finalPrompt

### ARCHITECTURE CONTEXT
$archContext
''';
      }
    }

    return finalPrompt;
  }

  /// Reads the lessons_learned.md file content, or null if missing/empty.
  String? _readLessonsLearned(ProjectLayout layout) {
    final file = File(layout.lessonsLearnedPath);
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync().trim();
      // Skip if file only contains the header line.
      if (content == '# Lessons Learned' || content.isEmpty) return null;
      return content;
    } catch (_) {
      return null;
    }
  }

  /// Reads the latest review reject note from the run log.
  String? readLatestReviewRejectNote(ProjectLayout layout) {
    final notes = readRecentReviewRejectNotes(layout, limit: 1);
    return notes.isEmpty ? null : notes.first;
  }

  /// Reads the most recent [limit] review reject notes from the run log,
  /// returned in chronological order (oldest first).
  List<String> readRecentReviewRejectNotes(
    ProjectLayout layout, {
    int limit = 3,
  }) {
    final file = File(layout.runLogPath);
    if (!file.existsSync()) {
      return const [];
    }
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      return const [];
    }
    final collected = <String>[];
    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final raw = lines[i].trim();
      if (raw.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final event = decoded['event']?.toString();
        if (event != 'review_reject') {
          continue;
        }
        final data = decoded['data'];
        if (data is Map) {
          final note = data['note']?.toString();
          if (note != null && note.trim().isNotEmpty) {
            collected.add(note.trim());
            if (collected.length >= limit) {
              break;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    // Reverse to get chronological order (oldest first).
    return collected.reversed.toList(growable: false);
  }

  /// Builds the retry-context block prepended to the coding prompt when
  /// [retryCount] >= 1. Lists previous reviewer feedback in order.
  String _buildRetryContextBlock(int retryCount, List<String> notes) {
    final buffer = StringBuffer();
    buffer.writeln('⚠ RETRY ATTEMPT $retryCount — Previous reviewer feedback:');
    if (notes.isEmpty) {
      buffer.writeln('(No specific notes recorded.)');
    } else {
      for (var i = 0; i < notes.length; i += 1) {
        buffer.writeln('Attempt ${i + 1}: ${notes[i]}');
      }
    }
    buffer.writeln('Address ALL of the above before anything else.');
    buffer.write('---');
    return buffer.toString();
  }
}
