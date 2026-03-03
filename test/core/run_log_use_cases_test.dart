import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test(
    'ReadRunLogPageUseCase pages newest-first events with byte cursors',
    () async {
      final root = Directory.systemTemp.createTempSync('genaisys_run_log_');
      addTearDown(() {
        root.deleteSync(recursive: true);
      });

      final dot = Directory('${root.path}${Platform.pathSeparator}.genaisys')
        ..createSync(recursive: true);
      final logPath = '${dot.path}${Platform.pathSeparator}RUN_LOG.jsonl';
      File(logPath).writeAsStringSync('''
{"timestamp":"2026-02-10T00:00:00Z","event":"e1","message":"m1"}
{"timestamp":"2026-02-10T00:00:01Z","event":"e2","message":"m2"}
{"timestamp":"2026-02-10T00:00:02Z","event":"e3","message":"m3"}
{"timestamp":"2026-02-10T00:00:03Z","event":"e4","message":"m4"}
{"timestamp":"2026-02-10T00:00:04Z","event":"e5","message":"m5"}
''');

      final useCase = ReadRunLogPageUseCase();

      final first = await useCase.run(root.path, limit: 2);
      expect(first.ok, isTrue);
      expect(first.data, isNotNull);
      expect(first.data!.events.map((e) => e.event).toList(), <String>[
        'e5',
        'e4',
      ]);
      expect(first.data!.nextBeforeOffset, isNotNull);

      final second = await useCase.run(
        root.path,
        limit: 2,
        beforeOffset: first.data!.nextBeforeOffset,
      );
      expect(second.ok, isTrue);
      expect(second.data, isNotNull);
      expect(second.data!.events.map((e) => e.event).toList(), <String>[
        'e3',
        'e2',
      ]);
      expect(second.data!.nextBeforeOffset, isNotNull);

      final third = await useCase.run(
        root.path,
        limit: 2,
        beforeOffset: second.data!.nextBeforeOffset,
      );
      expect(third.ok, isTrue);
      expect(third.data, isNotNull);
      expect(third.data!.events.map((e) => e.event).toList(), <String>['e1']);
      expect(third.data!.nextBeforeOffset, isNull);
    },
  );

  test(
    'ReadRunLogPageUseCase returns empty page when log file is missing',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'genaisys_run_log_empty_',
      );
      addTearDown(() {
        root.deleteSync(recursive: true);
      });
      Directory(
        '${root.path}${Platform.pathSeparator}.genaisys',
      ).createSync(recursive: true);

      final result = await ReadRunLogPageUseCase().run(root.path);
      expect(result.ok, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.events, isEmpty);
      expect(result.data!.nextBeforeOffset, isNull);
    },
  );
}
