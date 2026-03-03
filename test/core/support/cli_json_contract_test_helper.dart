import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'cli_json_output_helper.dart';
import '../../support/locked_dart_runner.dart';

Map<String, dynamic> runCliJsonCommand(List<String> args) {
  final result = runLockedDartSync(<String>[
    'run',
    '--verbosity=error',
    '--',
    'bin/genaisys_cli.dart',
    ...args,
  ], workingDirectory: Directory.current.path);
  expect(result.exitCode, 0, reason: result.stderr.toString());

  final jsonLine = firstJsonPayload(result.stdout.toString());
  expect(jsonLine, isNotEmpty, reason: 'missing JSON payload in CLI output');

  return jsonDecode(jsonLine) as Map<String, dynamic>;
}

void expectRequiredKeys(
  Map<String, dynamic> payload,
  List<String> requiredKeys,
) {
  for (final key in requiredKeys) {
    expect(payload.containsKey(key), isTrue, reason: 'missing key: $key');
  }
}

void expectStrictKeySet(
  Map<String, dynamic> payload, {
  required List<String> requiredKeys,
  List<String> optionalKeys = const <String>[],
}) {
  expectRequiredKeys(payload, requiredKeys);
  final allowed = <String>{...requiredKeys, ...optionalKeys};
  final unexpected =
      payload.keys.where((key) => !allowed.contains(key)).toList()..sort();
  expect(
    unexpected,
    isEmpty,
    reason: 'unexpected keys: ${unexpected.join(', ')}',
  );
}

void expectStableFieldTypes(
  Map<String, dynamic> payload, {
  required Map<String, Matcher> typeByKey,
}) {
  for (final entry in typeByKey.entries) {
    final key = entry.key;
    expect(payload.containsKey(key), isTrue, reason: 'missing key: $key');
    expect(payload[key], entry.value, reason: 'invalid type for key: $key');
  }
}

void expectMachineReadableErrorFields(
  Map<String, dynamic> payload, {
  String classKey = 'error_class',
  String kindKey = 'error_kind',
}) {
  expect(
    payload.containsKey(classKey),
    isTrue,
    reason: 'missing key: $classKey',
  );
  expect(payload.containsKey(kindKey), isTrue, reason: 'missing key: $kindKey');
  expect(payload[classKey], anyOf(isNull, isA<String>()));
  expect(payload[kindKey], anyOf(isNull, isA<String>()));
}
