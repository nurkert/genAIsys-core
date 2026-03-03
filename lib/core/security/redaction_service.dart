// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

import 'redaction_policy.dart';

class RedactionReport {
  const RedactionReport({
    this.applied = false,
    this.replacementCount = 0,
    this.types = const <String>[],
  });

  final bool applied;
  final int replacementCount;
  final List<String> types;

  static const RedactionReport none = RedactionReport();
}

class RedactionResult<T> {
  const RedactionResult({required this.value, required this.report});

  final T value;
  final RedactionReport report;
}

class RedactionService {
  RedactionService({RedactionPolicy? policy, Map<String, String>? environment})
    : _policy = policy ?? const RedactionPolicy(),
      _environment = environment ?? Platform.environment;

  final RedactionPolicy _policy;
  final Map<String, String> _environment;

  static final RedactionService shared = RedactionService();

  RedactionResult<String> sanitizeText(String input) {
    if (input.isEmpty) {
      return const RedactionResult<String>(
        value: '',
        report: RedactionReport.none,
      );
    }

    var value = input;
    var replacementCount = 0;
    final types = <String>{};

    void replaceWithPattern({
      required RegExp pattern,
      required String replacement,
      required String type,
    }) {
      final matches = pattern.allMatches(value).length;
      if (matches == 0) {
        return;
      }
      value = value.replaceAll(pattern, replacement);
      replacementCount += matches;
      types.add(type);
    }

    for (final key in _policy.environmentKeys) {
      final raw = _environment[key]?.trim();
      if (raw == null || raw.length < _policy.minimumSecretLength) {
        continue;
      }
      final escaped = RegExp.escape(raw);
      final pattern = RegExp(escaped);
      final matches = pattern.allMatches(value).length;
      if (matches == 0) {
        continue;
      }
      value = value.replaceAll(pattern, '[REDACTED:$key]');
      replacementCount += matches;
      types.add('env:$key');
    }

    replaceWithPattern(
      pattern: RegExp(
        r'\b(authorization\s*[:=]\s*bearer\s+)([A-Za-z0-9._~+/\-]+=*)',
        caseSensitive: false,
      ),
      replacement: 'Authorization: Bearer [REDACTED:BEARER_TOKEN]',
      type: 'bearer_header',
    );

    replaceWithPattern(
      pattern: RegExp(
        r'\bbearer\s+[A-Za-z0-9._~+/\-]+=*',
        caseSensitive: false,
      ),
      replacement: 'Bearer [REDACTED:BEARER_TOKEN]',
      type: 'bearer_token',
    );

    replaceWithPattern(
      pattern: RegExp(r'\bsk-[A-Za-z0-9]{16,}\b'),
      replacement: '[REDACTED:OPENAI_TOKEN]',
      type: 'openai_token',
    );

    replaceWithPattern(
      pattern: RegExp(r'\bAIza[0-9A-Za-z_-]{20,}\b'),
      replacement: '[REDACTED:GEMINI_TOKEN]',
      type: 'gemini_token',
    );

    replaceWithPattern(
      pattern: RegExp(
        r'\beyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\b',
      ),
      replacement: '[REDACTED:JWT]',
      type: 'jwt',
    );

    value = value.replaceAllMapped(
      RegExp(
        r'''\b(OPENAI_API_KEY|GEMINI_API_KEY|ANTHROPIC_API_KEY|AZURE_OPENAI_API_KEY|COHERE_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|HF_TOKEN|HUGGINGFACEHUB_API_TOKEN|GITHUB_TOKEN|GITLAB_TOKEN|BITBUCKET_TOKEN|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN)(\s*[:=]\s*)([^\s"'`]+)''',
        caseSensitive: false,
      ),
      (match) {
        replacementCount += 1;
        final key = match.group(1)!.toUpperCase();
        types.add('kv:$key');
        return '$key${match.group(2)}[REDACTED:$key]';
      },
    );

    if (replacementCount == 0) {
      return RedactionResult<String>(
        value: value,
        report: RedactionReport.none,
      );
    }

    final sortedTypes = types.toList()..sort();
    return RedactionResult<String>(
      value: value,
      report: RedactionReport(
        applied: true,
        replacementCount: replacementCount,
        types: sortedTypes,
      ),
    );
  }

  RedactionResult<Object?> sanitizeObject(Object? value) {
    final collector = _Collector();
    final sanitized = _sanitizeObject(value, collector);
    return RedactionResult<Object?>(
      value: sanitized,
      report: collector.buildReport(),
    );
  }

  Map<String, Object?> buildMetadata(RedactionReport report) {
    return <String, Object?>{
      'applied': report.applied,
      'replacement_count': report.replacementCount,
      'types': report.types,
    };
  }

  Object? _sanitizeObject(Object? value, _Collector collector) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final sanitized = sanitizeText(value);
      collector.add(sanitized.report);
      return sanitized.value;
    }
    if (value is List) {
      return value.map((item) => _sanitizeObject(item, collector)).toList();
    }
    if (value is Map) {
      final out = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        out[key] = _sanitizeObject(entry.value, collector);
      }
      return out;
    }
    return value;
  }
}

class _Collector {
  var _replacementCount = 0;
  final Set<String> _types = <String>{};

  void add(RedactionReport report) {
    if (!report.applied) {
      return;
    }
    _replacementCount += report.replacementCount;
    _types.addAll(report.types);
  }

  RedactionReport buildReport() {
    if (_replacementCount == 0) {
      return RedactionReport.none;
    }
    final types = _types.toList()..sort();
    return RedactionReport(
      applied: true,
      replacementCount: _replacementCount,
      types: types,
    );
  }
}
