// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../storage/atomic_file_write.dart';
import 'application_settings.dart';

abstract class ApplicationSettingsRepository {
  String get storagePath;

  Future<ApplicationSettings> read();
  Future<void> write(ApplicationSettings settings);
  Future<void> reset();
}

enum ApplicationSettingsPlatform { macOS, windows, linux, other }

class ApplicationSettingsPathResolver {
  const ApplicationSettingsPathResolver({
    Map<String, String>? environment,
    ApplicationSettingsPlatform? platformOverride,
  }) : _environment = environment,
       _platformOverride = platformOverride;

  final Map<String, String>? _environment;
  final ApplicationSettingsPlatform? _platformOverride;

  String resolveStoragePath() {
    final platform = _platformOverride ?? _detectPlatform();
    if (platform == ApplicationSettingsPlatform.windows) {
      final appData = _readEnv('APPDATA');
      if (appData != null) {
        return _joinPath(appData, <String>[
          'Genaisys',
          'application_settings.json',
        ]);
      }

      final userProfile = _readEnv('USERPROFILE');
      if (userProfile != null) {
        return _joinPath(userProfile, <String>[
          'AppData',
          'Roaming',
          'Genaisys',
          'application_settings.json',
        ]);
      }

      throw StateError(
        'Unable to resolve application settings path for Windows. '
        'Expected APPDATA or USERPROFILE environment variable.',
      );
    }

    final home = _readEnv('HOME') ?? _readEnv('USERPROFILE');
    if (home == null) {
      throw StateError(
        'Unable to resolve application settings path. '
        'Expected HOME environment variable.',
      );
    }
    return _joinPath(home, <String>[
      '.genaisys',
      'application_settings.json',
    ]);
  }

  ApplicationSettingsPlatform _detectPlatform() {
    if (Platform.isMacOS) {
      return ApplicationSettingsPlatform.macOS;
    }
    if (Platform.isWindows) {
      return ApplicationSettingsPlatform.windows;
    }
    if (Platform.isLinux) {
      return ApplicationSettingsPlatform.linux;
    }
    return ApplicationSettingsPlatform.other;
  }

  String? _readEnv(String key) {
    final env = _environment ?? Platform.environment;
    final value = env[key]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String _joinPath(String root, List<String> fragments) {
    var current = root;
    for (final fragment in fragments) {
      final normalized = _trimSlashes(fragment);
      if (normalized.isEmpty) {
        continue;
      }
      if (_endsWithAnySeparator(current)) {
        current = '$current$normalized';
      } else {
        current = '$current${Platform.pathSeparator}$normalized';
      }
    }
    return current;
  }

  bool _endsWithAnySeparator(String value) {
    return value.endsWith('/') || value.endsWith('\\');
  }

  String _trimSlashes(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'^[\\/]+|[\\/]+$'), '');
  }
}

class FileApplicationSettingsRepository
    implements ApplicationSettingsRepository {
  FileApplicationSettingsRepository({
    ApplicationSettingsPathResolver? pathResolver,
    String? storagePath,
  }) : _storagePath =
           storagePath ??
           (pathResolver ?? const ApplicationSettingsPathResolver())
               .resolveStoragePath();

  static const int schemaVersion = 1;

  final String _storagePath;

  @override
  String get storagePath => _storagePath;

  @override
  Future<ApplicationSettings> read() async {
    final file = File(storagePath);
    if (!file.existsSync()) {
      return ApplicationSettings.defaults;
    }

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      return ApplicationSettings.defaults;
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException(
        'Application settings payload must be a JSON object.',
      );
    }

    final jsonMap = Map<String, Object?>.from(decoded.cast<String, Object?>());
    return ApplicationSettings.fromJson(jsonMap);
  }

  @override
  Future<void> write(ApplicationSettings settings) async {
    final payload = <String, Object?>{
      'schema_version': schemaVersion,
      ...settings.toJson(),
    };
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    AtomicFileWrite.writeStringSync(storagePath, encoded);
  }

  @override
  Future<void> reset() async {
    await write(ApplicationSettings.defaults);
  }
}
