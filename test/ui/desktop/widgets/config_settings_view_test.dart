// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/app/app.dart';
import 'package:genaisys/core/config/config_field_registry.dart';
import 'package:genaisys/ui/desktop/controllers/config_settings_controller.dart';
import 'package:genaisys/ui/desktop/localization/desktop_strings.dart';
import 'package:genaisys/ui/desktop/widgets/shell/workspaces/settings/config_setting_row.dart';
import 'package:genaisys/ui/desktop/widgets/shell/workspaces/settings/config_settings_view.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('settings_view_test');
    Directory('${root.path}/.genaisys').createSync(recursive: true);
    File(
      '${root.path}/.genaisys/config.yml',
    ).writeAsStringSync('project:\n  name: "demo"\n');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  ConfigSettingsController controllerFor(Directory dir) {
    return ConfigSettingsController(projectRoot: dir.path);
  }

  Widget wrap(
    Widget child, {
    Brightness brightness = Brightness.light,
    double width = 1100,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: SizedBox(width: width, height: 800, child: child),
      ),
    );
  }

  Future<ConfigSettingsController> pumpView(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double width = 1100,
  }) async {
    final controller = controllerFor(root);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrap(
        ConfigSettingsView(
          controller: controller,
          strings: DesktopStrings.english,
        ),
        brightness: brightness,
        width: width,
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  group('coverage', () {
    testWidgets('every registered config key is reachable through the view', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      expect(controller.schema, isNotNull);
      expect(controller.schema!.fieldCount, configFieldRegistry.length);
    });

    testWidgets('renders a group rail entry for every top-level group', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      for (final group in controller.groups) {
        expect(
          find.text(group),
          findsWidgets,
          reason: 'group "$group" must be navigable',
        );
      }
    });

    testWidgets('shows the first group by default', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      expect(controller.selectedGroup, controller.groups.first);
      expect(controller.visibleSections, isNotEmpty);
    });
  });

  group('no project config', () {
    testWidgets('says so instead of offering unsaveable defaults', (
      WidgetTester tester,
    ) async {
      // A project root with no .genaisys/config.yml: reading would happily
      // return defaults, but there is nothing to write them to, so offering an
      // editor here would be a lie.
      final empty = Directory.systemTemp.createTempSync('settings_no_config');
      addTearDown(() => empty.deleteSync(recursive: true));

      final controller = ConfigSettingsController(projectRoot: empty.path);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          ConfigSettingsView(
            controller: controller,
            strings: DesktopStrings.english,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isConfigMissing, isTrue);
      expect(controller.schema, isNull);
      expect(
        find.text(DesktopStrings.english.projectSettingsUnavailableLabel),
        findsOneWidget,
      );
      expect(
        find.text(DesktopStrings.english.settingsRetryLabel),
        findsOneWidget,
      );
    });
  });

  group('search', () {
    testWidgets('finds a setting by its label without knowing its group', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      await tester.enterText(find.byType(TextField).first, 'max files');
      await tester.pumpAndSettle();

      expect(controller.isSearching, isTrue);
      expect(controller.searchResultCount, greaterThan(0));
      expect(
        controller.visibleSections
            .expand((s) => s.fields)
            .map((f) => f.qualifiedKey),
        contains('policies.diff_budget.max_files'),
      );
    });

    testWidgets('finds a setting by its raw config key', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'policies.diff_budget.max_files',
      );
      await tester.pumpAndSettle();

      expect(controller.searchResultCount, 1);
    });

    testWidgets('search spans groups, so the rail is hidden while active', (
      WidgetTester tester,
    ) async {
      await pumpView(tester);
      expect(find.byType(ListView), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).first, 'max');
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('reports an empty result instead of a blank pane', (
      WidgetTester tester,
    ) async {
      await pumpView(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'zzz-no-such-setting',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No setting matches'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('a toggle writes straight through to the config file', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      final toggleField = controller.schema!.allFields.firstWhere(
        (f) => f.control == ConfigFieldControl.toggle,
      );
      final before = toggleField.value as bool;

      await controller.setValue(toggleField.qualifiedKey, !before);
      await tester.pumpAndSettle();

      final after = controller.schema!.fieldFor(toggleField.qualifiedKey)!;
      expect(after.value, !before);
      expect(after.isModified, isTrue);
      expect(
        File('${root.path}/.genaisys/config.yml').readAsStringSync(),
        contains(toggleField.yamlKey),
      );
    });

    testWidgets('a rejected value surfaces inline and is not persisted', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      // max_files declares minValue: 1, so 0 must be refused.
      await controller.setValue('policies.diff_budget.max_files', 0);
      await tester.pumpAndSettle();

      expect(controller.errorFor('policies.diff_budget.max_files'), isNotNull);
      expect(
        controller.schema!.fieldFor('policies.diff_budget.max_files')!.value,
        isNot(0),
      );
    });

    testWidgets('restoring a field returns it to the registered default', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);
      const key = 'policies.diff_budget.max_files';
      final defaultValue = controller.schema!.fieldFor(key)!.defaultValue;

      await controller.setValue(key, 42);
      await tester.pumpAndSettle();
      expect(controller.schema!.fieldFor(key)!.isModified, isTrue);

      await controller.resetField(key);
      await tester.pumpAndSettle();

      final field = controller.schema!.fieldFor(key)!;
      expect(field.value, defaultValue);
      expect(field.isModified, isFalse);
    });

    testWidgets('restore-all only touches the settings currently in view', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      // One setting inside the visible group, one outside it.
      final visibleKey =
          controller.visibleSections.first.fields.first.qualifiedKey;
      const outsideKey = 'policies.diff_budget.max_files';
      expect(
        controller.schema!.fieldFor(outsideKey)!.section,
        isNot(controller.visibleSections.first.path),
        reason: 'The control key must sit outside the visible group',
      );

      await controller.setValue(visibleKey, _flip(controller, visibleKey));
      await controller.setValue(outsideKey, 33);
      await tester.pumpAndSettle();

      await controller.resetVisible();
      await tester.pumpAndSettle();

      expect(controller.schema!.fieldFor(visibleKey)!.isModified, isFalse);
      expect(
        controller.schema!.fieldFor(outsideKey)!.isModified,
        isTrue,
        reason: 'A setting outside the visible group must be left alone',
      );
    });
  });

  group('responsive', () {
    testWidgets('lays out without overflow at a narrow width', (
      WidgetTester tester,
    ) async {
      // A fixed-width group rail plus a fixed-width control would overflow a
      // narrow pane; the rail collapses to a dropdown instead.
      await pumpView(tester, width: 520);

      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
    });

    testWidgets('stacks a control under its label in a very narrow row', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, width: 380);

      expect(tester.takeException(), isNull);
      expect(find.byType(ConfigSettingRow), findsWidgets);
    });

    testWidgets('names the group on each card once the rail is gone', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester, width: 520);
      final group = controller.selectedGroup!;

      expect(find.textContaining('$group · '), findsWidgets);
    });

    testWidgets('keeps the rail at a comfortable width', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, width: 1100);

      expect(tester.takeException(), isNull);
      // Rail list + section list.
      expect(find.byType(ListView), findsNWidgets(2));
    });
  });

  group('affordances', () {
    testWidgets('a modified setting offers a restore control', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);
      final key = controller.visibleSections.first.fields.first.qualifiedKey;

      final before = find.byType(IconButton).evaluate().length;
      await controller.setValue(key, _flip(controller, key));
      await tester.pumpAndSettle();

      expect(find.byType(IconButton).evaluate().length, greaterThan(before));
    });

    testWidgets('every visible row explains what the setting does', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      // The row shows `description`, falling back to the raw config key. A
      // fallback here means somebody added a key without explaining it.
      for (final field in controller.visibleSections.expand((s) => s.fields)) {
        expect(
          field.description,
          isNotNull,
          reason: '${field.qualifiedKey} would show only its raw key',
        );
        expect(find.text(field.description!), findsWidgets);
      }
      expect(find.byType(ConfigSettingRow), findsWidgets);
    });

    testWidgets('a dropdown follows a value that changes underneath it', (
      WidgetTester tester,
    ) async {
      final controller = await pumpView(tester);

      final choiceField = controller.schema!.allFields.firstWhere(
        (f) => f.control == ConfigFieldControl.choice,
      );
      final replacement = choiceField.choices!.firstWhere(
        (c) => c != choiceField.value,
      );

      // Reach the choice field, whichever group it lives in.
      await tester.enterText(
        find.byType(TextField).first,
        choiceField.qualifiedKey,
      );
      await tester.pumpAndSettle();

      await controller.setValue(choiceField.qualifiedKey, replacement);
      await tester.pumpAndSettle();
      expect(find.text(replacement), findsWidgets);

      // A FormField keeps its own selection state; the row must still follow
      // the restore rather than keep showing the value the user picked.
      await controller.resetField(choiceField.qualifiedKey);
      await tester.pumpAndSettle();

      final restored = controller.schema!.fieldFor(choiceField.qualifiedKey)!;
      expect(restored.value, choiceField.defaultValue);
      expect(
        find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.text(replacement),
        ),
        findsNothing,
      );
    });

    testWidgets('renders in dark mode', (WidgetTester tester) async {
      await pumpView(tester, brightness: Brightness.dark);

      expect(find.byType(ConfigSettingRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

Object? _flip(ConfigSettingsController controller, String key) {
  final field = controller.schema!.fieldFor(key)!;
  switch (field.control) {
    case ConfigFieldControl.toggle:
      return !(field.value as bool);
    case ConfigFieldControl.number:
    case ConfigFieldControl.duration:
      return ((field.value as num?)?.toInt() ?? 0) + 1;
    case ConfigFieldControl.choice:
      final choices = field.choices!;
      return choices.firstWhere(
        (c) => c != field.value,
        orElse: () => choices.first,
      );
    case ConfigFieldControl.text:
      return 'changed';
  }
}
