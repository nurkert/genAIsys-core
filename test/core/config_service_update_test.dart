import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/core.dart';

import '../support/test_workspace.dart';

void main() {
  test('ConfigService creates config.yml when missing', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_cfg_create_');
    addTearDown(workspace.dispose);

    final service = ConfigService();
    service.update(
      workspace.root.path,
      update: const ConfigUpdate(
        safeWriteEnabled: false,
        shellAllowlist: ['flutter test'],
      ),
    );

    final configFile = File(workspace.layout.configPath);
    expect(configFile.existsSync(), isTrue);

    final contents = configFile.readAsStringSync();
    expect(contents, contains('safe_write:'));
    expect(contents, contains('enabled: false'));
    expect(contents, contains('flutter test'));
  });

  test('ConfigService preserves shell_allowlist comments', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_cfg_comments_');
    addTearDown(workspace.dispose);
    Directory(workspace.layout.genaisysDir).createSync(recursive: true);
    File(workspace.layout.configPath).writeAsStringSync('''policies:
  safe_write:
    enabled: true
  shell_allowlist:
    # allowlist comment
    - "flutter test"

    # trailing comment
  diff_budget:
    max_files: 10
    max_additions: 100
    max_deletions: 80
''');

    final service = ConfigService();
    service.update(
      workspace.root.path,
      update: const ConfigUpdate(shellAllowlist: ['dart format']),
    );

    final contents = File(workspace.layout.configPath).readAsStringSync();
    expect(contents, contains('# allowlist comment'));
    expect(contents, contains('# trailing comment'));
    expect(contents, contains('dart format'));
    expect(contents, contains('diff_budget:'));
  });

  test('ConfigService updates quality_gate settings', () {
    final workspace = TestWorkspace.create(prefix: 'genaisys_cfg_quality_');
    addTearDown(workspace.dispose);

    final service = ConfigService();
    service.update(
      workspace.root.path,
      update: const ConfigUpdate(
        qualityGateEnabled: false,
        qualityGateTimeoutSeconds: 42,
        qualityGateCommands: ['dart analyze'],
      ),
    );

    final config = ProjectConfig.load(workspace.root.path);
    expect(config.qualityGateEnabled, isFalse);
    expect(config.qualityGateTimeout, const Duration(seconds: 42));
    expect(config.qualityGateCommands, equals(['dart analyze']));
  });

  test('ConfigService updates adaptive quality_gate settings', () {
    final workspace = TestWorkspace.create(
      prefix: 'genaisys_cfg_quality_adaptive_',
    );
    addTearDown(workspace.dispose);

    final service = ConfigService();
    service.update(
      workspace.root.path,
      update: const ConfigUpdate(
        qualityGateAdaptiveByDiff: false,
        qualityGateSkipTestsForDocsOnly: false,
        qualityGatePreferDartTestForLibDartOnly: false,
        qualityGateFlakeRetryCount: 0,
      ),
    );

    final config = ProjectConfig.load(workspace.root.path);
    expect(config.qualityGateAdaptiveByDiff, isFalse);
    expect(config.qualityGateSkipTestsForDocsOnly, isFalse);
    expect(config.qualityGatePreferDartTestForLibDartOnly, isFalse);
    expect(config.qualityGateFlakeRetryCount, 0);
  });
}
