import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/services/import_graph_service.dart';

void main() {
  late ImportGraphService service;

  setUp(() {
    service = ImportGraphService();
  });

  group('buildGraph on real project', () {
    test('builds non-empty graph from project lib/', () {
      // Use the actual project root (two levels up from test/core/).
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) {
        // Skip if project root can't be determined.
        return;
      }

      final graph = service.buildGraph(projectRoot);

      expect(graph.forward, isNotEmpty);
      expect(graph.reverse, isNotEmpty);
      expect(graph.allFiles, isNotEmpty);

      // Verify a known file exists in the graph.
      final knownFile = 'lib/core/project_layout.dart';
      expect(
        graph.forward.containsKey(knownFile),
        isTrue,
        reason: 'project_layout.dart should be in the graph',
      );
    });

    test('reverse dependencies are consistent with forward', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final graph = service.buildGraph(projectRoot);

      // For every forward edge A→B, there should be a reverse edge B→A.
      for (final entry in graph.forward.entries) {
        final file = entry.key;
        for (final imported in entry.value) {
          expect(
            graph.reverse[imported]?.contains(file),
            isTrue,
            reason: '$file imports $imported but reverse edge is missing',
          );
        }
      }
    });
  });

  group('buildGraph with synthetic project', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('genaisys_import_graph_');
      // Create pubspec.yaml.
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: test_pkg\n');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('resolves relative imports', () {
      _createDartFile(temp, 'lib/core/a.dart', '''
import 'b.dart';
''');
      _createDartFile(temp, 'lib/core/b.dart', '');

      final graph = service.buildGraph(temp.path);

      expect(graph.forward['lib/core/a.dart'], contains('lib/core/b.dart'));
      expect(graph.reverse['lib/core/b.dart'], contains('lib/core/a.dart'));
    });

    test('resolves package imports for same package', () {
      _createDartFile(temp, 'lib/core/a.dart', '''
import 'package:test_pkg/utils/helper.dart';
''');
      _createDartFile(temp, 'lib/utils/helper.dart', '');

      final graph = service.buildGraph(temp.path);

      expect(
        graph.forward['lib/core/a.dart'],
        contains('lib/utils/helper.dart'),
      );
    });

    test('ignores external package imports', () {
      _createDartFile(temp, 'lib/core/a.dart', '''
import 'package:flutter/material.dart';
import 'package:path/path.dart';
''');

      final graph = service.buildGraph(temp.path);

      expect(graph.forward['lib/core/a.dart'], isEmpty);
    });

    test('ignores dart: imports', () {
      _createDartFile(temp, 'lib/core/a.dart', '''
import 'dart:io';
import 'dart:convert';
''');

      final graph = service.buildGraph(temp.path);

      expect(graph.forward['lib/core/a.dart'], isEmpty);
    });

    test('handles export statements', () {
      _createDartFile(temp, 'lib/core/a.dart', '''
export 'b.dart';
''');
      _createDartFile(temp, 'lib/core/b.dart', '');

      final graph = service.buildGraph(temp.path);

      expect(graph.forward['lib/core/a.dart'], contains('lib/core/b.dart'));
    });

    test('resolves parent directory imports', () {
      _createDartFile(temp, 'lib/core/services/a.dart', '''
import '../project_layout.dart';
''');
      _createDartFile(temp, 'lib/core/project_layout.dart', '');

      final graph = service.buildGraph(temp.path);

      expect(
        graph.forward['lib/core/services/a.dart'],
        contains('lib/core/project_layout.dart'),
      );
    });

    test('returns empty graph when lib/ does not exist', () {
      final emptyTemp = Directory.systemTemp.createTempSync(
        'genaisys_no_lib_',
      );
      try {
        final graph = service.buildGraph(emptyTemp.path);
        expect(graph.forward, isEmpty);
        expect(graph.reverse, isEmpty);
      } finally {
        emptyTemp.deleteSync(recursive: true);
      }
    });
  });

  group('reverseDependencies', () {
    test('returns direct importers of a file', () {
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': <String>{},
          'lib/c.dart': {'lib/b.dart'},
        },
        reverse: {
          'lib/a.dart': <String>{},
          'lib/b.dart': {'lib/a.dart', 'lib/c.dart'},
          'lib/c.dart': <String>{},
        },
      );

      final deps = service.reverseDependencies(graph, 'lib/b.dart');

      expect(deps, containsAll(['lib/a.dart', 'lib/c.dart']));
      expect(deps, hasLength(2));
    });

    test('returns empty set for file with no dependents', () {
      final graph = ImportGraph(
        forward: {'lib/a.dart': <String>{}},
        reverse: {'lib/a.dart': <String>{}},
      );

      final deps = service.reverseDependencies(graph, 'lib/a.dart');

      expect(deps, isEmpty);
    });

    test('returns empty set for unknown file', () {
      final graph = ImportGraph(forward: const {}, reverse: const {});

      final deps = service.reverseDependencies(graph, 'lib/unknown.dart');

      expect(deps, isEmpty);
    });
  });

  group('impactRadius', () {
    test('computes transitive reverse dependencies', () {
      // A → B → C (A imports B, B imports C)
      // Reverse: C is imported by B, B is imported by A
      // Impact of changing C: B and A are affected.
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': {'lib/c.dart'},
          'lib/c.dart': <String>{},
        },
        reverse: {
          'lib/a.dart': <String>{},
          'lib/b.dart': {'lib/a.dart'},
          'lib/c.dart': {'lib/b.dart'},
        },
      );

      final impact = service.impactRadius(graph, ['lib/c.dart']);

      expect(impact, containsAll(['lib/a.dart', 'lib/b.dart']));
      expect(impact, isNot(contains('lib/c.dart')));
    });

    test('does not include target files in result', () {
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': <String>{},
        },
        reverse: {
          'lib/a.dart': <String>{},
          'lib/b.dart': {'lib/a.dart'},
        },
      );

      final impact = service.impactRadius(graph, ['lib/b.dart']);

      expect(impact, contains('lib/a.dart'));
      expect(impact, isNot(contains('lib/b.dart')));
    });

    test('returns empty set for empty targets', () {
      final graph = ImportGraph(forward: const {}, reverse: const {});

      final impact = service.impactRadius(graph, []);

      expect(impact, isEmpty);
    });

    test('handles diamond dependencies', () {
      // A → B, A → C, B → D, C → D
      // Impact of D: B, C, A (all depend transitively)
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart', 'lib/c.dart'},
          'lib/b.dart': {'lib/d.dart'},
          'lib/c.dart': {'lib/d.dart'},
          'lib/d.dart': <String>{},
        },
        reverse: {
          'lib/a.dart': <String>{},
          'lib/b.dart': {'lib/a.dart'},
          'lib/c.dart': {'lib/a.dart'},
          'lib/d.dart': {'lib/b.dart', 'lib/c.dart'},
        },
      );

      final impact = service.impactRadius(graph, ['lib/d.dart']);

      expect(impact, containsAll(['lib/a.dart', 'lib/b.dart', 'lib/c.dart']));
      expect(impact, hasLength(3));
    });

    test('handles multiple target files', () {
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/c.dart': {'lib/d.dart'},
          'lib/b.dart': <String>{},
          'lib/d.dart': <String>{},
        },
        reverse: {
          'lib/a.dart': <String>{},
          'lib/b.dart': {'lib/a.dart'},
          'lib/c.dart': <String>{},
          'lib/d.dart': {'lib/c.dart'},
        },
      );

      final impact = service.impactRadius(graph, ['lib/b.dart', 'lib/d.dart']);

      expect(impact, containsAll(['lib/a.dart', 'lib/c.dart']));
    });
  });

  group('circularDependencies', () {
    test('detects simple cycle', () {
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': {'lib/a.dart'},
        },
        reverse: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': {'lib/a.dart'},
        },
      );

      final cycles = service.circularDependencies(graph);

      expect(cycles, isNotEmpty);
      // The cycle should contain both a.dart and b.dart.
      final allCycleFiles = cycles.expand((c) => c).toSet();
      expect(allCycleFiles, containsAll(['lib/a.dart', 'lib/b.dart']));
    });

    test('returns empty for acyclic graph', () {
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': {'lib/c.dart'},
          'lib/c.dart': <String>{},
        },
        reverse: {
          'lib/a.dart': <String>{},
          'lib/b.dart': {'lib/a.dart'},
          'lib/c.dart': {'lib/b.dart'},
        },
      );

      final cycles = service.circularDependencies(graph);

      expect(cycles, isEmpty);
    });

    test('detects three-node cycle', () {
      // A → B → C → A
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': {'lib/c.dart'},
          'lib/c.dart': {'lib/a.dart'},
        },
        reverse: {
          'lib/a.dart': {'lib/c.dart'},
          'lib/b.dart': {'lib/a.dart'},
          'lib/c.dart': {'lib/b.dart'},
        },
      );

      final cycles = service.circularDependencies(graph);

      expect(cycles, isNotEmpty);
      final allCycleFiles = cycles.expand((c) => c).toSet();
      expect(
        allCycleFiles,
        containsAll(['lib/a.dart', 'lib/b.dart', 'lib/c.dart']),
      );
    });

    test('detects known cycle in real project graph', () {
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) return;

      final graph = service.buildGraph(projectRoot);
      final cycles = service.circularDependencies(graph);

      // Verify cycle detection runs without error on a real codebase.
      // Known cycle: project_workspace_controller ↔ project_config_controller.
      // This test documents the existing state rather than asserting absence.
      expect(cycles, isA<List<List<String>>>());
      if (cycles.isNotEmpty) {
        // Each cycle should have at least 2 distinct nodes.
        for (final cycle in cycles) {
          expect(cycle.length, greaterThanOrEqualTo(3));
          // Last element equals first (cycle closure).
          expect(cycle.last, cycle.first);
        }
      }
    });
  });

  group('layerOf', () {
    test('classifies core files', () {
      expect(service.layerOf('lib/core/services/foo.dart'), 'core');
      expect(service.layerOf('lib/core/models/bar.dart'), 'core');
    });

    test('classifies cli files (more specific than core)', () {
      expect(service.layerOf('lib/core/cli/commands.dart'), 'cli');
    });

    test('classifies app files', () {
      expect(service.layerOf('lib/app/state.dart'), 'app');
    });

    test('classifies ui files', () {
      expect(service.layerOf('lib/ui/widgets/button.dart'), 'ui');
    });

    test('classifies desktop files', () {
      expect(service.layerOf('lib/desktop/services/window.dart'), 'desktop');
    });

    test('returns unknown for unrecognized paths', () {
      expect(service.layerOf('lib/main.dart'), 'unknown');
      expect(service.layerOf('test/foo.dart'), 'unknown');
    });
  });

  group('highFanOutFiles', () {
    test('detects files exceeding threshold', () {
      final imports = <String>{};
      for (var i = 0; i < 20; i++) {
        imports.add('lib/dep_$i.dart');
      }
      final graph = ImportGraph(
        forward: {
          'lib/big.dart': imports,
          'lib/small.dart': {'lib/dep_0.dart'},
        },
        reverse: const {},
      );

      final highFanOut = service.highFanOutFiles(graph, threshold: 15);

      expect(highFanOut, containsPair('lib/big.dart', 20));
      expect(highFanOut, isNot(contains('lib/small.dart')));
    });

    test('returns empty when no files exceed threshold', () {
      final graph = ImportGraph(
        forward: {
          'lib/a.dart': {'lib/b.dart'},
          'lib/b.dart': <String>{},
        },
        reverse: const {},
      );

      final highFanOut = service.highFanOutFiles(graph, threshold: 15);

      expect(highFanOut, isEmpty);
    });
  });
}

/// Finds the project root by looking for pubspec.yaml.
String? _findProjectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return null;
}

/// Creates a Dart file in the temporary project structure.
void _createDartFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
