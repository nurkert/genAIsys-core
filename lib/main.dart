// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/settings/project_registry_service.dart';
import 'core/settings/application_settings_repository.dart';
import 'desktop/services/noop_window_service.dart';
import 'desktop/services/plugin_multi_window_api.dart';
import 'desktop/services/production_window_service.dart';
import 'desktop/services/window_service_interface.dart';
import 'desktop/windowing/desktop_window_mode.dart';
import 'desktop/windowing/window_launch_context.dart';
import 'ui/desktop/desktop_saas_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final WindowLaunchContext bootstrapLaunchContext =
      WindowLaunchContext.fromProcessArgs(
        args: args,
        fallbackWindowMode: const String.fromEnvironment(
          'GENAISYS_WINDOW_MODE',
          defaultValue: 'project_hub',
        ),
      );
  final ApplicationSettingsRepository applicationSettingsRepository =
      FileApplicationSettingsRepository();
  final ProjectRegistryService projectRegistryService =
      ProjectRegistryService();

  const String projectDisplayNameFromEnv = String.fromEnvironment(
    'GENAISYS_PROJECT_NAME',
    defaultValue: 'Genaisys Project',
  );
  final String projectRootPathFromEnv = const String.fromEnvironment(
    'GENAISYS_PROJECT_ROOT',
    defaultValue: '',
  );
  final Object? payloadProjectRootPath = bootstrapLaunchContext
      .arguments[WindowLaunchContext.payloadProjectRootPathKey];
  final Object? payloadProjectName = bootstrapLaunchContext
      .arguments[WindowLaunchContext.payloadProjectNameKey];
  final String resolvedPayloadProjectName = payloadProjectName is String
      ? payloadProjectName
      : projectDisplayNameFromEnv;
  final String resolvedPayloadProjectRootPath = payloadProjectRootPath is String
      ? payloadProjectRootPath
      : projectRootPathFromEnv;
  DesktopWindowMode resolvedWindowMode = bootstrapLaunchContext.windowMode;
  String projectDisplayName = resolvedPayloadProjectName;
  String projectRootPath = resolvedPayloadProjectRootPath;

  final Map<String, Object?> resolvedArguments = <String, Object?>{
    ...bootstrapLaunchContext.arguments,
    WindowLaunchContext.payloadWindowModeKey: resolvedWindowMode.key,
    if (projectDisplayName.trim().isNotEmpty)
      WindowLaunchContext.payloadProjectNameKey: projectDisplayName,
    if (projectRootPath.trim().isNotEmpty)
      WindowLaunchContext.payloadProjectRootPathKey: projectRootPath,
  };
  final WindowLaunchContext launchContext = bootstrapLaunchContext.copyWith(
    windowMode: resolvedWindowMode,
    windowModeKey: resolvedWindowMode.key,
    arguments: Map<String, Object?>.unmodifiable(resolvedArguments),
  );

  final WindowServiceInterface windowService = _resolveWindowService(
    launchContext,
  );
  final DesktopWindowMode windowMode = launchContext.windowMode;

  if (kDebugMode) {
    debugPrint(
      '[WindowLaunch] mode=${launchContext.windowModeKey} '
      'sub=${launchContext.isSubWindow} id=${launchContext.windowId} '
      'args=${launchContext.arguments}',
    );
  }

  // CRITICAL: Call runApp() immediately so the Flutter frame scheduler starts
  // pumping frames.  All heavy initialization (window configuration, settings
  // I/O, workspace data loading) is deferred to DesktopSaasApp.initState()
  // where it runs as a post-frame callback, keeping the event loop alive.
  //
  // Without this, sub-windows created by desktop_multi_window freeze because
  // `await windowService.initialize()` blocks main() with sequential platform
  // channel calls (windowManager.waitUntilReadyToShow, etc.) BEFORE the
  // frame scheduler is started, starving the macOS run loop of frame ticks.
  runApp(
    DesktopSaasApp(
      windowService: windowService,
      windowMode: windowMode,
      projectDisplayName: projectDisplayName,
      projectRootPath: projectRootPath,
      applicationSettingsRepository: applicationSettingsRepository,
      projectRegistryService: projectRegistryService,
    ),
  );
}

WindowServiceInterface _resolveWindowService(
  WindowLaunchContext launchContext,
) {
  if (kIsWeb) {
    return NoopWindowService();
  }

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    return ProductionWindowService(
      launchContext: launchContext,
      multiWindowApi: DesktopMultiWindowApi(),
    );
  }

  return NoopWindowService();
}
