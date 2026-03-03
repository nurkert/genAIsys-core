import 'package:test/test.dart';
import 'package:genaisys/core/services/autopilot/autopilot_release_tag_service.dart';

void main() {
  group('AutopilotReleaseTagService', () {
    group('sanitizeTagPart', () {
      late AutopilotReleaseTagService service;

      setUp(() {
        service = AutopilotReleaseTagService();
      });

      test('preserves valid tag characters', () {
        expect(
          service.sanitizeTagPart('v1.2.3', fallback: '0.0.0'),
          'v1.2.3',
        );
      });

      test('replaces invalid characters with hyphens', () {
        expect(
          service.sanitizeTagPart('hello world!', fallback: 'x'),
          'hello-world',
        );
      });

      test('collapses multiple hyphens', () {
        expect(
          service.sanitizeTagPart('a---b', fallback: 'x'),
          'a-b',
        );
      });

      test('strips leading dots and hyphens', () {
        expect(
          service.sanitizeTagPart('..v1', fallback: 'x'),
          'v1',
        );
      });

      test('strips trailing dots and hyphens', () {
        expect(
          service.sanitizeTagPart('v1..', fallback: 'x'),
          'v1',
        );
      });

      test('returns fallback for empty result', () {
        expect(
          service.sanitizeTagPart('!!!', fallback: 'fallback'),
          'fallback',
        );
      });

      test('returns fallback for whitespace-only input', () {
        expect(
          service.sanitizeTagPart('   ', fallback: 'default'),
          'default',
        );
      });

      test('preserves underscores', () {
        expect(
          service.sanitizeTagPart('my_tag', fallback: 'x'),
          'my_tag',
        );
      });
    });
  });
}
