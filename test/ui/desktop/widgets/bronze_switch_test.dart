import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/ui/desktop/widgets/common/bronze_switch.dart';

void main() {
  testWidgets('BronzeSwitch animates thumb between off and on states', (
    WidgetTester tester,
  ) async {
    bool enabled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Scaffold(
              body: Center(
                child: BronzeSwitch(
                  value: enabled,
                  onChanged: (bool next) {
                    setState(() {
                      enabled = next;
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    final Finder switchFinder = find.byType(BronzeSwitch);
    final Finder thumbFinder = find.byKey(
      const ValueKey<String>('desktop.bronzeSwitch.thumb'),
    );

    final double leftOff = tester.getTopLeft(thumbFinder).dx;

    await tester.tap(switchFinder);
    await tester.pump();
    await tester.pumpAndSettle();
    final double leftOn = tester.getTopLeft(thumbFinder).dx;
    expect(leftOn, greaterThan(leftOff));

    await tester.tap(switchFinder);
    await tester.pump();
    await tester.pumpAndSettle();
    final double leftBackOff = tester.getTopLeft(thumbFinder).dx;
    expect(leftBackOff, lessThan(leftOn));
  });
}
