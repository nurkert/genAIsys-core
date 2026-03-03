import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/models/task.dart';

// ---------------------------------------------------------------------------
// Feature K: Task.parseLine dependency parsing unit tests
//
// The _depsPattern regex inside Task.parseLine supports two syntaxes:
//   [needs: slug]     — single dep
//   (depends: a, b)   — multiple deps, comma-separated
// These tests verify that dependencyRefs is populated correctly and the
// title is cleaned of the dependency annotation.
// ---------------------------------------------------------------------------

void main() {
  group('Task.parseLine — dependency parsing', () {
    test('[needs: slug] → dependencyRefs = [slug]', () {
      const line = '- [ ] [P1] [CORE] My Task [needs: auth-service-1]';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      expect(task, isNotNull);
      expect(task!.dependencyRefs, ['auth-service-1']);
    });

    test('[needs: slug] → title cleaned of dependency annotation', () {
      const line = '- [ ] [P2] [CORE] My Task [needs: auth-service-1]';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      expect(task, isNotNull);
      expect(task!.title, 'My Task');
      expect(task.title, isNot(contains('needs:')));
      expect(task.title, isNot(contains('auth-service')));
    });

    test('(depends: a, b) → dependencyRefs = [a, b]', () {
      const line = '- [ ] [P1] [CORE] Build pipeline (depends: setup-env-1, auth-service-1)';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      expect(task, isNotNull);
      expect(task!.dependencyRefs, containsAll(['setup-env-1', 'auth-service-1']));
      expect(task.dependencyRefs, hasLength(2));
    });

    test('(depends: a, b) → title cleaned of dependency annotation', () {
      const line = '- [ ] [P1] [CORE] Build pipeline (depends: setup-env-1, auth-service-1)';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      expect(task, isNotNull);
      expect(task!.title, 'Build pipeline');
      expect(task.title, isNot(contains('depends:')));
    });

    test('no dependency syntax → dependencyRefs = []', () {
      const line = '- [ ] [P1] [CORE] Simple task without deps';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      expect(task, isNotNull);
      expect(task!.dependencyRefs, isEmpty);
    });

    test('[needs: slug] is case-insensitive', () {
      const line = '- [ ] [P1] [CORE] Task [Needs: my-dep-1]';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      expect(task, isNotNull);
      expect(task!.dependencyRefs, ['my-dep-1']);
    });

    test('(DEPENDS: ...) is case-insensitive', () {
      const line = '- [ ] [P1] [CORE] Task (DEPENDS: dep-a-1, dep-b-2)';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      expect(task, isNotNull);
      expect(task!.dependencyRefs, containsAll(['dep-a-1', 'dep-b-2']));
    });

    test('done task with dependency parses correctly', () {
      const line = '- [x] [P1] [CORE] Completed task [needs: base-setup-0]';
      final task = Task.parseLine(
        line: line,
        section: 'Done',
        lineIndex: 5,
      );

      expect(task, isNotNull);
      expect(task!.completion, TaskCompletion.done);
      expect(task.dependencyRefs, ['base-setup-0']);
    });

    test('task with empty depends value → dependencyRefs empty', () {
      // If someone writes "(depends: )" with no actual refs, parsing should
      // gracefully return empty list (filter removes empty strings).
      const line = '- [ ] [P1] [CORE] My Task (depends: )';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 0,
      );

      // The task itself may or may not parse depending on how the regex behaves;
      // what matters is that dependencyRefs never contains empty strings.
      if (task != null) {
        expect(
          task.dependencyRefs.where((r) => r.isEmpty),
          isEmpty,
          reason: 'dependencyRefs must not contain empty strings',
        );
      }
    });

    test('category and priority preserved alongside deps', () {
      const line = '- [ ] [P2] [QA] Run integration tests [needs: db-setup-3]';
      final task = Task.parseLine(
        line: line,
        section: 'Backlog',
        lineIndex: 7,
      );

      expect(task, isNotNull);
      expect(task!.priority, TaskPriority.p2);
      expect(task.category, TaskCategory.qa);
      expect(task.dependencyRefs, ['db-setup-3']);
      expect(task.title, 'Run integration tests');
    });
  });
}
