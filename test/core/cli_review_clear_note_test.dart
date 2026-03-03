import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  test('CLI review clear logs note in run log', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_review_clear_note_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final runner = CliRunner();
    await runner.run(['init', temp.path]);

    final layout = ProjectLayout(temp.path);

    await runner.run([
      'review',
      'clear',
      '--note',
      'Reset after fix',
      temp.path,
    ]);

    final logFile = File(layout.runLogPath);
    final lines = logFile.readAsLinesSync();
    expect(lines, isNotEmpty);
    final entry = lines
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .cast<Map<String, dynamic>>()
        .lastWhere((item) => item['event'] == 'review_cleared');
    final data = entry['data'] as Map<String, dynamic>;

    expect(data['note'], 'Reset after fix');
  });
}
