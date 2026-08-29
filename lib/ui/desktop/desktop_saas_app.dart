// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/application_settings.dart';
import '../../core/settings/application_settings_repository.dart';
import '../../core/settings/project_registry_service.dart';
import '../../desktop/services/window_service_interface.dart';
import '../../desktop/windowing/desktop_window_mode.dart';
import 'localization/desktop_localization.dart';
import 'models/settings_models.dart';
import 'theme/platform_corner_profile.dart';
import 'theme/premium_white_bronze_tokens.dart';
import 'theme/saas_theme.dart';
import 'widgets/desktop_scaffold.dart';
import 'widgets/project_hub_window.dart';
import 'widgets/shell/settings_content_panel.dart';
import 'widgets/shell/settings_sidebar.dart';

/// Root app widget for the new desktop-first scaffold.
///
/// Important:
/// - this widget only depends on [WindowServiceInterface], never on concrete
///   window packages. This keeps UI modules replaceable and testable.
class DesktopSaasApp extends StatefulWidget {
  const DesktopSaasApp({
    super.key,
    required this.windowService,
    this.platformOverride,
    this.localizationController,
    this.windowMode = DesktopWindowMode.projectWorkspace,
    this.projectDisplayName,
    this.projectRootPath,
    this.themeModeOverride,
    this.initialApplicationSettings,
    this.applicationSettingsRepository,
    this.projectRegistryService,
  });

  final WindowServiceInterface windowService;
  final TargetPlatform? platformOverride;
  final DesktopLocalizationController? localizationController;
  final DesktopWindowMode windowMode;
  final String? projectDisplayName;
  final String? projectRootPath;
  final ThemeMode? themeModeOverride;
  final ApplicationSettings? initialApplicationSettings;
  final ApplicationSettingsRepository? applicationSettingsRepository;
  final ProjectRegistryService? projectRegistryService;

  @override
  State<DesktopSaasApp> createState() => _DesktopSaasAppState();
}

class _DesktopSaasAppState extends State<DesktopSaasApp> {
  static const Duration _macModifierReleaseTimeout = Duration(
    milliseconds: 420,
  );
  static const Duration _macModifierReleasePollInterval = Duration(
    milliseconds: 16,
  );

  late final DesktopLocalizationController _localizationController =
      widget.localizationController ?? DesktopLocalizationController();
  late final bool _ownsLocalizationController =
      widget.localizationController == null;
  late final ApplicationSettingsRepository _settingsRepository =
      widget.applicationSettingsRepository ??
      FileApplicationSettingsRepository();
  late final ProjectRegistryService _projectRegistryService =
      widget.projectRegistryService ?? ProjectRegistryService();
  late DesktopWindowMode _activeWindowMode = widget.windowMode;
  DesktopSettingsSection _selectedSettingsSection =
      DesktopSettingsSection.general;
  Future<void>? _openSettingsInFlight;
  late ThemeMode _settingsThemeMode = _themeModeFromApplication(
    widget.initialApplicationSettings?.themeMode ?? ApplicationThemeMode.system,
  );

  ThemeMode get _effectiveThemeMode =>
      widget.themeModeOverride ?? _settingsThemeMode;

  @override
  void initState() {
    super.initState();
    final ApplicationSettings? initial = widget.initialApplicationSettings;
    if (initial != null) {
      _applySettingsLanguage(initial.languageCode);
    }
    // Defer all heavy async work (window service initialization, settings I/O)
    // to after the first frame.  This ensures the Flutter frame scheduler is
    // fully running before any platform channel calls or file I/O happen,
    // preventing run-loop starvation on macOS sub-windows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_initializeAfterFirstFrame());
    });
  }

  Future<void> _initializeAfterFirstFrame() async {
    await widget.windowService.initialize();
    if (!mounted) {
      return;
    }
    await _hydrateApplicationSettings();
  }

  @override
  void didUpdateWidget(covariant DesktopSaasApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowMode != widget.windowMode) {
      _activeWindowMode = widget.windowMode;
    }
  }

  Future<void> _hydrateApplicationSettings() async {
    try {
      final ApplicationSettings settings = await _settingsRepository.read();
      if (!mounted) {
        return;
      }
      _applySettingsLanguage(settings.languageCode);
      _applySettingsThemeMode(settings.themeMode);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to load application settings: $error');
      }
    }
  }

  @override
  void dispose() {
    if (_ownsLocalizationController) {
      _localizationController.dispose();
    }
    widget.windowService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = _withPlatformOverride(SaasTheme.light());
    final ThemeData darkTheme = _withPlatformOverride(SaasTheme.dark());

    return AnimatedBuilder(
      animation: _localizationController,
      builder: (BuildContext context, Widget? child) {
        final strings = _localizationController.strings;
        final String resolvedProjectName =
            widget.projectDisplayName ?? strings.defaultProjectWindowName;

        return DesktopLocalizationScope(
          controller: _localizationController,
          child: MaterialApp(
            title: strings.appTitle,
            locale: _localizationController.locale,
            supportedLocales: _localizationController.supportedLocales,
            debugShowCheckedModeBanner: false,
            themeMode: _effectiveThemeMode,
            theme: lightTheme,
            darkTheme: darkTheme,
            home: _withGlobalShortcuts(
              _buildWindowHome(context, resolvedProjectName),
            ),
          ),
        );
      },
    );
  }

  Widget _withGlobalShortcuts(Widget child) {
    final TargetPlatform platform =
        widget.platformOverride ?? defaultTargetPlatform;
    final Map<ShortcutActivator, VoidCallback> bindings =
        <ShortcutActivator, VoidCallback>{
          if (platform != TargetPlatform.macOS)
            const SingleActivator(LogicalKeyboardKey.comma, control: true):
                _openGeneralSettings,
        };

    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }

  void _openGeneralSettings() {
    if (_activeWindowMode == DesktopWindowMode.settingsWorkspace) {
      return;
    }
    final Future<void>? inFlight = _openSettingsInFlight;
    if (inFlight != null) {
      return;
    }
    _openSettingsInFlight = _openGeneralSettingsInternal().whenComplete(() {
      _openSettingsInFlight = null;
    });
  }

  Future<void> _openGeneralSettingsInternal() async {
    final TargetPlatform platform =
        widget.platformOverride ?? defaultTargetPlatform;
    if (platform == TargetPlatform.macOS) {
      await _waitForMacModifiersToRelease();
    }
    if (!mounted || _activeWindowMode == DesktopWindowMode.settingsWorkspace) {
      return;
    }
    await widget.windowService.openGeneralSettingsWindow().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Failed to open settings window: $error');
    });
  }

  Future<void> _waitForMacModifiersToRelease() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    while (_hasActiveMacModifierKeys()) {
      if (stopwatch.elapsed >= _macModifierReleaseTimeout) {
        return;
      }
      await Future<void>.delayed(_macModifierReleasePollInterval);
    }
  }

  bool _hasActiveMacModifierKeys() {
    final Set<LogicalKeyboardKey> pressed =
        HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
  }

  void _onSettingsSaved(ApplicationSettings settings) {
    _applySettingsLanguage(settings.languageCode);
    _applySettingsThemeMode(settings.themeMode);
  }

  void _applySettingsLanguage(String languageCode) {
    final String normalized = languageCode.trim().toLowerCase();
    final DesktopLanguage language = switch (normalized) {
      'en' => DesktopLanguage.english,
      _ => DesktopLanguage.english,
    };
    _localizationController.setLanguage(language);
  }

  void _applySettingsThemeMode(ApplicationThemeMode themeMode) {
    final ThemeMode resolved = _themeModeFromApplication(themeMode);
    if (_settingsThemeMode == resolved) {
      return;
    }
    setState(() {
      _settingsThemeMode = resolved;
    });
  }

  Widget _buildWindowHome(BuildContext context, String projectName) {
    final strings = _localizationController.strings;

    switch (_activeWindowMode) {
      case DesktopWindowMode.projectWorkspace:
        return DesktopScaffold(
          windowService: widget.windowService,
          projectDisplayName: projectName,
          projectRootPath: widget.projectRootPath,
          onOpenSettings: _openGeneralSettings,
          manageWindowTranslucency: false,
          sidebarLightGlassColor: PremiumWhiteBronzeTokens.sidebarLightSurface,
          sidebarDarkGlassColor: PremiumWhiteBronzeTokens.sidebarDarkSurface,
          sidebarLightBorderColor: PremiumWhiteBronzeTokens.sidebarLightBorder,
          sidebarDarkBorderColor: PremiumWhiteBronzeTokens.sidebarDarkBorder,
        );
      case DesktopWindowMode.projectHub:
        return ProjectHubWindow(
          onOpenSettings: _openGeneralSettings,
          windowService: widget.windowService,
          projectRegistryService: _projectRegistryService,
        );
      case DesktopWindowMode.settingsWorkspace:
        return DesktopScaffold(
          windowService: widget.windowService,
          projectDisplayName: strings.settingsWindowName,
          onOpenSettings: _openGeneralSettings,
          manageWindowTranslucency: false,
          leftSidebarCollapsible: false,
          rightSidebarEnabled: false,
          leftSidebarBuilder: (BuildContext context) => SettingsSidebar(
            cornerRadius: PlatformCornerProfile.resolve().sidebarRadius,
            strings: strings,
            selectedSection: _selectedSettingsSection,
            onSelectSection: (DesktopSettingsSection section) {
              if (_selectedSettingsSection == section) {
                return;
              }
              setState(() {
                _selectedSettingsSection = section;
              });
            },
            lightGlassColor: PremiumWhiteBronzeTokens.sidebarLightSurface,
            darkGlassColor: PremiumWhiteBronzeTokens.sidebarDarkSurface,
            lightBorderColor: PremiumWhiteBronzeTokens.sidebarLightBorder,
            darkBorderColor: PremiumWhiteBronzeTokens.sidebarDarkBorder,
          ),
          mainContentBuilder:
              (
                BuildContext context,
                double topCornerRadius,
                bool leftSidebarVisible,
                bool rightSidebarVisible,
              ) => SettingsContentPanel(
                topCornerRadius: topCornerRadius,
                leftSidebarVisible: leftSidebarVisible,
                rightSidebarVisible: rightSidebarVisible,
                strings: strings,
                selectedSection: _selectedSettingsSection,
                settingsRepository: _settingsRepository,
                onSettingsSaved: _onSettingsSaved,
              ),
        );
    }
  }

  ThemeData _withPlatformOverride(ThemeData theme) {
    final TargetPlatform? override = widget.platformOverride;
    if (override == null) {
      return theme;
    }
    return theme.copyWith(platform: override);
  }

  ThemeMode _themeModeFromApplication(ApplicationThemeMode themeMode) {
    return switch (themeMode) {
      ApplicationThemeMode.light => ThemeMode.light,
      ApplicationThemeMode.dark => ThemeMode.dark,
      ApplicationThemeMode.system => ThemeMode.system,
    };
  }
}
