import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/ui/desktop/widgets/common/bronze_reflection.dart';

void main() {
  test('Bronze reflection is repelled away from cursor', () {
    const Alignment rest = Alignment(0, 0);
    const Size size = Size(100, 40);

    final Alignment nearLeft = BronzeReflectionPhysics.repelledAlignment(
      localPosition: const Offset(0, 20),
      size: size,
      restAlignment: rest,
      strength: 0.5,
    );
    final Alignment nearRight = BronzeReflectionPhysics.repelledAlignment(
      localPosition: const Offset(100, 20),
      size: size,
      restAlignment: rest,
      strength: 0.5,
    );

    expect(nearLeft.x, greaterThan(0));
    expect(nearRight.x, lessThan(0));
  });

  test('Bronze reflection has stable seed-based resting alignment', () {
    final Alignment a = BronzeReflectionPhysics.restingAlignmentForSeed(1234);
    final Alignment b = BronzeReflectionPhysics.restingAlignmentForSeed(1234);
    final Alignment c = BronzeReflectionPhysics.restingAlignmentForSeed(1235);

    expect(a, b);
    expect(a, isNot(c));
  });

  test(
    'Bronze reflection wandering path is deterministic per seed/progress',
    () {
      final Alignment a = BronzeReflectionPhysics.wanderingAlignment(
        seed: 77,
        progress: 0.35,
        hoverAmount: 0.4,
        pressAmount: 0.1,
      );
      final Alignment b = BronzeReflectionPhysics.wanderingAlignment(
        seed: 77,
        progress: 0.35,
        hoverAmount: 0.4,
        pressAmount: 0.1,
      );
      final Alignment c = BronzeReflectionPhysics.wanderingAlignment(
        seed: 78,
        progress: 0.35,
        hoverAmount: 0.4,
        pressAmount: 0.1,
      );

      expect(a, b);
      expect(a, isNot(c));
    },
  );

  test('Bronze reflection pulse stays in normalized bounds', () {
    for (int i = 0; i <= 20; i++) {
      final double progress = i / 20;
      final double pulse = BronzeReflectionPhysics.specularPulse(
        seed: 123,
        progress: progress,
      );
      expect(pulse, inInclusiveRange(-1.0, 1.0));
    }
  });
}
