import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/app/use_cases/diagnostics_use_cases.dart';

import 'support/e2e_harness.dart';
import 'support/stub_agents.dart';

void main() {
  test(
    'E2E: dry-run does not mutate — all project files unchanged',
    () async {
      final harness = await E2EHarness.create(agentRunner: SuccessAgent());
      addTearDown(harness.dispose);

      harness.seedTasks('## Backlog\n- [ ] [P1] [CORE] Dry-run task\n');

      // Snapshot all files in .genaisys/ before dry-run.
      final snapshotBefore = _snapshotDirectory(
        '${harness.projectRoot}/.genaisys',
      );
      final commitsBefore = harness.gitCommitCount();

      // Run the dry-run use case (Phase 4 CLI command).
      final dryRunUseCase = AutopilotDryRunUseCase();
      final dryResult = await dryRunUseCase.run(harness.projectRoot);

      // The use case should return a result (ok or failure).
      expect(dryResult, isNotNull);

      // Verify no files changed.
      final snapshotAfter = _snapshotDirectory(
        '${harness.projectRoot}/.genaisys',
      );
      expect(
        snapshotAfter,
        equals(snapshotBefore),
        reason: 'Dry-run must not mutate .genaisys/ files',
      );

      // No new commits should be created.
      final commitsAfter = harness.gitCommitCount();
      expect(
        commitsAfter,
        equals(commitsBefore),
        reason: 'Dry-run must not create git commits',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Reads all files in a directory into a map of {relativePath: content}.
/// Used for before/after comparison.
Map<String, String> _snapshotDirectory(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return {};
  final snapshot = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = entity.path.substring(dirPath.length);
      try {
        snapshot[relativePath] = entity.readAsStringSync();
      } catch (_) {
        // Binary files — use length as a proxy.
        snapshot[relativePath] = 'binary:${entity.lengthSync()}';
      }
    }
  }
  return snapshot;
}
