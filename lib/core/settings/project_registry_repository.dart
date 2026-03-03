// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:io';

import '../storage/atomic_file_write.dart';
import 'project_registry.dart';

abstract class ProjectRegistryRepository {
  String get storagePath;

  Future<ProjectRegistry> read();
  Future<void> write(ProjectRegistry registry);
  Future<void> reset();
}

enum ProjectRegistryPlatform { macOS, windows, linux, other }

class ProjectRegistryPathResolver {
  const ProjectRegistryPathResolver({
    Map<String, String>? environment,
    ProjectRegistryPlatform? platformOverride,
  }) : _environment = environment,
       _platformOverride = platformOverride;

  final Map<String, String>? _environment;
  final ProjectRegistryPlatform? _platformOverride;

  String resolveStoragePath() {
    final ProjectRegistryPlatform platform =
        _platformOverride ?? _detectPlatform();
    if (platform == ProjectRegistryPlatform.windows) {
      final String? appData = _readEnv('APPDATA');
      if (appData != null) {
        return _joinPath(appData, <String>[
          'Genaisys',
          'project_registry.json',
        ]);
      }

      final String? userProfile = _readEnv('USERPROFILE');
      if (userProfile != null) {
        return _joinPath(userProfile, <String>[
          'AppData',
          'Roaming',
          'Genaisys',
          'project_registry.json',
        ]);
      }

      throw StateError(
        'Unable to resolve project registry path for Windows. '
        'Expected APPDATA or USERPROFILE environment variable.',
      );
    }

    final String? home = _readEnv('HOME') ?? _readEnv('USERPROFILE');
    if (home == null) {
      throw StateError(
        'Unable to resolve project registry path. '
        'Expected HOME environment variable.',
      );
    }
    return _joinPath(home, <String>['.genaisys', 'project_registry.json']);
  }

  ProjectRegistryPlatform _detectPlatform() {
    if (Platform.isMacOS) {
      return ProjectRegistryPlatform.macOS;
    }
    if (Platform.isWindows) {
      return ProjectRegistryPlatform.windows;
    }
    if (Platform.isLinux) {
      return ProjectRegistryPlatform.linux;
    }
    return ProjectRegistryPlatform.other;
  }

  String? _readEnv(String key) {
    final Map<String, String> env = _environment ?? Platform.environment;
    final String? value = env[key]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String _joinPath(String root, List<String> fragments) {
    var current = root;
    for (final String fragment in fragments) {
      final String normalized = _trimSlashes(fragment);
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
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'^[\\/]+|[\\/]+$'), '');
  }
}

class FileProjectRegistryRepository implements ProjectRegistryRepository {
  FileProjectRegistryRepository({
    ProjectRegistryPathResolver? pathResolver,
    String? storagePath,
  }) : _storagePath =
           storagePath ??
           (pathResolver ?? const ProjectRegistryPathResolver())
               .resolveStoragePath();

  static const int schemaVersion = 1;
  final String _storagePath;

  @override
  String get storagePath => _storagePath;

  @override
  Future<ProjectRegistry> read() async {
    final File file = File(storagePath);
    if (!file.existsSync()) {
      return ProjectRegistry.empty;
    }
    final String content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      return ProjectRegistry.empty;
    }
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException(
        'Project registry payload must be a JSON object.',
      );
    }
    final Map<String, Object?> mapped = Map<String, Object?>.from(
      decoded.cast<String, Object?>(),
    );
    return ProjectRegistry.fromJson(mapped);
  }

  @override
  Future<void> write(ProjectRegistry registry) async {
    final Map<String, Object?> payload = <String, Object?>{
      'schema_version': schemaVersion,
      ...registry.toJson(),
    };
    final String encoded = const JsonEncoder.withIndent('  ').convert(payload);
    AtomicFileWrite.writeStringSync(storagePath, encoded);
  }

  @override
  Future<void> reset() async {
    await write(ProjectRegistry.empty);
  }
}
