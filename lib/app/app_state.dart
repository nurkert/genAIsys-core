// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

enum AppSection { project, dashboard, tasks, review, autopilot, settings }

class AppState {
  const AppState({
    this.projectRoot,
    this.projectExists = false,
    this.genaisysReady = false,
    this.busy = false,
    this.errorMessage,
    this.section = AppSection.project,
  });

  final String? projectRoot;
  final bool projectExists;
  final bool genaisysReady;
  final bool busy;
  final String? errorMessage;
  final AppSection section;

  static const _sentinel = Object();

  AppState copyWith({
    String? projectRoot,
    bool? projectExists,
    bool? genaisysReady,
    bool? busy,
    Object? errorMessage = _sentinel,
    AppSection? section,
  }) {
    return AppState(
      projectRoot: projectRoot ?? this.projectRoot,
      projectExists: projectExists ?? this.projectExists,
      genaisysReady: genaisysReady ?? this.genaisysReady,
      busy: busy ?? this.busy,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      section: section ?? this.section,
    );
  }
}
