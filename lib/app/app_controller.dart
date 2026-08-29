// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/app/app.dart';
import '../core/gui/gui_initialize_project_use_case.dart';
import '../core/project_layout.dart';
import 'app_services.dart';
import 'app_state.dart';

class AppController extends ChangeNotifier {
  factory AppController({
    GenaisysApi? api,
    AppServices? services,
    GetStatusUseCase? statusUseCase,
    GuiInitializeProjectUseCase? initUseCase,
  }) {
    final resolvedServices = services ?? AppServices(api: api);
    return AppController._internal(
      services: resolvedServices,
      statusUseCase: statusUseCase ?? resolvedServices.status,
      initUseCase: initUseCase ?? resolvedServices.initializeProject,
    );
  }

  AppController._internal({
    required this.services,
    required GetStatusUseCase statusUseCase,
    required GuiInitializeProjectUseCase initUseCase,
  }) : _statusUseCase = statusUseCase,
       _initUseCase = initUseCase;

  final AppServices services;
  final GetStatusUseCase _statusUseCase;
  final GuiInitializeProjectUseCase _initUseCase;

  AppState _state = const AppState();
  AppState get state => _state;

  void setSection(AppSection section) {
    _state = _state.copyWith(section: section);
    notifyListeners();
  }

  void clearError() {
    if (_state.errorMessage == null) {
      return;
    }
    _state = _state.copyWith(errorMessage: null);
    notifyListeners();
  }

  Future<void> selectProject(String? projectRoot) async {
    if (projectRoot == null || projectRoot.trim().isEmpty) {
      _state = _state.copyWith(
        projectRoot: null,
        projectExists: false,
        genaisysReady: false,
        errorMessage: 'Bitte ein gültiges Projektverzeichnis wählen.',
        section: AppSection.project,
      );
      notifyListeners();
      return;
    }

    final normalized = projectRoot.trim();
    _state = _state.copyWith(
      projectRoot: normalized,
      busy: true,
      errorMessage: null,
    );
    notifyListeners();

    final rootDir = Directory(normalized);
    final hasRoot = rootDir.existsSync();
    final hasGenaisys = Directory(
      ProjectLayout(normalized).genaisysDir,
    ).existsSync();

    if (!hasRoot) {
      _state = _state.copyWith(
        busy: false,
        projectExists: false,
        genaisysReady: false,
        errorMessage: 'Projektverzeichnis existiert nicht.',
        section: AppSection.project,
      );
      notifyListeners();
      return;
    }

    if (!hasGenaisys) {
      _state = _state.copyWith(
        busy: false,
        projectExists: true,
        genaisysReady: false,
        section: AppSection.project,
      );
      notifyListeners();
      return;
    }

    await _refreshStatus(normalized);
  }

  Future<AppResult<ProjectInitializationDto>?> initializeProject({
    bool overwrite = false,
  }) async {
    final root = _state.projectRoot;
    if (root == null || root.isEmpty) {
      _state = _state.copyWith(
        errorMessage: 'Kein Projektverzeichnis ausgewählt.',
      );
      notifyListeners();
      return null;
    }

    _state = _state.copyWith(busy: true, errorMessage: null);
    notifyListeners();

    final result = await _initUseCase.run(root, overwrite: overwrite);
    if (!result.ok) {
      _state = _state.copyWith(
        busy: false,
        genaisysReady: false,
        errorMessage: _formatError(result.error),
      );
      notifyListeners();
      return result;
    }

    await _refreshStatus(root);
    return result;
  }

  Future<void> refresh() async {
    final root = _state.projectRoot;
    if (root == null || root.isEmpty) {
      return;
    }
    await _refreshStatus(root);
  }

  Future<void> _refreshStatus(String projectRoot) async {
    final result = await _statusUseCase.run(projectRoot);
    if (!result.ok) {
      _state = _state.copyWith(
        busy: false,
        projectExists: true,
        genaisysReady: false,
        errorMessage: _formatError(result.error),
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      busy: false,
      projectExists: true,
      genaisysReady: true,
      errorMessage: null,
      section: _state.section == AppSection.project
          ? AppSection.dashboard
          : _state.section,
    );
    notifyListeners();
  }

  String _formatError(AppError? error) {
    if (error == null) {
      return 'Unbekannter Fehler.';
    }
    switch (error.kind) {
      case AppErrorKind.invalidInput:
        return 'Ungültige Eingabe: ${error.message}';
      case AppErrorKind.preconditionFailed:
        return 'Voraussetzung fehlt: ${error.message}';
      case AppErrorKind.notFound:
        return 'Nicht gefunden: ${error.message}';
      case AppErrorKind.conflict:
        return 'Konflikt: ${error.message}';
      case AppErrorKind.policyViolation:
        return 'Policy-Verstoß: ${error.message}';
      case AppErrorKind.ioFailure:
        final message = error.message.toLowerCase();
        if (message.contains('operation not permitted') ||
            message.contains('permission denied') ||
            message.contains('cannot open file')) {
          return 'I/O-Fehler: ${error.message} '
              '(Tipp: Auf macOS bitte den Projektordner über '
              '"Projektordner wählen" auswählen, damit die App Zugriff erhält.)';
        }
        return 'I/O-Fehler: ${error.message}';
      case AppErrorKind.unknown:
        return 'Unerwarteter Fehler: ${error.message}';
    }
  }
}
