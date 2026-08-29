import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/services/vision_alignment_service.dart';

/// Sample VISION.md content with a Goals section for testing.
const _sampleVision = '''# Vision (Short)

## Mission
Genaisys is a desktop orchestrator for AI-assisted software delivery.

## Goals (High-Level)
- Reliable desktop-first orchestration with a strict core/UI split.
- Mandatory independent review gate before any task is considered done.
- Autonomous, incremental execution of roadmap tasks in small controlled steps.
- Robust git workflow: branch-per-task, review-gated commit/push/merge, conflict recovery.
- Hardened agent runtime: timeouts, budgets, strict policies, and deterministic safeguards.

## Constraints / Invariants
- No task completion without review approval.
''';

/// A minimal VISION.md without a Goals section.
const _visionNoGoals = '''# Vision (Short)

## Mission
Genaisys is a desktop orchestrator.

## Constraints
- No task completion without review approval.
''';

/// TASKS.md with a mix of open and completed tasks for drift/gap testing.
const _sampleTasks = '''# Tasks

## Backlog
- [ ] [P1] [CORE] Implement review gate enforcement
- [ ] [P2] [CORE] Add agent timeout budgets
- [x] [P1] [CORE] Build desktop orchestration pipeline
- [x] [P1] [CORE] Implement git branch-per-task workflow
- [x] [P2] [DOCS] Update README formatting
- [x] [P2] [DOCS] Write changelog notes
- [x] [P2] [DOCS] Fix typo in license header
''';

/// TASKS.md where all completed tasks are well aligned with vision.
const _alignedTasks = '''# Tasks

## Backlog
- [x] [P1] [CORE] Build reliable desktop orchestration service
- [x] [P1] [CORE] Implement mandatory review gate before done
- [x] [P1] [CORE] Add autonomous incremental task execution
- [x] [P1] [CORE] Implement robust git workflow with conflict recovery
- [x] [P1] [SEC] Harden agent runtime with timeouts and budgets
''';

/// TASKS.md where no completed tasks align with vision goals.
const _driftedTasks = '''# Tasks

## Backlog
- [x] [P3] [UI] Polish button colors
- [x] [P3] [UI] Adjust sidebar animation speed
- [x] [P3] [UI] Tweak font sizes for headers
- [x] [P3] [UI] Add loading spinner placeholder
- [x] [P3] [UI] Fix tooltip positioning offset
''';

void main() {
  late Directory temp;
  late ProjectLayout layout;
  late VisionAlignmentService service;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('genaisys_vision_alignment_');
    layout = ProjectLayout(temp.path);

    // Create the required directory structure.
    Directory(layout.genaisysDir).createSync(recursive: true);
    Directory(layout.auditDir).createSync(recursive: true);
    Directory(layout.locksDir).createSync(recursive: true);

    service = VisionAlignmentService();
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  group('extractGoals', () {
    test('extracts goals from standard VISION.md', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);

      final goals = service.extractGoals(temp.path);

      expect(goals.length, 5);
      expect(goals[0].text, contains('desktop-first orchestration'));
      expect(goals[0].keywords, isNotEmpty);
      expect(goals[1].text, contains('review gate'));
    });

    test('returns empty list when VISION.md is missing', () {
      final goals = service.extractGoals(temp.path);
      expect(goals, isEmpty);
    });

    test('returns empty list when VISION.md has no Goals section', () {
      File(layout.visionPath).writeAsStringSync(_visionNoGoals);

      final goals = service.extractGoals(temp.path);
      expect(goals, isEmpty);
    });

    test('excludes goals with fewer than 2 keywords', () {
      // A goal with very short or only stop-word text.
      const tinyGoals = '''# Vision

## Goals
- The best.
- Reliable desktop-first orchestration with a strict core/UI split.
''';
      File(layout.visionPath).writeAsStringSync(tinyGoals);

      final goals = service.extractGoals(temp.path);
      // "The best." after stop-word removal → "best" (1 keyword) → excluded.
      // "Reliable desktop-first orchestration ..." → multiple keywords → included.
      expect(goals.length, 1);
      expect(goals[0].text, contains('orchestration'));
    });

    test('strips trailing Details: references from goal text', () {
      const visionWithDetails = '''# Vision

## Goals (High-Level)
- Reliable orchestration with core/UI split. Details: see docs/foo.md
''';
      File(layout.visionPath).writeAsStringSync(visionWithDetails);

      final goals = service.extractGoals(temp.path);
      expect(goals, isNotEmpty);
      expect(goals[0].text, isNot(contains('Details:')));
      expect(goals[0].text, contains('orchestration'));
    });

    test('skips indented sub-bullets', () {
      const visionWithSubBullets = '''# Vision

## Goals
- Reliable desktop-first orchestration.
  - Sub-detail about implementation approach.
- Mandatory review gate before task completion.
''';
      File(layout.visionPath).writeAsStringSync(visionWithSubBullets);

      final goals = service.extractGoals(temp.path);
      expect(goals.length, 2);
      // Sub-bullet should not appear as a goal.
      for (final goal in goals) {
        expect(goal.text, isNot(contains('Sub-detail')));
      }
    });

    test('stops collecting goals at next heading', () {
      const visionMultiSection = '''# Vision

## Goals
- Reliable orchestration with core/UI split.

## Constraints
- No task completion without review.
''';
      File(layout.visionPath).writeAsStringSync(visionMultiSection);

      final goals = service.extractGoals(temp.path);
      expect(goals.length, 1);
      expect(goals[0].text, contains('orchestration'));
    });
  });

  group('scoreAlignment', () {
    test('returns 0.0 when goals are empty', () {
      final score = service.scoreAlignment('Some task', const []);

      expect(score.taskTitle, 'Some task');
      expect(score.score, 0.0);
      expect(score.matchedGoals, isEmpty);
    });

    test('returns 0.0 for unrelated task', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      final goals = service.extractGoals(temp.path);

      final score = service.scoreAlignment(
        'Polish button hover animations',
        goals,
      );

      expect(score.score, 0.0);
      expect(score.matchedGoals, isEmpty);
    });

    test('returns positive score for aligned task', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      final goals = service.extractGoals(temp.path);

      final score = service.scoreAlignment(
        'Implement review gate enforcement',
        goals,
      );

      expect(score.score, greaterThan(0.0));
      expect(score.matchedGoals, isNotEmpty);
    });

    test('returns higher score for better matches', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      final goals = service.extractGoals(temp.path);

      final strongMatch = service.scoreAlignment(
        'Implement mandatory independent review gate',
        goals,
      );
      final weakMatch = service.scoreAlignment(
        'Implement independent logging utility',
        goals,
      );

      expect(strongMatch.score, greaterThan(weakMatch.score));
    });

    test('score is clamped to [0.0, 1.0]', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      final goals = service.extractGoals(temp.path);

      final score = service.scoreAlignment(
        'Reliable desktop-first orchestration with strict core UI split',
        goals,
      );

      expect(score.score, greaterThanOrEqualTo(0.0));
      expect(score.score, lessThanOrEqualTo(1.0));
    });

    test('handles task title with only stop words', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      final goals = service.extractGoals(temp.path);

      final score = service.scoreAlignment('the and or is', goals);

      expect(score.score, 0.0);
    });
  });

  group('detectDrift', () {
    test('returns no drift when VISION.md is missing', () {
      // No VISION.md, only TASKS.md.
      File(layout.tasksPath).writeAsStringSync(_sampleTasks);
      // Ensure run log exists.
      File(layout.runLogPath).writeAsStringSync('');

      final drift = service.detectDrift(temp.path);

      expect(drift.driftDetected, isFalse);
      expect(drift.totalCount, 0);
      expect(drift.alignmentRate, 1.0);
    });

    test('returns no drift when no completed tasks exist', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Pending task one
- [ ] [P2] [CORE] Pending task two
''');
      File(layout.runLogPath).writeAsStringSync('');

      final drift = service.detectDrift(temp.path);

      expect(drift.driftDetected, isFalse);
      expect(drift.totalCount, 0);
    });

    test('detects drift when recent tasks are unrelated to vision', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      File(layout.tasksPath).writeAsStringSync(_driftedTasks);
      File(layout.runLogPath).writeAsStringSync('');

      final drift = service.detectDrift(temp.path);

      expect(drift.driftDetected, isTrue);
      expect(drift.alignmentRate, lessThan(0.30));
      expect(drift.totalCount, 5);
    });

    test('returns no drift when tasks are well aligned', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      File(layout.tasksPath).writeAsStringSync(_alignedTasks);
      File(layout.runLogPath).writeAsStringSync('');

      final drift = service.detectDrift(temp.path);

      expect(drift.driftDetected, isFalse);
      expect(drift.alignmentRate, greaterThanOrEqualTo(0.30));
      expect(drift.alignedCount, greaterThan(0));
    });

    test('logs vision_drift_detected event when drift occurs', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      File(layout.tasksPath).writeAsStringSync(_driftedTasks);
      File(layout.runLogPath).writeAsStringSync('');

      service.detectDrift(temp.path);

      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, contains('"event":"vision_drift_detected"'));
      expect(log, contains('"alignment_rate"'));
    });

    test('does not log drift event when alignment is good', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      File(layout.tasksPath).writeAsStringSync(_alignedTasks);
      File(layout.runLogPath).writeAsStringSync('');

      service.detectDrift(temp.path);

      final log = File(layout.runLogPath).readAsStringSync();
      expect(log, isNot(contains('vision_drift_detected')));
    });

    test('respects windowSize parameter', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      // 5 drifted tasks + 2 aligned tasks.
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [x] [P1] [CORE] Build desktop orchestration pipeline
- [x] [P1] [CORE] Implement review gate enforcement
- [x] [P3] [UI] Polish button colors
- [x] [P3] [UI] Adjust sidebar animation speed
- [x] [P3] [UI] Tweak font sizes for headers
- [x] [P3] [UI] Add loading spinner placeholder
- [x] [P3] [UI] Fix tooltip positioning offset
''');
      File(layout.runLogPath).writeAsStringSync('');

      // With windowSize=2, only last 2 UI tasks → drifted.
      final smallWindow = service.detectDrift(temp.path, windowSize: 2);
      expect(smallWindow.totalCount, 2);
      expect(smallWindow.driftDetected, isTrue);

      // With windowSize=20 (all 7 tasks), includes aligned ones.
      final largeWindow = service.detectDrift(temp.path, windowSize: 20);
      expect(largeWindow.totalCount, 7);
    });
  });

  group('findGaps', () {
    test('returns empty when VISION.md is missing', () {
      File(layout.tasksPath).writeAsStringSync(_sampleTasks);

      final gaps = service.findGaps(temp.path);

      expect(gaps.totalGoals, 0);
      expect(gaps.coveredGoals, 0);
      expect(gaps.uncoveredGoals, isEmpty);
    });

    test('identifies uncovered goals', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      // Only tasks related to review and git — other goals uncovered.
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Implement review gate enforcement
- [ ] [P1] [CORE] Build git workflow with conflict recovery
''');

      final gaps = service.findGaps(temp.path);

      expect(gaps.totalGoals, 5);
      expect(gaps.coveredGoals, greaterThan(0));
      expect(gaps.uncoveredGoals, isNotEmpty);
      // At least some goals should be uncovered since we only have 2 tasks.
      expect(
        gaps.coveredGoals + gaps.uncoveredGoals.length,
        equals(gaps.totalGoals),
      );
    });

    test('reports all goals as covered when tasks span all goals', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      // Tasks matching all 5 goals.
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Build reliable desktop-first orchestration with core/UI split
- [ ] [P1] [CORE] Implement mandatory independent review gate
- [ ] [P1] [CORE] Add autonomous incremental execution of roadmap tasks
- [ ] [P1] [CORE] Implement robust git workflow branch-per-task conflict recovery
- [ ] [P1] [SEC] Harden agent runtime timeouts budgets strict policies deterministic safeguards
''');

      final gaps = service.findGaps(temp.path);

      expect(gaps.totalGoals, 5);
      expect(gaps.coveredGoals, 5);
      expect(gaps.uncoveredGoals, isEmpty);
    });

    test('reports all goals as uncovered when tasks are unrelated', () {
      File(layout.visionPath).writeAsStringSync(_sampleVision);
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P3] [UI] Polish button hover animations
- [ ] [P3] [UI] Adjust loading spinner color
''');

      final gaps = service.findGaps(temp.path);

      expect(gaps.totalGoals, 5);
      expect(gaps.uncoveredGoals.length, 5);
      expect(gaps.coveredGoals, 0);
    });

    test('considers both open and completed tasks for coverage', () {
      File(layout.visionPath).writeAsStringSync('''# Vision

## Goals
- Reliable desktop-first orchestration with core/UI split.
- Mandatory review gate before done.
''');
      File(layout.tasksPath).writeAsStringSync('''# Tasks

## Backlog
- [ ] [P1] [CORE] Build reliable desktop orchestration
- [x] [P1] [CORE] Implement mandatory review gate
''');

      final gaps = service.findGaps(temp.path);

      // Both open and completed tasks should count for coverage.
      expect(gaps.totalGoals, 2);
      expect(gaps.coveredGoals, 2);
      expect(gaps.uncoveredGoals, isEmpty);
    });
  });

  group('integration with ProductivityReflectionResult', () {
    test('drift and gaps can be included in result', () {
      // This tests the data model, not the full reflection flow.
      const drift = DriftReport(
        alignedCount: 3,
        totalCount: 10,
        alignmentRate: 0.3,
        driftDetected: false,
      );
      const gaps = GapReport(
        totalGoals: 5,
        coveredGoals: 3,
        uncoveredGoals: ['Goal A', 'Goal B'],
      );

      // Verify the data classes hold their values correctly.
      expect(drift.alignedCount, 3);
      expect(drift.totalCount, 10);
      expect(drift.alignmentRate, 0.3);
      expect(drift.driftDetected, isFalse);
      expect(gaps.totalGoals, 5);
      expect(gaps.coveredGoals, 3);
      expect(gaps.uncoveredGoals, hasLength(2));
    });
  });

  group('keyword extraction edge cases', () {
    test('handles special characters in titles', () {
      File(layout.visionPath).writeAsStringSync('''# Vision

## Goals
- Implement CI/CD pipeline with automated testing.
''');

      final goals = service.extractGoals(temp.path);
      expect(goals, isNotEmpty);

      // A task with special characters should still score.
      final score = service.scoreAlignment(
        'Implement CI/CD pipeline automation',
        goals,
      );
      expect(score.score, greaterThan(0.0));
    });

    test('handles hyphenated words', () {
      File(layout.visionPath).writeAsStringSync('''# Vision

## Goals
- Desktop-first orchestration with branch-per-task workflow.
''');

      final goals = service.extractGoals(temp.path);
      expect(goals, isNotEmpty);

      // "desktop-first" splits to "desktop" and "first" after regex.
      final score = service.scoreAlignment(
        'Build desktop orchestration',
        goals,
      );
      expect(score.score, greaterThan(0.0));
    });
  });
}
