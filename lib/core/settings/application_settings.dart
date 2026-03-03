// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

enum ApplicationThemeMode {
  system,
  light,
  dark;

  String get storageValue => switch (this) {
    ApplicationThemeMode.system => 'system',
    ApplicationThemeMode.light => 'light',
    ApplicationThemeMode.dark => 'dark',
  };

  static ApplicationThemeMode fromStorageValue(Object? raw) {
    final String normalized = _normalizeString(raw);
    return switch (normalized) {
      'light' => ApplicationThemeMode.light,
      'dark' => ApplicationThemeMode.dark,
      _ => ApplicationThemeMode.system,
    };
  }

  static String _normalizeString(Object? raw) {
    if (raw is! String) {
      return '';
    }
    return raw.trim().toLowerCase();
  }
}

class ApplicationSettings {
  const ApplicationSettings({
    required this.themeMode,
    required this.languageCode,
    required this.desktopNotificationsEnabled,
    required this.autopilotByDefaultEnabled,
    required this.localTelemetryEnabled,
    required this.strictSecretRedactionEnabled,
  });

  static const ApplicationSettings defaults = ApplicationSettings(
    themeMode: ApplicationThemeMode.system,
    languageCode: 'en',
    desktopNotificationsEnabled: true,
    autopilotByDefaultEnabled: false,
    localTelemetryEnabled: true,
    strictSecretRedactionEnabled: true,
  );

  final ApplicationThemeMode themeMode;
  final String languageCode;
  final bool desktopNotificationsEnabled;
  final bool autopilotByDefaultEnabled;
  final bool localTelemetryEnabled;
  final bool strictSecretRedactionEnabled;

  ApplicationSettings copyWith({
    ApplicationThemeMode? themeMode,
    String? languageCode,
    bool? desktopNotificationsEnabled,
    bool? autopilotByDefaultEnabled,
    bool? localTelemetryEnabled,
    bool? strictSecretRedactionEnabled,
  }) {
    return ApplicationSettings(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      desktopNotificationsEnabled:
          desktopNotificationsEnabled ?? this.desktopNotificationsEnabled,
      autopilotByDefaultEnabled:
          autopilotByDefaultEnabled ?? this.autopilotByDefaultEnabled,
      localTelemetryEnabled:
          localTelemetryEnabled ?? this.localTelemetryEnabled,
      strictSecretRedactionEnabled:
          strictSecretRedactionEnabled ?? this.strictSecretRedactionEnabled,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'theme_mode': themeMode.storageValue,
      'language_code': languageCode,
      'desktop_notifications_enabled': desktopNotificationsEnabled,
      'autopilot_by_default_enabled': autopilotByDefaultEnabled,
      'local_telemetry_enabled': localTelemetryEnabled,
      'strict_secret_redaction_enabled': strictSecretRedactionEnabled,
    };
  }

  static ApplicationSettings fromJson(Map<String, Object?> json) {
    return ApplicationSettings(
      themeMode: ApplicationThemeMode.fromStorageValue(json['theme_mode']),
      languageCode: _stringOrDefault(
        json['language_code'],
        defaults.languageCode,
      ),
      desktopNotificationsEnabled: _boolOrDefault(
        json['desktop_notifications_enabled'],
        defaults.desktopNotificationsEnabled,
      ),
      autopilotByDefaultEnabled: _boolOrDefault(
        json['autopilot_by_default_enabled'],
        defaults.autopilotByDefaultEnabled,
      ),
      localTelemetryEnabled: _boolOrDefault(
        json['local_telemetry_enabled'],
        defaults.localTelemetryEnabled,
      ),
      strictSecretRedactionEnabled: _boolOrDefault(
        json['strict_secret_redaction_enabled'],
        defaults.strictSecretRedactionEnabled,
      ),
    );
  }

  static bool _boolOrDefault(Object? raw, bool fallback) {
    if (raw is bool) {
      return raw;
    }
    return fallback;
  }

  static String _stringOrDefault(Object? raw, String fallback) {
    if (raw is! String) {
      return fallback;
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ApplicationSettings &&
        other.themeMode == themeMode &&
        other.languageCode == languageCode &&
        other.desktopNotificationsEnabled == desktopNotificationsEnabled &&
        other.autopilotByDefaultEnabled == autopilotByDefaultEnabled &&
        other.localTelemetryEnabled == localTelemetryEnabled &&
        other.strictSecretRedactionEnabled == strictSecretRedactionEnabled;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    languageCode,
    desktopNotificationsEnabled,
    autopilotByDefaultEnabled,
    localTelemetryEnabled,
    strictSecretRedactionEnabled,
  );
}
