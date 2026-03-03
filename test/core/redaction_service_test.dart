import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/security/redaction_service.dart';

void main() {
  test('RedactionService masks known token patterns and env values', () {
    final service = RedactionService(
      environment: {'OPENAI_API_KEY': 'sk-live-secret-value-123456789'},
    );

    final result = service.sanitizeText(
      'Bearer sk-live-secret-value-123456789 '
      'Authorization: Bearer sk-abcdefghijklmnopqrst '
      'JWT eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0In0.signature',
    );

    expect(result.report.applied, isTrue);
    expect(result.value, isNot(contains('sk-live-secret-value-123456789')));
    expect(result.value, isNot(contains('sk-abcdefghijklmnopqrst')));
    expect(result.value, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    expect(result.value, contains('[REDACTED:OPENAI_API_KEY]'));
    expect(result.report.types, isNotEmpty);
  });

  test('RedactionService keeps non-sensitive text unchanged', () {
    final service = RedactionService(environment: const {});
    const original = 'Task completed with clean output.';

    final result = service.sanitizeText(original);

    expect(result.report.applied, isFalse);
    expect(result.value, original);
  });

  test('RedactionService sanitizes nested objects recursively', () {
    final service = RedactionService(
      environment: {'GEMINI_API_KEY': 'AIza-secret-token-1234567890'},
    );
    final payload = <String, Object?>{
      'message': 'GEMINI_API_KEY=AIza-secret-token-1234567890',
      'events': <Object?>[
        {'stderr': 'Bearer sk-abcdefghijklmnop'},
      ],
    };

    final result = service.sanitizeObject(payload);
    final sanitized = (result.value as Map).cast<String, Object?>();
    final message = sanitized['message'] as String;
    final stderr =
        ((sanitized['events'] as List).first as Map)['stderr'] as String;

    expect(result.report.applied, isTrue);
    expect(message, isNot(contains('AIza-secret-token-1234567890')));
    expect(stderr, isNot(contains('sk-abcdefghijklmnop')));
  });
}
