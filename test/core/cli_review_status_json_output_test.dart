import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';
import 'package:genaisys/core/storage/state_store.dart';

import '../support/locked_dart_runner.dart';

void main() {
  test(
    'CLI review status --json returns valid JSON for escaped status',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_review_status_json_output_',
      );
      addTearDown(() {
        temp.deleteSync(recursive: true);
      });

      final runner = CliRunner();
      await runner.run(['init', temp.path]);

      final layout = ProjectLayout(temp.path);
      final store = StateStore(layout.statePath);
      store.write(
        store.read().copyWith(
          activeTask: store.read().activeTask.copyWith(
            reviewStatus: 'approved "manual"',
            reviewUpdatedAt: '2026-02-04T00:00:00Z',
          ),
        ),
      );

      final result = runLockedDartSync(<String>[
        'run',
        '--verbosity=error',
        '--',
        'bin/genaisys_cli.dart',
        'review',
        'status',
        '--json',
        temp.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = result.stdout.toString().trim();
      expect(output, isNotEmpty);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['review_status'], 'approved "manual"');
      expect(decoded['review_updated_at'], '2026-02-04T00:00:00Z');
    },
  );
}
