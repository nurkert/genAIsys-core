// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'cli_runner.dart';

extension _CliRunnerUtils on CliRunner {
  void _writeJsonError({required String code, required String message}) {
    _jsonPresenter.writeError(this.stdout, code: code, message: message);
  }

  String? _extractPath(List<String> options) {
    const optionsWithValues = {
      '--from',
      '--sprint-size',
      '--section',
      '--reason',
      '--detail',
      '--id',
      '--title',
      '--note',
      '--prompt',
      '--test-summary',
      '--min-open',
      '--max-plan-add',
      '--step-sleep',
      '--idle-sleep',
      '--max-steps',
      '--max-failures',
      '--max-task-retries',
      '--status-interval',
      '--duration',
      '--max-cycles',
      '--branch',
      '--profile',
      '--max-restarts',
      '--restart-backoff-base',
      '--restart-backoff-max',
      '--low-signal-limit',
      '--throughput-window-minutes',
      '--throughput-max-steps',
      '--throughput-max-rejects',
      '--throughput-max-high-retries',
      '--base',
      '--remote',
      '--session-id',
      '--theme',
      '--language',
      '--notifications',
      '--autopilot',
      '--telemetry',
      '--strict-secrets',
    };
    for (var i = 0; i < options.length; i++) {
      final option = options[i];
      if (optionsWithValues.contains(option)) {
        i += 1;
        continue;
      }
      if (!option.startsWith('-')) {
        return option;
      }
    }
    return null;
  }

  String? _readOptionValue(List<String> options, String name) {
    final index = options.indexOf(name);
    if (index == -1) {
      return null;
    }
    final valueIndex = index + 1;
    if (valueIndex >= options.length) {
      return null;
    }
    final value = options[valueIndex];
    if (value.startsWith('-')) {
      return null;
    }
    return value;
  }

  String _resolveRoot(String? path) {
    if (path == null || path.trim().isEmpty) {
      return _normalizeRoot(Directory.current.path);
    }
    return _normalizeRoot(Directory(path).absolute.path);
  }

  String _normalizeRoot(String rawPath) {
    final normalized = Uri.file(rawPath).normalizePath().toFilePath();
    return _trimTrailingSeparator(normalized);
  }

  String _trimTrailingSeparator(String path) {
    final separator = Platform.pathSeparator;
    if (path.endsWith(separator) && path.length > separator.length) {
      return path.substring(0, path.length - separator.length);
    }
    return path;
  }

  int? _parsePositiveIntOrNull(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 1) {
      return null;
    }
    return parsed;
  }

  int? _parseNonNegativeIntOrNull(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  Duration? _parseDurationOrNull(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized.endsWith('h')) {
      final hours = int.tryParse(
        normalized.substring(0, normalized.length - 1),
      );
      if (hours == null || hours < 0) {
        return null;
      }
      return Duration(hours: hours);
    }
    if (normalized.endsWith('m')) {
      final minutes = int.tryParse(
        normalized.substring(0, normalized.length - 1),
      );
      if (minutes == null || minutes < 0) {
        return null;
      }
      return Duration(minutes: minutes);
    }
    if (normalized.endsWith('s')) {
      final seconds = int.tryParse(
        normalized.substring(0, normalized.length - 1),
      );
      if (seconds == null || seconds < 0) {
        return null;
      }
      return Duration(seconds: seconds);
    }
    final seconds = int.tryParse(normalized);
    if (seconds == null || seconds < 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  bool _wantsHelp(List<String> options) {
    for (final option in options) {
      final normalized = option.trim().toLowerCase();
      if (normalized == '--help' ||
          normalized == '-h' ||
          normalized == 'help') {
        return true;
      }
    }
    return false;
  }
}
