// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'config/quality_gate_profile.dart';
import 'project_layout.dart';
import 'storage/atomic_file_write.dart';
import 'templates/default_files.dart';

class ProjectInitializer {
  ProjectInitializer(this.projectRoot);

  final String projectRoot;

  ProjectLayout get layout => ProjectLayout(projectRoot);

  void ensureStructure({
    bool overwrite = false,
    QualityGateProfile? profile,
    bool hasRemote = true,
  }) {
    for (final dir in layout.requiredDirs) {
      Directory(dir).createSync(recursive: true);
    }

    _writeIfMissing(
      layout.gitignorePath,
      DefaultFiles.genaisysGitignore(),
      overwrite,
    );
    _writeIfMissing(layout.visionPath, DefaultFiles.vision(), overwrite);
    _writeIfMissing(layout.rulesPath, DefaultFiles.rules(), overwrite);
    _writeIfMissing(layout.tasksPath, DefaultFiles.tasks(), overwrite);
    _writeIfMissing(
      layout.rootVisionCompatPath,
      DefaultFiles.rootVisionCompat(),
      overwrite,
    );
    _writeIfMissing(
      layout.rootRulesCompatPath,
      DefaultFiles.rootRulesCompat(),
      overwrite,
    );
    _writeIfMissing(
      layout.rootTasksCompatPath,
      DefaultFiles.rootTasksCompat(),
      overwrite,
    );
    _writeIfMissing(layout.statePath, DefaultFiles.stateJson(), overwrite);
    _writeIfMissing(layout.runLogPath, '', overwrite);
    _writeIfMissing(
      layout.configPath,
      DefaultFiles.configYaml(profile: profile, hasRemote: hasRemote),
      overwrite,
    );
    _writeIfMissing(
      layout.evalBenchmarksPath,
      DefaultFiles.evalBenchmarks(),
      overwrite,
    );
    _writeIfMissing(
      layout.evalSummaryPath,
      DefaultFiles.evalSummary(),
      overwrite,
    );
    _writeIfMissing(layout.lessonsLearnedPath, '# Lessons Learned\n', overwrite);

    final contexts = DefaultFiles.agentContexts();
    contexts.forEach((fileName, content) {
      final path = _join(layout.agentContextsDir, fileName);
      _writeIfMissing(path, content, overwrite);
    });
  }

  void _writeIfMissing(String path, String content, bool overwrite) {
    final file = File(path);
    if (file.existsSync() && !overwrite) {
      return;
    }
    AtomicFileWrite.writeStringSync(path, content);
  }

  String _join(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
