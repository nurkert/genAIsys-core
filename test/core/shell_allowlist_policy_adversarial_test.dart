import 'package:test/test.dart';

import 'package:genaisys/core/policy/shell_allowlist_policy.dart';

void main() {
  test('ShellAllowlistPolicy blocks chaining and separator abuse', () {
    final policy = ShellAllowlistPolicy(allowedPrefixes: ['dart analyze']);

    expect(policy.allows('dart analyze && echo hacked'), isFalse);
    expect(policy.allows('dart analyze; echo hacked'), isFalse);
    expect(policy.allows('dart analyze | cat'), isFalse);
    expect(policy.allows('dart analyze \n echo hacked'), isFalse);
    expect(policy.allows('dart analyze \r\n echo hacked'), isFalse);
  });

  test('ShellAllowlistPolicy blocks subshell and backtick execution', () {
    final policy = ShellAllowlistPolicy(allowedPrefixes: ['dart analyze']);

    expect(policy.allows('dart analyze \$(whoami)'), isFalse);
    expect(policy.allows('dart analyze "\$(whoami)"'), isFalse);
    expect(policy.allows('dart analyze `whoami`'), isFalse);
  });

  test('ShellAllowlistPolicy blocks argument smuggling attempts', () {
    final policy = ShellAllowlistPolicy(allowedPrefixes: ['flutter test']);

    expect(
      policy.allows('flutter test --plain-name "ok" \n rm -rf /'),
      isFalse,
    );
    expect(
      policy.allows('flutter test --reporter=\$(cat /tmp/secret)'),
      isFalse,
    );
  });

  test('ShellAllowlistPolicy keeps legitimate quoted commands passable', () {
    final policy = ShellAllowlistPolicy(
      allowedPrefixes: ['flutter test', 'dart analyze'],
    );

    expect(
      policy.allows('flutter test --plain-name "App flow happy path"'),
      isTrue,
    );
    expect(policy.allows("dart analyze '--literal-\$(not-executed)'"), isTrue);
    expect(policy.allows('dart analyze --fatal-infos'), isTrue);
  });
}
