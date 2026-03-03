import 'package:test/test.dart';

import 'package:genaisys/core/policy/language_policy.dart';

void main() {
  test('LanguagePolicy allows English text', () {
    expect(
      () => LanguagePolicy.enforceEnglish('This is a short task plan.'),
      returnsNormally,
    );
  });

  test('LanguagePolicy allows empty text', () {
    expect(() => LanguagePolicy.enforceEnglish(''), returnsNormally);
  });

  test('LanguagePolicy rejects umlauts', () {
    expect(
      () => LanguagePolicy.enforceEnglish('Überprüfung'),
      throwsStateError,
    );
  });

  test('LanguagePolicy rejects common German words', () {
    expect(
      () => LanguagePolicy.enforceEnglish('Das ist nicht korrekt.'),
      throwsStateError,
    );
  });
}
