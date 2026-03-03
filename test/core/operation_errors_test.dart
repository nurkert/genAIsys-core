import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/errors/operation_errors.dart';

void main() {
  test(
    'classifyOperationError returns TransientError for FileSystemException',
    () {
      final error = FileSystemException('disk failure');
      final classified = classifyOperationError(error, StackTrace.current);

      expect(classified, isA<TransientError>());
      expect(classified.message, contains('disk failure'));
    },
  );

  test(
    'classifyOperationError returns PermanentError for unrecognized StateError',
    () {
      final error = StateError(
        'Missing state OPENAI_API_KEY=sk-ABCDEFGHIJKLMNOP123456',
      );
      final classified = classifyOperationError(error, StackTrace.current);

      expect(classified, isA<PermanentError>());
      expect(classified.message, contains('Missing state'));
      expect(
        classified.message,
        isNot(contains('sk-ABCDEFGHIJKLMNOP123456')),
      );
      expect(classified.message, contains('[REDACTED:OPENAI_API_KEY]'));
    },
  );

  test(
    'classifyOperationError treats git push transport failures as transient',
    () {
      final error = StateError(
        'Unable to push main to origin in /tmp/repo\n'
        'fatal: unable to access https://example/repo.git: Could not resolve host',
      );
      final classified = classifyOperationError(error, StackTrace.current);

      expect(classified, isA<TransientError>());
      expect(classified.message, contains('Unable to push'));
    },
  );

  test('classifyOperationError keeps git auth failures permanent', () {
    final error = StateError(
      'Unable to push main to origin in /tmp/repo\n'
      'fatal: Authentication failed for https://example/repo.git',
    );
    final classified = classifyOperationError(error, StackTrace.current);

    expect(classified, isA<PermanentError>());
    expect(classified.message, contains('Authentication failed'));
  });

  test('classifyOperationError preserves existing OperationError', () {
    final error = TransientError('Temporary');
    final classified = classifyOperationError(error, StackTrace.current);

    expect(identical(classified, error), isTrue);
  });

  test('classifyOperationError maps ArgumentError to ValidationError', () {
    final error = ArgumentError('Bad input');
    final classified = classifyOperationError(error, StackTrace.current);

    expect(classified, isA<ValidationError>());
    expect(classified.message, contains('Bad input'));
  });

  test('classifyOperationError maps not-found StateError to NotFoundError', () {
    final error = StateError('Task not found');
    final classified = classifyOperationError(error, StackTrace.current);

    expect(classified, isA<NotFoundError>());
  });

  test(
    'classifyOperationError maps conflict-style StateError to ConflictError',
    () {
      final error = StateError('Task title already exists');
      final classified = classifyOperationError(error, StackTrace.current);

      expect(classified, isA<ConflictError>());
    },
  );

  test(
    'classifyOperationError maps policy-style StateError to PolicyViolationError',
    () {
      final error = StateError('Policy violation: safe_write blocked change');
      final classified = classifyOperationError(error, StackTrace.current);

      expect(classified, isA<PolicyViolationError>());
    },
  );

  test(
    'classifyOperationError treats provider exhaustion as transient',
    () {
      final error = StateError('No eligible provider configured.');
      final classified = classifyOperationError(error, StackTrace.current);

      expect(classified, isA<TransientError>());
      expect(classified.message, contains('No eligible provider'));
    },
  );

  group('transient git state errors', () {
    for (final msg in [
      'failed to checkout branch feat/task-1',
      'failed to create branch feat/task-2',
      'cannot lock ref refs/heads/main',
      'Unable to create index.lock: File exists',
    ]) {
      test('classifyOperationError treats "$msg" as TransientError', () {
        final error = StateError(msg);
        final classified = classifyOperationError(error, StackTrace.current);

        expect(classified, isA<TransientError>());
      });
    }
  });

  test(
    'classifyOperationError known patterns still classify correctly '
    'despite TransientError default',
    () {
      // PolicyViolation still matches first
      final pv = classifyOperationError(
        StateError('Policy violation: blocked'),
        StackTrace.current,
      );
      expect(pv, isA<PolicyViolationError>());

      // NotFound still matches first
      final nf = classifyOperationError(
        StateError('Task not found'),
        StackTrace.current,
      );
      expect(nf, isA<NotFoundError>());

      // Conflict still matches first
      final cf = classifyOperationError(
        StateError('Branch already exists'),
        StackTrace.current,
      );
      expect(cf, isA<ConflictError>());
    },
  );
}
