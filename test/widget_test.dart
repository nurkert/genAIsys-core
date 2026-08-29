import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/settings/application_settings.dart';
import 'package:genaisys/core/settings/application_settings_repository.dart';
import 'package:genaisys/core/settings/project_registry.dart';
import 'package:genaisys/core/settings/project_registry_service.dart';
import 'package:genaisys/desktop/windowing/desktop_window_mode.dart';
import 'package:genaisys/ui/desktop/desktop_saas_app.dart';
import 'package:genaisys/ui/desktop/theme/premium_white_bronze_tokens.dart';
import 'package:genaisys/ui/desktop/theme/ui_chrome_config.dart';
import 'package:genaisys/ui/desktop/widgets/shell/workspaces/workspace_feedback_banner.dart';
import 'support/fake_project_registry_repository.dart';
import 'support/fake_window_service.dart';

void main() {
  testWidgets('Desktop scaffold renders left main and right sidebars', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(DesktopSaasApp(windowService: windowService));
    await tester.pumpAndSettle();

    expect(find.text('Project Chat'), findsAtLeastNWidgets(1));
    expect(
      find.text(
        'Coordinate implementation details, ask questions, and track execution decisions.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ask the workspace assistant...'), findsOneWidget);
    expect(find.text('Genaisys Project'), findsOneWidget);
    expect(windowService.setBlurCallCount, 0);
  });

  testWidgets('Project hub window renders separate project selection shell', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(
      DesktopSaasApp(
        windowService: windowService,
        windowMode: DesktopWindowMode.projectHub,
        projectRegistryService: ProjectRegistryService(
          repository: FakeProjectRegistryRepository(
            initialRegistry: const ProjectRegistry(
              lastOpenedProjectId: '/tmp/genaisys-core',
              projects: <RegisteredProject>[
                RegisteredProject(
                  id: '/tmp/genaisys-core',
                  name: 'Genaisys Core',
                  rootPath: '/tmp/genaisys-core',
                  createdAtIso8601: '2026-02-12T00:00:00.000Z',
                  lastOpenedAtIso8601: '2026-02-12T00:01:00.000Z',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // "Project Hub" appears in both the top bar and the sidebar title.
    expect(find.text('Project Hub'), findsWidgets);
    expect(find.text('Recent Projects'), findsOneWidget);
    expect(find.text('Genaisys Core'), findsOneWidget);
    expect(find.text('Executive Dashboard'), findsNothing);
  });

  testWidgets('Project hub opens workspace window for selected project', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(
      DesktopSaasApp(
        windowService: windowService,
        windowMode: DesktopWindowMode.projectHub,
        projectRegistryService: ProjectRegistryService(
          repository: FakeProjectRegistryRepository(
            initialRegistry: const ProjectRegistry(
              lastOpenedProjectId: null,
              projects: <RegisteredProject>[
                RegisteredProject(
                  id: '/tmp/atlas',
                  name: 'Atlas',
                  rootPath: '/tmp/atlas',
                  createdAtIso8601: '2026-02-12T00:00:00.000Z',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the project card row (entire card is now clickable).
    await tester.tap(find.text('Atlas'));
    await tester.pumpAndSettle();

    expect(windowService.openProjectWorkspaceWindowCallCount, 1);
    expect(windowService.lastProjectWorkspaceName, 'Atlas');
    expect(windowService.lastProjectWorkspaceRootPath, '/tmp/atlas');
  });

  testWidgets('Project hub settings action is clickable at startup', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(
      DesktopSaasApp(
        windowService: windowService,
        windowMode: DesktopWindowMode.projectHub,
      ),
    );
    await tester.pumpAndSettle();

    // The gear icon at the sidebar bottom has a tooltip "Application Settings".
    await tester.tap(find.byTooltip('Application Settings'));
    await tester.pumpAndSettle();

    expect(windowService.openGeneralSettingsWindowCallCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Project hub sidebar search renders without unbounded flex layout errors',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1060, 680));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final FakeWindowService windowService = FakeWindowService();

      await tester.pumpWidget(
        DesktopSaasApp(
          windowService: windowService,
          windowMode: DesktopWindowMode.projectHub,
          projectRegistryService: ProjectRegistryService(
            repository: FakeProjectRegistryRepository(
              initialRegistry: ProjectRegistry.empty,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One search field in the sidebar.
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings window keeps left sidebar fixed and hides right sidebar',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final FakeWindowService windowService = FakeWindowService();

      await tester.pumpWidget(
        DesktopSaasApp(
          windowService: windowService,
          windowMode: DesktopWindowMode.settingsWorkspace,
        ),
      );
      await tester.pumpAndSettle();

      final Finder leftSidebarSlot = find.byKey(
        const Key('desktop.leftSidebar.slot'),
      );
      final Finder rightSidebarSlot = find.byKey(
        const Key('desktop.rightSidebar.slot'),
      );

      expect(
        find.text(
          'Configure global desktop behavior, automation defaults, and security posture.',
        ),
        findsOneWidget,
      );
      expect(find.text('Project Chat'), findsNothing);
      expect(find.text('Backlog'), findsNothing);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.byKey(const Key('desktop.topbar.toggleLeft')), findsNothing);
      expect(find.byKey(const Key('desktop.topbar.toggleRight')), findsNothing);
      expect(tester.getSize(leftSidebarSlot).width, greaterThan(0));
      expect(tester.getSize(rightSidebarSlot).width, lessThan(1));
      expect(windowService.setBlurCallCount, 0);
    },
  );

  testWidgets('Ctrl+, opens general settings in a dedicated window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(DesktopSaasApp(windowService: windowService));
    await tester.pumpAndSettle();

    expect(find.text('Project Chat'), findsAtLeastNWidgets(1));
    expect(find.text('Application Settings'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(windowService.openGeneralSettingsWindowCallCount, 1);
    expect(find.text('Project Chat'), findsAtLeastNWidgets(1));
    expect(find.text('Workspace Preferences'), findsNothing);
  });

  testWidgets(
    'Settings open shortcut is deduplicated while request is active',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final FakeWindowService windowService = FakeWindowService()
        ..openGeneralSettingsWindowDelay = const Duration(milliseconds: 180);

      await tester.pumpWidget(
        DesktopSaasApp(
          windowService: windowService,
          platformOverride: TargetPlatform.windows,
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(windowService.openGeneralSettingsWindowCallCount, 1);

      await tester.pump(const Duration(milliseconds: 220));
      windowService.openGeneralSettingsWindowDelay = Duration.zero;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(windowService.openGeneralSettingsWindowCallCount, 2);
    },
  );

  testWidgets('Top bar right toggle shows and hides right sidebar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(DesktopSaasApp(windowService: windowService));
    await tester.pumpAndSettle();
    final Finder rightSidebarSlot = find.byKey(
      const Key('desktop.rightSidebar.slot'),
    );
    final Finder toggleRightButton = find.byKey(
      const Key('desktop.topbar.toggleRight'),
    );

    expect(tester.getSize(rightSidebarSlot).width, lessThan(1));
    await tester.tap(toggleRightButton);
    await tester.pumpAndSettle();
    expect(tester.getSize(rightSidebarSlot).width, greaterThan(0));

    await tester.tap(toggleRightButton);
    await tester.pumpAndSettle();
    expect(tester.getSize(rightSidebarSlot).width, lessThan(1));
  });

  testWidgets('Sidebar switches between new workspace sections', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(DesktopSaasApp(windowService: windowService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(find.text('Backlog Board'), findsAtLeastNWidgets(1));
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('Task Details'), findsNothing);
    expect(find.text('Create Task'), findsNothing);

    await tester.tap(find.text('Autopilot'));
    await tester.pumpAndSettle();
    expect(find.text('Autopilot Control'), findsAtLeastNWidgets(1));
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Project Health'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Run Log'), findsAtLeastNWidgets(1));

    await tester.tap(find.byTooltip('Project Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Project Settings'), findsAtLeastNWidgets(1));
    expect(find.text('Project config is unavailable.'), findsOneWidget);
  });

  testWidgets('Sidebar places Autopilot between Chat and Backlog', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(DesktopSaasApp(windowService: windowService));
    await tester.pumpAndSettle();

    final double chatY = tester.getTopLeft(find.text('Chat').first).dy;
    final double autopilotY = tester
        .getTopLeft(find.text('Autopilot').first)
        .dy;
    final double backlogY = tester.getTopLeft(find.text('Backlog').first).dy;

    expect(chatY, lessThan(autopilotY));
    expect(autopilotY, lessThan(backlogY));
  });

  testWidgets('Feedback banner is only rendered inside reports workspace', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(DesktopSaasApp(windowService: windowService));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceFeedbackBanner), findsNothing);

    final List<String> nonReportsSections = <String>[
      'Backlog',
      'Dashboard',
      'Autopilot',
      'Chat',
    ];

    for (final String section in nonReportsSections) {
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceFeedbackBanner), findsNothing);
    }

    // Settings uses a tooltip-only gear icon
    await tester.tap(find.byTooltip('Project Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceFeedbackBanner), findsNothing);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceFeedbackBanner), findsNWidgets(2));
  });

  testWidgets('macOS fullscreen animates topbar leading inset', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(
      DesktopSaasApp(
        windowService: windowService,
        platformOverride: TargetPlatform.macOS,
      ),
    );
    await tester.pumpAndSettle();

    final Finder leadingInset = find.byKey(
      const Key('desktop.topbar.leadingInset'),
    );
    expect(tester.getSize(leadingInset).width, 84);
    final double insetBeforeFullscreen = tester.getSize(leadingInset).width;

    windowService.setFullscreenForTest(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getSize(leadingInset).width, insetBeforeFullscreen);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 80));
    final double insetMidAnimation = tester.getSize(leadingInset).width;
    await tester.pumpAndSettle();
    final double insetAfterFullscreen = tester.getSize(leadingInset).width;

    expect(insetMidAnimation, lessThan(insetBeforeFullscreen));
    expect(insetMidAnimation, greaterThan(insetAfterFullscreen));
    expect(insetAfterFullscreen, 6);
  });

  testWidgets(
    'Windows keeps left toggle static and reserves trailing controls inset',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final FakeWindowService windowService = FakeWindowService();

      await tester.pumpWidget(
        DesktopSaasApp(
          windowService: windowService,
          platformOverride: TargetPlatform.windows,
        ),
      );
      await tester.pumpAndSettle();

      final Finder leadingInset = find.byKey(
        const Key('desktop.topbar.leadingInset'),
      );
      final Finder trailingInset = find.byKey(
        const Key('desktop.topbar.trailingInset'),
      );

      expect(
        tester.getSize(leadingInset).width,
        UiChromeConfig.topBarEdgeInset,
      );
      expect(
        tester.getSize(trailingInset).width,
        UiChromeConfig.topBarWindowControlsInsetWindows,
      );

      windowService.setFullscreenForTest(true);
      await tester.pumpAndSettle();

      expect(
        tester.getSize(leadingInset).width,
        UiChromeConfig.topBarEdgeInset,
      );
      expect(
        tester.getSize(trailingInset).width,
        UiChromeConfig.topBarWindowControlsInsetWindows,
      );
    },
  );

  testWidgets('Theme switch to dark keeps project workspace layouts stable', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1360, 880));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    Future<void> pumpApp(ThemeMode mode) async {
      await tester.pumpWidget(
        DesktopSaasApp(windowService: windowService, themeModeOverride: mode),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp(ThemeMode.light);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(find.text('Backlog Board'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Run Log'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Project Chat'), findsAtLeastNWidgets(1));
    await tester.enterText(
      find.byType(TextField).first,
      'line one\nline two\nline three',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await pumpApp(ThemeMode.dark);
    expect(find.text('Project Chat'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(find.text('Backlog Board'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Autopilot'));
    await tester.pumpAndSettle();
    expect(find.text('Autopilot Control'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Project Health'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Project Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Project Settings'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shell background follows light/dark toggles bidirectionally', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1360, 880));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    Future<void> pumpWithTheme(ThemeMode mode) async {
      await tester.pumpWidget(
        DesktopSaasApp(windowService: windowService, themeModeOverride: mode),
      );
      await tester.pumpAndSettle();
    }

    Color shellBackgroundColor() {
      final Container container = tester.widget<Container>(
        find.byKey(const Key('desktop.shell.background')),
      );
      return container.color!;
    }

    await pumpWithTheme(ThemeMode.light);
    expect(
      shellBackgroundColor(),
      equals(PremiumWhiteBronzeTokens.projectShellBackground),
    );

    await pumpWithTheme(ThemeMode.dark);
    expect(
      shellBackgroundColor(),
      equals(PremiumWhiteBronzeTokens.projectShellBackgroundDark),
    );

    await pumpWithTheme(ThemeMode.light);
    expect(
      shellBackgroundColor(),
      equals(PremiumWhiteBronzeTokens.projectShellBackground),
    );
  });

  testWidgets('Workspace does not request blur when acrylic is disabled', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1360, 880));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    Future<void> pumpWithTheme(ThemeMode mode) async {
      await tester.pumpWidget(
        DesktopSaasApp(windowService: windowService, themeModeOverride: mode),
      );
      await tester.pumpAndSettle();
    }

    await pumpWithTheme(ThemeMode.light);
    await pumpWithTheme(ThemeMode.dark);
    await pumpWithTheme(ThemeMode.light);

    expect(windowService.setBlurCallCount, 0);
    expect(windowService.lastSetBlurEnabled, isNull);
    expect(windowService.lastSetBlurDarkMode, isNull);
  });

  testWidgets('Settings workspace renders cleanly in dark mode', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1320, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final FakeWindowService windowService = FakeWindowService();

    await tester.pumpWidget(
      DesktopSaasApp(
        windowService: windowService,
        windowMode: DesktopWindowMode.settingsWorkspace,
        themeModeOverride: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Application Settings'), findsAtLeastNWidgets(1));
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Application settings theme mode supports light dark and system',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1320, 860));
      addTearDown(() async {
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
        await tester.binding.setSurfaceSize(null);
      });
      final FakeWindowService windowService = FakeWindowService();
      final _MemoryApplicationSettingsRepository settingsRepository =
          _MemoryApplicationSettingsRepository(
            initial: const ApplicationSettings(
              themeMode: ApplicationThemeMode.light,
              languageCode: 'en',
              desktopNotificationsEnabled: true,
              autopilotByDefaultEnabled: false,
              localTelemetryEnabled: true,
              strictSecretRedactionEnabled: true,
            ),
          );

      await tester.pumpWidget(
        DesktopSaasApp(
          windowService: windowService,
          windowMode: DesktopWindowMode.settingsWorkspace,
          applicationSettingsRepository: settingsRepository,
        ),
      );
      await tester.pumpAndSettle();
      expect(_appThemeMode(tester), ThemeMode.light);

      final Finder themeModeDropdownFinder = find.byWidgetPredicate(
        (Widget widget) =>
            widget is DropdownButtonFormField<ApplicationThemeMode>,
      );
      final DropdownButtonFormField<ApplicationThemeMode> themeModeDropdown =
          tester.widget<DropdownButtonFormField<ApplicationThemeMode>>(
            themeModeDropdownFinder,
          );
      themeModeDropdown.onChanged?.call(ApplicationThemeMode.dark);
      await tester.pump();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(settingsRepository.current.themeMode, ApplicationThemeMode.dark);
      expect(_appThemeMode(tester), ThemeMode.dark);

      tester
          .widget<DropdownButtonFormField<ApplicationThemeMode>>(
            themeModeDropdownFinder,
          )
          .onChanged
          ?.call(ApplicationThemeMode.system);
      await tester.pump();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(settingsRepository.current.themeMode, ApplicationThemeMode.system);
      expect(_appThemeMode(tester), ThemeMode.system);
      expect(tester.takeException(), isNull);
    },
  );
}

ThemeMode _appThemeMode(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
}

class _MemoryApplicationSettingsRepository
    implements ApplicationSettingsRepository {
  _MemoryApplicationSettingsRepository({ApplicationSettings? initial})
    : _current = initial ?? ApplicationSettings.defaults;

  ApplicationSettings _current;

  ApplicationSettings get current => _current;

  @override
  String get storagePath => '/tmp/test-application-settings.json';

  @override
  Future<ApplicationSettings> read() async {
    return _current;
  }

  @override
  Future<void> reset() async {
    _current = ApplicationSettings.defaults;
  }

  @override
  Future<void> write(ApplicationSettings settings) async {
    _current = settings;
  }
}
