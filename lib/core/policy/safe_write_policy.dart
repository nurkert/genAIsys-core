// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

class SafeWriteViolation {
  SafeWriteViolation({
    required this.path,
    required this.category,
    required this.message,
  });

  final String path;
  final String category;
  final String message;
}

class SafeWritePolicy {
  SafeWritePolicy({
    required this.projectRoot,
    required this.allowedRoots,
    this.enabled = true,
  });

  final String projectRoot;
  final List<String> allowedRoots;
  final bool enabled;

  SafeWriteViolation? violationForPath(String path) {
    if (!enabled) {
      return null;
    }
    final relative = _normalizeRelative(path);
    final decodedRelative = _decodePotentiallyEncoded(relative);
    final traversal = _traversalViolation(decodedRelative);
    if (traversal != null) {
      return traversal;
    }
    final normalizedRelative = _normalizeSegment(decodedRelative);
    final critical = _criticalViolation(normalizedRelative);
    if (critical != null) {
      return critical;
    }
    final symlinkEscape = _symlinkEscapeViolation(normalizedRelative);
    if (symlinkEscape != null) {
      return symlinkEscape;
    }
    if (_isWithinAllowedRoots(normalizedRelative)) {
      return null;
    }
    return SafeWriteViolation(
      path: path,
      category: 'outside_roots',
      message: 'Path is outside allowed safe-write roots.',
    );
  }

  bool allowsPath(String path) => violationForPath(path) == null;

  SafeWriteViolation? _traversalViolation(String relative) {
    final segments = relative.split('/');
    var depth = 0;
    for (final rawSegment in segments) {
      final segment = rawSegment.trim();
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (depth == 0) {
          return SafeWriteViolation(
            path: relative,
            category: 'path_traversal',
            message: 'Path traversal outside project root is blocked.',
          );
        }
        depth -= 1;
        continue;
      }
      depth += 1;
    }
    return null;
  }

  SafeWriteViolation? _criticalViolation(String relative) {
    for (final rule in _criticalRules) {
      if (rule.matches(relative)) {
        return SafeWriteViolation(
          path: relative,
          category: rule.category,
          message: rule.message,
        );
      }
    }
    return null;
  }

  bool _isWithinAllowedRoots(String relative) {
    if (allowedRoots.isEmpty) {
      return true;
    }
    final normalizedPath = _normalizeSegment(relative);
    for (final root in allowedRoots) {
      final normalizedRoot = _normalizeSegment(root);
      if (normalizedRoot.isEmpty || normalizedRoot == '.') {
        return true;
      }
      if (normalizedPath == normalizedRoot ||
          normalizedPath.startsWith('$normalizedRoot/')) {
        return true;
      }
    }
    return false;
  }

  String _normalizeRelative(String path) {
    var normalized = path.replaceAll('\\', '/');
    var root = projectRoot.replaceAll('\\', '/');
    if (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    if (root.isNotEmpty && normalized.startsWith(root)) {
      normalized = normalized.substring(root.length);
      if (normalized.startsWith('/')) {
        normalized = normalized.substring(1);
      }
    }
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  SafeWriteViolation? _symlinkEscapeViolation(String relative) {
    if (relative.isEmpty) {
      return null;
    }
    final root = _normalizeAbsolutePath(Directory(projectRoot).absolute.path);
    var cursor = root;
    for (final segment in relative.split('/')) {
      final part = segment.trim();
      if (part.isEmpty || part == '.') {
        continue;
      }
      cursor = '$cursor/$part';
      final entityType = FileSystemEntity.typeSync(cursor, followLinks: false);
      if (entityType == FileSystemEntityType.notFound) {
        break;
      }
      if (entityType != FileSystemEntityType.link) {
        continue;
      }
      try {
        final target = Link(cursor).resolveSymbolicLinksSync();
        final normalizedTarget = _normalizeAbsolutePath(target);
        if (!_isWithinRoot(normalizedTarget, root)) {
          return SafeWriteViolation(
            path: relative,
            category: 'symlink_escape',
            message: 'Path resolves through symlink outside project root.',
          );
        }
      } on FileSystemException {
        return SafeWriteViolation(
          path: relative,
          category: 'symlink_escape',
          message: 'Path resolves through unreadable symlink.',
        );
      }
    }
    return null;
  }

  bool _isWithinRoot(String candidate, String root) {
    return candidate == root || candidate.startsWith('$root/');
  }

  String _normalizeAbsolutePath(String path) {
    var normalized = path.replaceAll('\\', '/');
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _decodePotentiallyEncoded(String value) {
    try {
      return Uri.decodeFull(value);
    } on FormatException {
      return value;
    }
  }

  String _normalizeSegment(String value) {
    var normalized = value.replaceAll('\\', '/').trim();
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    final output = <String>[];
    for (final segment in normalized.split('/')) {
      final part = segment.trim();
      if (part.isEmpty || part == '.') {
        continue;
      }
      if (part == '..') {
        if (output.isNotEmpty) {
          output.removeLast();
        }
        continue;
      }
      output.add(part);
    }
    return output.join('/');
  }
}

class _SafeWriteCriticalRule {
  const _SafeWriteCriticalRule({
    required this.category,
    required this.message,
    required this.matches,
  });

  final String category;
  final String message;
  final bool Function(String path) matches;
}

const List<_SafeWriteCriticalRule> _criticalRules = [
  _SafeWriteCriticalRule(
    category: 'git_metadata',
    message: 'Git metadata is protected.',
    matches: _matchesGitMetadata,
  ),
  _SafeWriteCriticalRule(
    category: 'genaisys_control',
    message: 'Genaisys control files are protected.',
    matches: _matchesGenaisysControl,
  ),
  _SafeWriteCriticalRule(
    category: 'genaisys_state',
    message: 'Genaisys state files are protected.',
    matches: _matchesGenaisysState,
  ),
];

bool _matchesGitMetadata(String path) {
  return path == '.git' || path.startsWith('.git/');
}

bool _matchesGenaisysControl(String path) {
  return path == '.genaisys/config.yml' ||
      path == '.genaisys/RULES.md' ||
      path == '.genaisys/VISION.md';
}

bool _matchesGenaisysState(String path) {
  return path == '.genaisys/STATE.json';
}
