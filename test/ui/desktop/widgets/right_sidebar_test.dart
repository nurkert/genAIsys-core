import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/ui/desktop/controllers/project_workspace_controller.dart';
import 'package:genaisys/ui/desktop/localization/desktop_localization.dart';
import 'package:genaisys/ui/desktop/models/dashboard_models.dart';
import 'package:genaisys/ui/desktop/models/workspace_models.dart';
import 'package:genaisys/ui/desktop/widgets/shell/right_sidebar.dart';

void main() {
  testWidgets('right sidebar renders section-specific backlog composer', (
    WidgetTester tester,
  ) async {
    final _SidebarTestController controller = _SidebarTestController();

    await tester.pumpWidget(
      _wrapWithMaterial(
        RightSidebar(
          cornerRadius: 24,
          selectedSection: DesktopPrimarySection.backlog,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backlog Board'), findsOneWidget);
    expect(
      find.byKey(const Key('rightSidebar.backlog.taskTitle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('rightSidebar.backlog.priority')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('rightSidebar.backlog.createTask')),
      findsOneWidget,
    );
    expect(find.text('Project Chat'), findsNothing);
  });

  testWidgets('right sidebar backlog composer triggers task creation', (
    WidgetTester tester,
  ) async {
    final _SidebarTestController controller = _SidebarTestController();

    await tester.pumpWidget(
      _wrapWithMaterial(
        RightSidebar(
          cornerRadius: 24,
          selectedSection: DesktopPrimarySection.backlog,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rightSidebar.backlog.taskTitle')),
      'Integrate backlog create composer',
    );
    await tester.tap(find.byKey(const Key('rightSidebar.backlog.createTask')));
    await tester.pumpAndSettle();

    expect(controller.creations.length, 1);
    expect(
      controller.creations.single.title,
      'Integrate backlog create composer',
    );
    expect(controller.creations.single.priority, BacklogTaskPriority.p2);
  });

  testWidgets('backlog composer consumes pending focus request on open', (
    WidgetTester tester,
  ) async {
    final _SidebarTestController controller = _SidebarTestController();
    controller.requestBacklogComposerFocus();

    await tester.pumpWidget(
      _wrapWithMaterial(
        RightSidebar(
          cornerRadius: 24,
          selectedSection: DesktopPrimarySection.backlog,
          controller: controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final Finder editable = find.descendant(
      of: find.byKey(const Key('rightSidebar.backlog.taskTitle')),
      matching: find.byType(EditableText),
    );
    expect(editable, findsOneWidget);
    final EditableText editableText = tester.widget<EditableText>(editable);
    expect(editableText.focusNode.hasFocus, isTrue);
  });

  testWidgets('right sidebar switches content per selected section', (
    WidgetTester tester,
  ) async {
    final _SidebarTestController controller = _SidebarTestController();

    await tester.pumpWidget(
      _wrapWithMaterial(
        RightSidebar(
          cornerRadius: 24,
          selectedSection: DesktopPrimarySection.chat,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Project Chat'), findsOneWidget);
    expect(
      find.byKey(const Key('rightSidebar.backlog.taskTitle')),
      findsNothing,
    );
  });
}

Widget _wrapWithMaterial(Widget child) {
  final DesktopLocalizationController localizationController =
      DesktopLocalizationController();
  return MaterialApp(
    home: DesktopLocalizationScope(
      controller: localizationController,
      child: Scaffold(body: child),
    ),
  );
}

class _SidebarTestController extends ProjectWorkspaceController {
  _SidebarTestController()
    : super(projectRootPath: '/tmp/genaisys-right-sidebar-test');

  final List<_CreationRecord> creations = <_CreationRecord>[];

  @override
  bool get isActionInProgress => false;

  @override
  String? get errorMessage => null;

  @override
  String? get infoMessage => null;

  @override
  Future<void> createTask({
    required String title,
    required BacklogTaskPriority priority,
    AppTaskCategory category = AppTaskCategory.core,
    String section = 'Backlog',
  }) async {
    creations.add(_CreationRecord(title: title, priority: priority));
  }
}

class _CreationRecord {
  const _CreationRecord({required this.title, required this.priority});

  final String title;
  final BacklogTaskPriority priority;
}
