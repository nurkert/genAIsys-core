import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/policy/safe_write_policy.dart';

void main() {
  test('SafeWritePolicy allows paths inside allowed roots', () {
    final temp = Directory.systemTemp.createTempSync('genaisys_safe_write_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final policy = SafeWritePolicy(
      projectRoot: temp.path,
      allowedRoots: ['lib', 'test'],
    );

    final libFile = File(
      '${temp.path}${Platform.pathSeparator}lib${Platform.pathSeparator}a.txt',
    );
    final testFile = File(
      '${temp.path}${Platform.pathSeparator}test${Platform.pathSeparator}b.txt',
    );

    expect(policy.allowsPath(libFile.path), isTrue);
    expect(policy.allowsPath(testFile.path), isTrue);
  });

  test('SafeWritePolicy rejects paths outside allowed roots', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_out_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final policy = SafeWritePolicy(
      projectRoot: temp.path,
      allowedRoots: ['lib'],
    );

    final otherFile = File(
      '${temp.path}${Platform.pathSeparator}docs${Platform.pathSeparator}readme.md',
    );

    expect(policy.allowsPath(otherFile.path), isFalse);
  });

  test('SafeWritePolicy allows all when disabled', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_off_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });

    final policy = SafeWritePolicy(
      projectRoot: temp.path,
      allowedRoots: const [],
      enabled: false,
    );

    final file = File('${temp.path}${Platform.pathSeparator}anywhere.txt');

    expect(policy.allowsPath(file.path), isTrue);
  });
}
