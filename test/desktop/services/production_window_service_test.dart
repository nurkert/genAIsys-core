import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/desktop/services/multi_window_api.dart';
import 'package:genaisys/desktop/services/production_window_service.dart';
import 'package:genaisys/desktop/windowing/desktop_window_mode.dart';
import 'package:genaisys/desktop/windowing/window_launch_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductionWindowService.initialize', () {
    test('root project hub closes restored subwindows on startup', () async {
      final _FakeMultiWindowApi multiWindowApi = _FakeMultiWindowApi(
        subWindowIds: <String>['7', '8'],
        identitiesByWindowId: <String, Map<String, Object?>>{},
      );
      final ProductionWindowService service = ProductionWindowService(
        launchContext: _hubLaunchContext(),
        multiWindowApi: multiWindowApi,
      );

      await service.initialize();

      expect(
        multiWindowApi.closedWindowByIdCalls,
        unorderedEquals(<String>['7', '8']),
      );
    });
  });

  group('ProductionWindowService.openProjectWorkspaceWindow', () {
    test(
      'reuses existing matching project workspace window by root path',
      () async {
        final _FakeMultiWindowApi multiWindowApi = _FakeMultiWindowApi(
          subWindowIds: <String>['21'],
          identitiesByWindowId: <String, Map<String, Object?>>{
            '21': <String, Object?>{
              WindowLaunchContext.payloadWindowModeKey:
                  DesktopWindowMode.projectWorkspace.key,
              'window_id': '21',
              WindowLaunchContext.payloadProjectRootPathKey: '/tmp/repo',
            },
          },
        );
        final ProductionWindowService service = ProductionWindowService(
          launchContext: _hubLaunchContext(),
          multiWindowApi: multiWindowApi,
        );

        await service.openProjectWorkspaceWindow(
          projectName: 'Repo',
          projectRootPath: '/tmp/repo',
        );

        expect(multiWindowApi.createWindowCallCount, 0);
        expect(multiWindowApi.showWindowByIdCalls, contains('21'));
      },
    );

    test(
      'creates new workspace window when no matching project is open',
      () async {
        final _FakeMultiWindowApi multiWindowApi = _FakeMultiWindowApi(
          subWindowIds: <String>['21'],
          identitiesByWindowId: <String, Map<String, Object?>>{
            '21': <String, Object?>{
              WindowLaunchContext.payloadWindowModeKey:
                  DesktopWindowMode.projectWorkspace.key,
              'window_id': '21',
              WindowLaunchContext.payloadProjectRootPathKey: '/tmp/other-repo',
            },
          },
          nextCreatedWindowId: 44,
        );
        final ProductionWindowService service = ProductionWindowService(
          launchContext: _hubLaunchContext(),
          multiWindowApi: multiWindowApi,
        );

        await service.openProjectWorkspaceWindow(
          projectName: 'Repo',
          projectRootPath: '/tmp/repo',
        );

        expect(multiWindowApi.createWindowCallCount, 1);
        expect(multiWindowApi.createdWindows, hasLength(1));
        final _FakeManagedSubWindow created =
            multiWindowApi.createdWindows.single;
        expect(created.showCallCount, 1);
      },
    );
  });
}

WindowLaunchContext _hubLaunchContext() {
  return const WindowLaunchContext(
    windowMode: DesktopWindowMode.projectHub,
    windowModeKey: 'project_hub',
    isSubWindow: false,
    windowId: null,
    arguments: <String, Object?>{
      WindowLaunchContext.payloadWindowModeKey: 'project_hub',
    },
  );
}

class _FakeMultiWindowApi implements MultiWindowApi {
  _FakeMultiWindowApi({
    required this.subWindowIds,
    required this.identitiesByWindowId,
    this.nextCreatedWindowId = 100,
  });

  final List<String> subWindowIds;
  final Map<String, Map<String, Object?>> identitiesByWindowId;
  int nextCreatedWindowId;

  int createWindowCallCount = 0;
  final List<String> showWindowByIdCalls = <String>[];
  final List<String> closedWindowByIdCalls = <String>[];
  final List<_FakeManagedSubWindow> createdWindows = <_FakeManagedSubWindow>[];

  @override
  void setMessageHandler(MultiWindowMessageHandler? handler) {}

  @override
  Future<ManagedSubWindow> createWindow({required String payload}) async {
    createWindowCallCount += 1;
    final _FakeManagedSubWindow window = _FakeManagedSubWindow(
      windowId: nextCreatedWindowId.toString(),
    );
    nextCreatedWindowId += 1;
    createdWindows.add(window);
    return window;
  }

  @override
  Future<List<String>> getAllSubWindowIds() async {
    return List<String>.from(subWindowIds);
  }

  @override
  Future<Object?> invokeMethod({
    required String targetWindowId,
    required String method,
    Object? arguments,
  }) async {
    final Map<String, Object?>? identity = identitiesByWindowId[targetWindowId];
    if (identity == null) {
      return null;
    }
    return identity;
  }

  @override
  Future<void> showWindowById(String windowId) async {
    showWindowByIdCalls.add(windowId);
  }

  @override
  Future<void> closeWindowById(String windowId) async {
    closedWindowByIdCalls.add(windowId);
    subWindowIds.remove(windowId);
  }
}

class _FakeManagedSubWindow implements ManagedSubWindow {
  _FakeManagedSubWindow({required this.windowId});

  @override
  final String windowId;

  int showCallCount = 0;

  @override
  Future<void> show() async {
    showCallCount += 1;
  }
}
