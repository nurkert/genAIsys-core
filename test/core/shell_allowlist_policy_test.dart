import 'package:test/test.dart';

import 'package:genaisys/core/policy/shell_allowlist_policy.dart';

void main() {
  test('ShellAllowlistPolicy allows prefixed commands', () {
    final policy = ShellAllowlistPolicy(
      allowedPrefixes: ['flutter test', 'dart format'],
    );

    expect(policy.allows('flutter test'), isTrue);
    expect(policy.allows('flutter test --coverage'), isTrue);
    expect(policy.allows('dart format lib'), isTrue);
  });

  test('ShellAllowlistPolicy rejects unknown commands', () {
    final policy = ShellAllowlistPolicy(allowedPrefixes: ['flutter test']);

    expect(policy.allows('rm -rf /'), isFalse);
    expect(policy.allows('flutter build'), isFalse);
  });

  test('ShellAllowlistPolicy rejects shell command chaining', () {
    final policy = ShellAllowlistPolicy(allowedPrefixes: ['dart analyze']);

    expect(policy.allows('dart analyze && rm -rf /'), isFalse);
    expect(policy.allows('dart analyze; echo hacked'), isFalse);
    expect(policy.allows('dart analyze | cat'), isFalse);
  });

  test('ShellAllowlistPolicy supports quoted arguments token-safe', () {
    final policy = ShellAllowlistPolicy(allowedPrefixes: ['flutter test']);

    expect(
      policy.allows('flutter test --plain-name "App flow happy path"'),
      isTrue,
    );
  });

  test('ShellAllowlistPolicy allows claude command with args', () {
    final policy = ShellAllowlistPolicy(
      allowedPrefixes: ['claude', 'codex', 'gemini'],
    );

    expect(policy.allows('claude -p --output-format text'), isTrue);
    expect(
      policy.allows(
        'claude -p --output-format text --dangerously-skip-permissions',
      ),
      isTrue,
    );
    expect(policy.allows('claude --help'), isTrue);
  });

  test('ShellAllowlistPolicy allows all when disabled', () {
    final policy = ShellAllowlistPolicy(
      allowedPrefixes: const [],
      enabled: false,
    );

    expect(policy.allows('rm -rf /'), isTrue);
  });
}
