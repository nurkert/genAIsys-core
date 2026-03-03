import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/policy/safe_write_policy.dart';

void main() {
  test('SafeWritePolicy blocks traversal escape attempts', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_adversarial_traversal_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    final policy = SafeWritePolicy(
      projectRoot: temp.path,
      allowedRoots: ['lib'],
    );

    expect(
      policy.violationForPath('../lib/escaped.dart')?.category,
      'path_traversal',
    );
    expect(
      policy.violationForPath(r'..\lib\escaped.dart')?.category,
      'path_traversal',
    );
    expect(
      policy.violationForPath('lib/../../secrets.txt')?.category,
      'path_traversal',
    );
  });

  test('SafeWritePolicy blocks encoded traversal and protected targets', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_adversarial_encoded_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    final policy = SafeWritePolicy(
      projectRoot: temp.path,
      allowedRoots: ['lib'],
    );

    expect(
      policy.violationForPath('%2e%2e/%2e%2e/.git/config')?.category,
      'path_traversal',
    );
    expect(
      policy.violationForPath('lib/%2e%2e/.genaisys/STATE.json')?.category,
      'genaisys_state',
    );
  });

  test('SafeWritePolicy blocks symlink escape outside project root', () {
    if (Platform.isWindows) {
      return;
    }
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_adversarial_symlink_',
    );
    final outside = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_adversarial_outside_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
      outside.deleteSync(recursive: true);
    });

    final libDir = Directory('${temp.path}${Platform.pathSeparator}lib');
    libDir.createSync(recursive: true);
    final linkPath = '${libDir.path}${Platform.pathSeparator}escape';
    try {
      Link(linkPath).createSync(outside.path);
    } on FileSystemException {
      return;
    }

    final policy = SafeWritePolicy(
      projectRoot: temp.path,
      allowedRoots: ['lib'],
    );
    final violation = policy.violationForPath(
      'lib${Platform.pathSeparator}escape${Platform.pathSeparator}payload.txt',
    );
    expect(violation?.category, 'symlink_escape');
  });

  test('SafeWritePolicy keeps legitimate in-root paths passable', () {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_safe_write_adversarial_positive_',
    );
    addTearDown(() {
      temp.deleteSync(recursive: true);
    });
    final policy = SafeWritePolicy(
      projectRoot: temp.path,
      allowedRoots: ['lib'],
    );

    expect(policy.allowsPath('./lib/main.dart'), isTrue);
    expect(policy.allowsPath('lib/./nested/file.dart'), isTrue);
    expect(policy.allowsPath('./'), isFalse);
  });
}
