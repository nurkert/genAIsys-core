// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

String? resolveExecutable(
  String executable, {
  Map<String, String>? environment,
  List<String> extraSearchPaths = const [],
}) {
  if (_isAbsolutePath(executable)) {
    return _isExecutable(executable) ? executable : null;
  }

  final paths = <String>[];
  final pathVar = environment?['PATH'] ?? Platform.environment['PATH'];
  if (pathVar != null && pathVar.trim().isNotEmpty) {
    final separator = Platform.isWindows ? ';' : ':';
    paths.addAll(
      pathVar.split(separator).map((p) => p.trim()).where((p) => p.isNotEmpty),
    );
  }
  for (final extra in extraSearchPaths) {
    if (!paths.contains(extra)) {
      paths.add(extra);
    }
  }

  for (final dir in paths) {
    final candidate = _joinPath(dir, executable);
    if (_isExecutable(candidate)) {
      return candidate;
    }
  }

  return null;
}

List<String> defaultSearchPaths() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final userBinPaths = <String>[];
  if (home != null) {
    if (Platform.isLinux || Platform.isMacOS) {
      userBinPaths.add(
        _joinPath(home, '.npm-global${Platform.pathSeparator}bin'),
      );
      userBinPaths.add(_joinPath(home, '.local${Platform.pathSeparator}bin'));
      userBinPaths.add(_joinPath(home, 'bin'));
    }
  }

  if (Platform.isMacOS) {
    return [
      ...userBinPaths,
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
    ];
  }
  if (Platform.isLinux) {
    return [...userBinPaths, '/usr/local/bin', '/usr/bin', '/bin'];
  }
  if (Platform.isWindows) {
    return const [r'C:\Windows\System32', r'C:\Windows'];
  }
  return const [];
}

bool _isAbsolutePath(String path) {
  if (path.startsWith('/')) {
    return true;
  }
  return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
}

String _joinPath(String left, String right) {
  final separator = Platform.pathSeparator;
  if (left.endsWith(separator)) {
    return '$left$right';
  }
  return '$left$separator$right';
}

bool _isExecutable(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return false;
  }
  if (Platform.isWindows) {
    return true;
  }
  try {
    final mode = file.statSync().mode;
    // Any execute bit set (owner/group/other).
    return mode & 0x49 != 0;
  } catch (_) {
    // Best-effort: stat may fail due to permissions or broken symlinks.
    return false;
  }
}
