import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/shared/cli_structured_error.dart';

void main() {
  test('CliStructuredError.toJson() includes all fields', () {
    const error = CliStructuredError(
      errorCode: 'preflight_failed',
      errorClass: 'preflight',
      errorKind: 'git_dirty',
      message: 'Git worktree is dirty.',
      remediationHint: 'Commit or stash your changes.',
    );

    final json = error.toJson();
    expect(json['error_code'], 'preflight_failed');
    expect(json['error_class'], 'preflight');
    expect(json['error_kind'], 'git_dirty');
    expect(json['message'], 'Git worktree is dirty.');
    expect(json['remediation_hint'], 'Commit or stash your changes.');
  });

  test('CliStructuredError.toJson() round-trips through jsonEncode/Decode', () {
    const error = CliStructuredError(
      errorCode: 'yaml_parse',
      message: 'Unexpected token at line 42.',
    );

    final encoded = jsonEncode(error.toJson());
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;

    expect(decoded['error_code'], 'yaml_parse');
    expect(decoded['message'], 'Unexpected token at line 42.');
    expect(decoded['error_class'], isNull);
    expect(decoded['error_kind'], isNull);
    expect(decoded['remediation_hint'], isNull);
  });

  test('CliStructuredError.write() emits a valid JSON line', () {
    final buffer = StringBuffer();
    final sink = _StringBufferSink(buffer);

    const error = CliStructuredError(
      errorCode: 'test_code',
      errorClass: 'test_class',
      errorKind: 'test_kind',
      message: 'Test message.',
      remediationHint: 'Fix it.',
    );

    CliStructuredError.write(sink, error);
    final line = buffer.toString().trim();
    expect(line, isNotEmpty);

    final decoded = jsonDecode(line) as Map<String, dynamic>;
    expect(decoded['error_code'], 'test_code');
    expect(decoded['message'], 'Test message.');
  });

  test('CliStructuredError.toJson() strict key set', () {
    const error = CliStructuredError(
      errorCode: 'some_code',
      message: 'Some message.',
    );

    final json = error.toJson();
    final expectedKeys = <String>{
      'error_code',
      'error_class',
      'error_kind',
      'message',
      'remediation_hint',
    };
    expect(json.keys.toSet(), equals(expectedKeys));
  });
}

/// Minimal IOSink backed by a StringBuffer for unit testing.
class _StringBufferSink implements IOSink {
  _StringBufferSink(this._buffer);

  final StringBuffer _buffer;

  @override
  Encoding encoding = utf8;

  @override
  void write(Object? obj) => _buffer.write(obj);

  @override
  void writeln([Object? obj = '']) {
    _buffer.write(obj);
    _buffer.write('\n');
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    _buffer.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();
}
