import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_runner.dart';
import 'package:genaisys/core/settings/application_settings.dart';
import 'package:genaisys/core/settings/application_settings_repository.dart';

void main() {
  Future<String> captureRun({
    required List<String> args,
    required _MemoryApplicationSettingsRepository repository,
    required File stdoutFile,
    required File stderrFile,
  }) async {
    final stdoutSink = stdoutFile.openWrite();
    final stderrSink = stderrFile.openWrite();
    try {
      await CliRunner(
        applicationSettingsRepository: repository,
        stdout: stdoutSink,
        stderr: stderrSink,
      ).run(args);
      await stdoutSink.flush();
      await stderrSink.flush();
    } finally {
      await stdoutSink.close();
      await stderrSink.close();
      await stdoutSink.done;
      await stderrSink.done;
    }
    return stdoutFile.readAsStringSync();
  }

  test('CLI settings --json prints persisted global settings', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_app_settings_show_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final repository = _MemoryApplicationSettingsRepository(
      storagePath: '${temp.path}/application_settings.json',
      initial: const ApplicationSettings(
        themeMode: ApplicationThemeMode.dark,
        languageCode: 'en',
        desktopNotificationsEnabled: false,
        autopilotByDefaultEnabled: true,
        localTelemetryEnabled: false,
        strictSecretRedactionEnabled: true,
      ),
    );
    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureRun(
      args: ['settings', '--json'],
      repository: repository,
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    expect(stderrFile.readAsStringSync(), isEmpty);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded['storage_path'], repository.storagePath);
    final settings = decoded['settings'] as Map<String, dynamic>;
    expect(settings['theme_mode'], 'dark');
    expect(settings['language_code'], 'en');
    expect(settings['desktop_notifications_enabled'], false);
    expect(settings['autopilot_by_default_enabled'], true);
    expect(settings['local_telemetry_enabled'], false);
    expect(settings['strict_secret_redaction_enabled'], true);
  });

  test('CLI settings set updates repository', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_app_settings_set_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final repository = _MemoryApplicationSettingsRepository(
      storagePath: '${temp.path}/application_settings.json',
    );
    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    await captureRun(
      args: [
        'settings',
        'set',
        '--theme',
        'dark',
        '--language',
        'EN',
        '--notifications',
        'false',
        '--autopilot',
        'true',
        '--telemetry',
        'false',
        '--strict-secrets',
        'false',
        '--json',
      ],
      repository: repository,
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    expect(stderrFile.readAsStringSync(), isEmpty);
    expect(repository.writeCount, 1);
    expect(
      repository.current,
      const ApplicationSettings(
        themeMode: ApplicationThemeMode.dark,
        languageCode: 'en',
        desktopNotificationsEnabled: false,
        autopilotByDefaultEnabled: true,
        localTelemetryEnabled: false,
        strictSecretRedactionEnabled: false,
      ),
    );
  });

  test('CLI settings set returns JSON error for invalid bool', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_app_settings_invalid_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final repository = _MemoryApplicationSettingsRepository(
      storagePath: '${temp.path}/application_settings.json',
    );
    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    final output = await captureRun(
      args: ['settings', 'set', '--notifications', 'maybe', '--json'],
      repository: repository,
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 64);
    expect(stderrFile.readAsStringSync(), isEmpty);
    expect(repository.writeCount, 0);
    final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
    expect(decoded['code'], 'invalid_option');
    expect(decoded['error'], contains('Invalid value for --notifications'));
  });

  test(
    'CLI settings set returns JSON error for invalid theme mode',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cli_app_settings_invalid_theme_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
        exitCode = 0;
      });

      final repository = _MemoryApplicationSettingsRepository(
        storagePath: '${temp.path}/application_settings.json',
      );
      final stdoutFile = File('${temp.path}/stdout.txt');
      final stderrFile = File('${temp.path}/stderr.txt');

      exitCode = 0;
      final output = await captureRun(
        args: ['settings', 'set', '--theme', 'neon', '--json'],
        repository: repository,
        stdoutFile: stdoutFile,
        stderrFile: stderrFile,
      );

      expect(exitCode, 64);
      expect(stderrFile.readAsStringSync(), isEmpty);
      expect(repository.writeCount, 0);
      final decoded = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(decoded['code'], 'invalid_option');
      expect(decoded['error'], contains('Invalid value for --theme'));
    },
  );

  test('CLI settings reset restores defaults', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_cli_app_settings_reset_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    final repository = _MemoryApplicationSettingsRepository(
      storagePath: '${temp.path}/application_settings.json',
      initial: const ApplicationSettings(
        themeMode: ApplicationThemeMode.light,
        languageCode: 'fr',
        desktopNotificationsEnabled: false,
        autopilotByDefaultEnabled: true,
        localTelemetryEnabled: false,
        strictSecretRedactionEnabled: false,
      ),
    );
    final stdoutFile = File('${temp.path}/stdout.txt');
    final stderrFile = File('${temp.path}/stderr.txt');

    exitCode = 0;
    await captureRun(
      args: ['settings', 'reset', '--json'],
      repository: repository,
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
    );

    expect(exitCode, 0);
    expect(stderrFile.readAsStringSync(), isEmpty);
    expect(repository.resetCount, 1);
    expect(repository.current, ApplicationSettings.defaults);
  });
}

class _MemoryApplicationSettingsRepository
    implements ApplicationSettingsRepository {
  _MemoryApplicationSettingsRepository({
    required this.storagePath,
    ApplicationSettings? initial,
  }) : _settings = initial ?? ApplicationSettings.defaults;

  @override
  final String storagePath;

  ApplicationSettings _settings;
  int writeCount = 0;
  int resetCount = 0;

  ApplicationSettings get current => _settings;

  @override
  Future<ApplicationSettings> read() async {
    return _settings;
  }

  @override
  Future<void> write(ApplicationSettings settings) async {
    _settings = settings;
    writeCount += 1;
  }

  @override
  Future<void> reset() async {
    _settings = ApplicationSettings.defaults;
    resetCount += 1;
  }
}
