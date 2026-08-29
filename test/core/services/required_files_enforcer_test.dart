import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/services/required_files_enforcer.dart';

void main() {
  late RequiredFilesEnforcer enforcer;

  setUp(() {
    enforcer = RequiredFilesEnforcer();
  });

  group('requiredFilesFromSpec', () {
    test('extracts non-optional files from spec Files section', () {
      final result = enforcer.requiredFilesFromSpec('''
# Task Spec

## Files
- `lib/core/config/project_config.dart` (modify)
- `lib/core/config/project_config_schema.dart` (new)
- `README.md` (optional)
''');

      expect(result, [
        'lib/core/config/project_config.dart',
        'lib/core/config/project_config_schema.dart',
      ]);
    });

    test('returns empty list for null spec', () {
      expect(enforcer.requiredFilesFromSpec(null), isEmpty);
    });

    test('returns empty list for spec without Files section', () {
      final result = enforcer.requiredFilesFromSpec('''
# Task Spec
## Summary
Just a description.
''');
      expect(result, isEmpty);
    });

    test('stops parsing at next section header', () {
      final result = enforcer.requiredFilesFromSpec('''
# Task Spec

## Files
- `lib/core/service.dart` (modify)

## Notes
- Some notes here
''');
      expect(result, ['lib/core/service.dart']);
    });

    test('ignores non-path bullets', () {
      final result = enforcer.requiredFilesFromSpec('''
# Task Spec

## Files
- `lib/core/config/project_config.dart` (modify)
- Update any impacted imports/usages across core
''');
      expect(result, ['lib/core/config/project_config.dart']);
    });
  });

  group('requiredFilesFromSubtask', () {
    test('extracts repo paths from backticked content', () {
      final result = enforcer.requiredFilesFromSubtask(
        'Create `lib/core/config/project_config_schema.dart` defining the model.',
      );
      expect(result, ['lib/core/config/project_config_schema.dart']);
    });

    test('returns null for null subtask', () {
      expect(enforcer.requiredFilesFromSubtask(null), isNull);
    });

    test('returns null for subtask without repo paths', () {
      expect(
        enforcer.requiredFilesFromSubtask('Baseline the current API surface.'),
        isNull,
      );
    });

    test('ignores bare filenames without directory prefix', () {
      expect(
        enforcer.requiredFilesFromSubtask(
          'Baseline in `in_process_genaisys_api.dart`.',
        ),
        isNull,
      );
    });

    test('deduplicates and sorts paths', () {
      final result = enforcer.requiredFilesFromSubtask(
        'Modify `lib/b.dart` and `lib/a.dart` and also `lib/b.dart`.',
      );
      expect(result, ['lib/a.dart', 'lib/b.dart']);
    });
  });

  group('missingRequiredFiles', () {
    test('returns empty when all required files are in changed paths', () {
      final result = enforcer.missingRequiredFiles(
        ['lib/core/service.dart', 'README.md'],
        ['lib/core/service.dart', 'README.md', 'lib/other.dart'],
      );
      expect(result, isEmpty);
    });

    test('returns missing files', () {
      final result = enforcer.missingRequiredFiles(
        ['lib/core/service.dart', 'README.md'],
        ['lib/other.dart'],
      );
      expect(result, ['lib/core/service.dart', 'README.md']);
    });

    test('returns empty for empty required list', () {
      expect(enforcer.missingRequiredFiles([], ['lib/a.dart']), isEmpty);
    });
  });

  group('hasAnyRequiredFile', () {
    test('returns true when at least one required file is changed', () {
      expect(
        enforcer.hasAnyRequiredFile(
          ['lib/a.dart', 'lib/b.dart'],
          ['lib/b.dart'],
        ),
        isTrue,
      );
    });

    test('returns false when no required file is changed', () {
      expect(
        enforcer.hasAnyRequiredFile(
          ['lib/a.dart', 'lib/b.dart'],
          ['lib/c.dart'],
        ),
        isFalse,
      );
    });

    test('returns true for empty required list', () {
      expect(enforcer.hasAnyRequiredFile([], ['lib/a.dart']), isTrue);
    });
  });

  group('matchesRequiredTarget', () {
    test('matches exact path', () {
      expect(
        enforcer.matchesRequiredTarget(
          'lib/core/service.dart',
          {'lib/core/service.dart'},
        ),
        isTrue,
      );
    });

    test('matches directory prefix without trailing slash', () {
      expect(
        enforcer.matchesRequiredTarget(
          'lib/core',
          {'lib/core/agents/provider_process_runner.dart'},
        ),
        isTrue,
      );
    });

    test('matches glob pattern with **', () {
      expect(
        enforcer.matchesRequiredTarget(
          'lib/core/**/task_cycle_service*.dart',
          {'lib/core/services/task_cycle_service.dart'},
        ),
        isTrue,
      );
    });

    test('does not match unrelated path', () {
      expect(
        enforcer.matchesRequiredTarget(
          'lib/core/service.dart',
          {'lib/ui/widget.dart'},
        ),
        isFalse,
      );
    });
  });

  group('deletedRequiredFiles', () {
    test('detects required files that are in diff but missing from disk', () {
      final temp = Directory.systemTemp.createTempSync('enforcer_deleted_');
      addTearDown(() => temp.deleteSync(recursive: true));

      final result = enforcer.deletedRequiredFiles(
        temp.path,
        ['lib/core/service.dart'],
        ['lib/core/service.dart'],
      );
      expect(result, ['lib/core/service.dart']);
    });

    test('does not flag files that exist on disk', () {
      final temp = Directory.systemTemp.createTempSync('enforcer_exists_');
      addTearDown(() => temp.deleteSync(recursive: true));
      Directory('${temp.path}/lib/core').createSync(recursive: true);
      File('${temp.path}/lib/core/service.dart').writeAsStringSync('// ok');

      final result = enforcer.deletedRequiredFiles(
        temp.path,
        ['lib/core/service.dart'],
        ['lib/core/service.dart'],
      );
      expect(result, isEmpty);
    });

    test('skips glob patterns', () {
      final temp = Directory.systemTemp.createTempSync('enforcer_glob_');
      addTearDown(() => temp.deleteSync(recursive: true));

      final result = enforcer.deletedRequiredFiles(
        temp.path,
        ['lib/core/**/*.dart'],
        ['lib/core/service.dart'],
      );
      expect(result, isEmpty);
    });
  });

  group('allRequiredFilesExistOnDisk', () {
    test('returns true when all files exist', () {
      final temp = Directory.systemTemp.createTempSync('enforcer_all_exist_');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/README.md').writeAsStringSync('# Hi');

      expect(
        enforcer.allRequiredFilesExistOnDisk(temp.path, ['README.md']),
        isTrue,
      );
    });

    test('returns false when a file is missing', () {
      final temp = Directory.systemTemp.createTempSync('enforcer_missing_');
      addTearDown(() => temp.deleteSync(recursive: true));

      expect(
        enforcer.allRequiredFilesExistOnDisk(temp.path, ['README.md']),
        isFalse,
      );
    });

    test('returns false for glob patterns', () {
      final temp = Directory.systemTemp.createTempSync('enforcer_glob_disk_');
      addTearDown(() => temp.deleteSync(recursive: true));

      expect(
        enforcer.allRequiredFilesExistOnDisk(temp.path, ['lib/**/*.dart']),
        isFalse,
      );
    });
  });

  group('filesSectionEntries', () {
    test('parses entries with backticked paths and optional markers', () {
      final entries = enforcer.filesSectionEntries('''
## Files
- `lib/core/service.dart` (modify)
- `README.md` (optional)
''');
      expect(entries, hasLength(2));
      expect(entries[0].path, 'lib/core/service.dart');
      expect(entries[0].optional, isFalse);
      expect(entries[1].path, 'README.md');
      expect(entries[1].optional, isTrue);
    });

    test('parses entries without backticks', () {
      final entries = enforcer.filesSectionEntries('''
## Files
- lib/core/service.dart
''');
      expect(entries, hasLength(1));
      expect(entries[0].path, 'lib/core/service.dart');
    });
  });

  group('looksLikeRepoPath', () {
    test('accepts standard prefixes', () {
      expect(enforcer.looksLikeRepoPath('lib/core/service.dart'), isTrue);
      expect(enforcer.looksLikeRepoPath('test/core/test.dart'), isTrue);
      expect(enforcer.looksLikeRepoPath('docs/guide.md'), isTrue);
      expect(enforcer.looksLikeRepoPath('bin/main.dart'), isTrue);
      expect(enforcer.looksLikeRepoPath('.genaisys/TASKS.md'), isTrue);
    });

    test('accepts known root files', () {
      expect(enforcer.looksLikeRepoPath('README.md'), isTrue);
      expect(enforcer.looksLikeRepoPath('pubspec.yaml'), isTrue);
    });

    test('rejects unknown root files', () {
      expect(enforcer.looksLikeRepoPath('random_file.txt'), isFalse);
    });

    test('rejects empty and invalid candidates', () {
      expect(enforcer.looksLikeRepoPath(''), isFalse);
      expect(enforcer.looksLikeRepoPath('Something:'), isFalse);
    });

    test('strips ./ prefix', () {
      expect(enforcer.looksLikeRepoPath('./lib/core/service.dart'), isTrue);
    });
  });
}
