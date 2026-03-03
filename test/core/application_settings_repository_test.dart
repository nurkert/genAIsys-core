import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/settings/application_settings.dart';
import 'package:genaisys/core/settings/application_settings_repository.dart';

void main() {
  String normalize(String path) => path.replaceAll('\\', '/');

  test('path resolver uses HOME on macOS/linux-style platforms', () {
    const resolver = ApplicationSettingsPathResolver(
      environment: <String, String>{'HOME': '/Users/tester'},
      platformOverride: ApplicationSettingsPlatform.macOS,
    );

    final path = resolver.resolveStoragePath();
    expect(path, '/Users/tester/.genaisys/application_settings.json');
  });

  test('path resolver uses APPDATA on Windows', () {
    const resolver = ApplicationSettingsPathResolver(
      environment: <String, String>{
        'APPDATA': r'C:\Users\tester\AppData\Roaming',
      },
      platformOverride: ApplicationSettingsPlatform.windows,
    );

    final path = resolver.resolveStoragePath();
    expect(
      normalize(path),
      'C:/Users/tester/AppData/Roaming/Genaisys/application_settings.json',
    );
  });

  test('path resolver falls back to USERPROFILE on Windows', () {
    const resolver = ApplicationSettingsPathResolver(
      environment: <String, String>{'USERPROFILE': r'C:\Users\tester'},
      platformOverride: ApplicationSettingsPlatform.windows,
    );

    final path = resolver.resolveStoragePath();
    expect(
      normalize(path),
      'C:/Users/tester/AppData/Roaming/Genaisys/application_settings.json',
    );
  });

  test('file repository returns defaults when storage is missing', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_app_settings_missing_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final repository = FileApplicationSettingsRepository(
      storagePath: '${temp.path}/application_settings.json',
    );
    final settings = await repository.read();

    expect(settings, ApplicationSettings.defaults);
  });

  test('file repository writes and reads settings', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_app_settings_roundtrip_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final repository = FileApplicationSettingsRepository(
      storagePath: '${temp.path}/application_settings.json',
    );
    const expected = ApplicationSettings(
      themeMode: ApplicationThemeMode.dark,
      languageCode: 'en',
      desktopNotificationsEnabled: false,
      autopilotByDefaultEnabled: true,
      localTelemetryEnabled: false,
      strictSecretRedactionEnabled: true,
    );

    await repository.write(expected);
    final actual = await repository.read();

    expect(actual, expected);
  });

  test('file repository reset restores defaults', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_app_settings_reset_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final repository = FileApplicationSettingsRepository(
      storagePath: '${temp.path}/application_settings.json',
    );
    await repository.write(
      const ApplicationSettings(
        themeMode: ApplicationThemeMode.light,
        languageCode: 'fr',
        desktopNotificationsEnabled: false,
        autopilotByDefaultEnabled: true,
        localTelemetryEnabled: false,
        strictSecretRedactionEnabled: false,
      ),
    );

    await repository.reset();
    final actual = await repository.read();
    expect(actual, ApplicationSettings.defaults);
  });

  test('unknown persisted theme mode falls back to system', () async {
    final temp = Directory.systemTemp.createTempSync(
      'genaisys_app_settings_theme_fallback_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final File storage = File('${temp.path}/application_settings.json');
    storage.writeAsStringSync('''
{
  "schema_version": 1,
  "theme_mode": "invalid-mode",
  "language_code": "en"
}
''');

    final repository = FileApplicationSettingsRepository(
      storagePath: storage.path,
    );
    final ApplicationSettings settings = await repository.read();

    expect(settings.themeMode, ApplicationThemeMode.system);
  });
}
