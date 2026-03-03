// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

class _AppSettingsHandler {
  const _AppSettingsHandler(this._runner);

  final CliRunner _runner;

  static const Set<String> _valueOptions = <String>{
    '--theme',
    '--language',
    '--notifications',
    '--autopilot',
    '--telemetry',
    '--strict-secrets',
  };

  Future<void> run(List<String> options) async {
    if (_runner._wantsHelp(options)) {
      _runner._printHelp();
      return;
    }

    final bool asJson = options.contains('--json');
    final List<String> normalizedOptions = options
        .where((String option) => option != '--json')
        .toList(growable: false);
    if (normalizedOptions.isEmpty) {
      await _showSettings(asJson: asJson);
      return;
    }

    final String subcommand = normalizedOptions.first.toLowerCase();
    switch (subcommand) {
      case 'show':
        await _showSettings(asJson: asJson);
        return;
      case 'set':
        await _setSettings(normalizedOptions.skip(1).toList(), asJson: asJson);
        return;
      case 'reset':
        await _resetSettings(asJson: asJson);
        return;
      default:
        _writeUsageError(
          asJson: asJson,
          code: 'unknown_subcommand',
          message:
              'Unknown subcommand: $subcommand. Use: settings [show|set|reset]',
        );
        return;
    }
  }

  Future<void> _showSettings({required bool asJson}) async {
    try {
      final ApplicationSettings settings = await _runner
          ._applicationSettingsRepository
          .read();
      _writeSettings(settings: settings, asJson: asJson, prefix: null);
    } on Object catch (error) {
      _writeCommandError(
        asJson: asJson,
        code: 'app_settings_read_failed',
        message: 'Failed to read application settings: $error',
      );
    }
  }

  Future<void> _setSettings(
    List<String> options, {
    required bool asJson,
  }) async {
    final validationError = _validateSetOptions(options);
    if (validationError != null) {
      _writeUsageError(
        asJson: asJson,
        code: validationError.code,
        message: validationError.message,
      );
      return;
    }

    try {
      final ApplicationSettings current = await _runner
          ._applicationSettingsRepository
          .read();
      var next = current;
      var changed = false;

      final String? theme = _runner._readOptionValue(options, '--theme');
      if (theme != null) {
        final ApplicationThemeMode? parsedTheme = _parseThemeMode(theme);
        if (parsedTheme == null) {
          _writeUsageError(
            asJson: asJson,
            code: 'invalid_option',
            message:
                'Invalid value for --theme: "$theme". '
                'Use one of: system, light, dark.',
          );
          return;
        }
        next = next.copyWith(themeMode: parsedTheme);
        changed = true;
      }

      final String? language = _runner._readOptionValue(options, '--language');
      if (language != null) {
        final normalized = language.trim().toLowerCase();
        if (normalized.isEmpty) {
          _writeUsageError(
            asJson: asJson,
            code: 'invalid_option',
            message: 'Invalid value for --language: must not be empty.',
          );
          return;
        }
        next = next.copyWith(languageCode: normalized);
        changed = true;
      }

      final _ParsedFlag<bool>? notifications = _parseBoolFlag(
        options,
        '--notifications',
      );
      if (notifications != null) {
        if (notifications.error != null) {
          _writeUsageError(
            asJson: asJson,
            code: 'invalid_option',
            message: notifications.error!,
          );
          return;
        }
        next = next.copyWith(desktopNotificationsEnabled: notifications.value!);
        changed = true;
      }

      final _ParsedFlag<bool>? autopilot = _parseBoolFlag(
        options,
        '--autopilot',
      );
      if (autopilot != null) {
        if (autopilot.error != null) {
          _writeUsageError(
            asJson: asJson,
            code: 'invalid_option',
            message: autopilot.error!,
          );
          return;
        }
        next = next.copyWith(autopilotByDefaultEnabled: autopilot.value!);
        changed = true;
      }

      final _ParsedFlag<bool>? telemetry = _parseBoolFlag(
        options,
        '--telemetry',
      );
      if (telemetry != null) {
        if (telemetry.error != null) {
          _writeUsageError(
            asJson: asJson,
            code: 'invalid_option',
            message: telemetry.error!,
          );
          return;
        }
        next = next.copyWith(localTelemetryEnabled: telemetry.value!);
        changed = true;
      }

      final _ParsedFlag<bool>? strictSecrets = _parseBoolFlag(
        options,
        '--strict-secrets',
      );
      if (strictSecrets != null) {
        if (strictSecrets.error != null) {
          _writeUsageError(
            asJson: asJson,
            code: 'invalid_option',
            message: strictSecrets.error!,
          );
          return;
        }
        next = next.copyWith(
          strictSecretRedactionEnabled: strictSecrets.value!,
        );
        changed = true;
      }

      if (!changed) {
        _writeUsageError(
          asJson: asJson,
          code: 'missing_option',
          message:
              'No changes provided. Use one or more: '
              '--theme, --language, --notifications, --autopilot, --telemetry, --strict-secrets.',
        );
        return;
      }

      await _runner._applicationSettingsRepository.write(next);
      _writeSettings(
        settings: next,
        asJson: asJson,
        prefix: 'Application settings updated.',
      );
    } on Object catch (error) {
      _writeCommandError(
        asJson: asJson,
        code: 'app_settings_write_failed',
        message: 'Failed to write application settings: $error',
      );
    }
  }

  Future<void> _resetSettings({required bool asJson}) async {
    try {
      await _runner._applicationSettingsRepository.reset();
      final ApplicationSettings settings = await _runner
          ._applicationSettingsRepository
          .read();
      _writeSettings(
        settings: settings,
        asJson: asJson,
        prefix: 'Application settings reset to defaults.',
      );
    } on Object catch (error) {
      _writeCommandError(
        asJson: asJson,
        code: 'app_settings_reset_failed',
        message: 'Failed to reset application settings: $error',
      );
    }
  }

  _UsageError? _validateSetOptions(List<String> options) {
    for (var i = 0; i < options.length; i++) {
      final String token = options[i];
      if (!token.startsWith('-')) {
        return _UsageError(
          code: 'invalid_option',
          message:
              'Unexpected argument "$token". '
              'Use: settings set [--theme <mode>] [--language <code>] '
              '[--notifications <bool>] [--autopilot <bool>] '
              '[--telemetry <bool>] [--strict-secrets <bool>]',
        );
      }
      if (!_valueOptions.contains(token)) {
        return _UsageError(
          code: 'invalid_option',
          message:
              'Unknown option: $token. Allowed options: '
              '--theme, --language, --notifications, --autopilot, --telemetry, --strict-secrets.',
        );
      }
      final int valueIndex = i + 1;
      if (valueIndex >= options.length || options[valueIndex].startsWith('-')) {
        return _UsageError(
          code: 'missing_option_value',
          message: 'Missing value for option: $token',
        );
      }
      i += 1;
    }
    return null;
  }

  _ParsedFlag<bool>? _parseBoolFlag(List<String> options, String flagName) {
    final String? rawValue = _runner._readOptionValue(options, flagName);
    if (rawValue == null) {
      return null;
    }
    final bool? value = _parseBool(rawValue);
    if (value == null) {
      return _ParsedFlag<bool>(
        value: null,
        error:
            'Invalid value for $flagName: "$rawValue". '
            'Use true/false, yes/no, on/off, 1/0.',
      );
    }
    return _ParsedFlag<bool>(value: value, error: null);
  }

  bool? _parseBool(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    switch (normalized) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        return null;
    }
  }

  ApplicationThemeMode? _parseThemeMode(String rawValue) {
    final String normalized = rawValue.trim().toLowerCase();
    return switch (normalized) {
      'system' => ApplicationThemeMode.system,
      'light' => ApplicationThemeMode.light,
      'dark' => ApplicationThemeMode.dark,
      _ => null,
    };
  }

  void _writeSettings({
    required ApplicationSettings settings,
    required bool asJson,
    required String? prefix,
  }) {
    if (asJson) {
      final Map<String, Object?> payload = <String, Object?>{
        'storage_path': _runner._applicationSettingsRepository.storagePath,
        'settings': settings.toJson(),
      };
      if (prefix != null) {
        payload['message'] = prefix;
      }
      _runner.stdout.writeln(jsonEncode(payload));
      return;
    }

    if (prefix != null) {
      _runner.stdout.writeln(prefix);
    }
    _runner.stdout.writeln(
      'Application settings path: ${_runner._applicationSettingsRepository.storagePath}',
    );
    _runner.stdout.writeln('theme_mode: ${settings.themeMode.storageValue}');
    _runner.stdout.writeln('language_code: ${settings.languageCode}');
    _runner.stdout.writeln(
      'desktop_notifications_enabled: ${settings.desktopNotificationsEnabled}',
    );
    _runner.stdout.writeln(
      'autopilot_by_default_enabled: ${settings.autopilotByDefaultEnabled}',
    );
    _runner.stdout.writeln(
      'local_telemetry_enabled: ${settings.localTelemetryEnabled}',
    );
    _runner.stdout.writeln(
      'strict_secret_redaction_enabled: ${settings.strictSecretRedactionEnabled}',
    );
  }

  void _writeUsageError({
    required bool asJson,
    required String code,
    required String message,
  }) {
    if (asJson) {
      _runner._writeJsonError(code: code, message: message);
    } else {
      _runner.stderr.writeln(message);
    }
    _runner.exitCode = 64;
  }

  void _writeCommandError({
    required bool asJson,
    required String code,
    required String message,
  }) {
    if (asJson) {
      _runner._writeJsonError(code: code, message: message);
    } else {
      _runner.stderr.writeln(message);
    }
    _runner.exitCode = 1;
  }
}

class _ParsedFlag<T> {
  const _ParsedFlag({required this.value, required this.error});

  final T? value;
  final String? error;
}

class _UsageError {
  const _UsageError({required this.code, required this.message});

  final String code;
  final String message;
}
