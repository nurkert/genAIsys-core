import 'dart:io';

import 'package:genaisys/core/project_initializer.dart';
import 'package:genaisys/core/project_layout.dart';

class TestWorkspace {
  TestWorkspace._(this.root) : layout = ProjectLayout(root.path);

  final Directory root;
  final ProjectLayout layout;

  static TestWorkspace create({String prefix = 'genaisys_test_'}) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    return TestWorkspace._(dir);
  }

  void ensureStructure({bool overwrite = false}) {
    ProjectInitializer(root.path).ensureStructure(overwrite: overwrite);
  }

  void writeTasks(String contents) {
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.tasksPath).writeAsStringSync(contents);
  }

  void writeConfig(String contents) {
    Directory(layout.genaisysDir).createSync(recursive: true);
    File(layout.configPath).writeAsStringSync(contents);
  }

  void writeRunLog(List<String> lines) {
    Directory(layout.genaisysDir).createSync(recursive: true);
    final file = File(layout.runLogPath);
    file.writeAsStringSync('${lines.join('\n')}\n');
  }

  void dispose() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}
