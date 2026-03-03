// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:io';

/// Unified output strategy for CLI surfaces.
///
/// - [CliOutput.plain]: plain text, no ANSI, grep-friendly (default for CI /
///   tests; also activated when `NO_COLOR` env var is set or `TERM=dumb`)
/// - [CliOutput.rich]: box-drawing, colours, symbols (enabled when stdout is
///   a TTY and no `NO_COLOR` env var is set)
/// - [CliOutput.auto]: picks at runtime based on `stdout.hasTerminal`
class CliOutput {
  const CliOutput._(this._rich);

  final bool _rich;

  /// Always plain — no ANSI, grep-friendly. Use for tests and CI.
  static const CliOutput plain = CliOutput._(false);

  /// Always rich — box-drawing, colours, symbols. Use for forced TTY tests.
  static const CliOutput rich = CliOutput._(true);

  /// Auto-detect: rich when stdout is a TTY and `NO_COLOR` / `TERM=dumb` are
  /// not set.
  factory CliOutput.auto() {
    final isTty = stdout.hasTerminal;
    final noColor =
        Platform.environment.containsKey('NO_COLOR') ||
        Platform.environment['TERM'] == 'dumb';
    return isTty && !noColor ? CliOutput.rich : CliOutput.plain;
  }

  /// Whether rich (ANSI / box-drawing) mode is active.
  bool get isRich => _rich;

  // ── Timestamp ────────────────────────────────────────────────────────────

  /// Formats [dt] (or `DateTime.now()` in local time) as `HH:MM:SS`.
  ///
  /// If [dt] is a UTC [DateTime] (e.g. from `DateTime.parse('…Z')`), its UTC
  /// hour/minute/second are used directly — this keeps test assertions stable
  /// across time zones.  Use `DateTime.now().toLocal()` for local time in
  /// production callers.
  String timestamp([DateTime? dt]) {
    final t = dt ?? DateTime.now().toLocal();
    return '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}';
  }

  /// Parses an ISO-8601 string and formats it as `HH:MM:SS`.
  /// Returns `'(none)'` for null/empty, or the raw string on parse failure.
  String parseTimestamp(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '(none)';
    try {
      return timestamp(DateTime.parse(isoStr));
    } catch (_) {
      return isoStr;
    }
  }

  // ── Symbols ──────────────────────────────────────────────────────────────

  String get ok => _rich ? '✓' : 'OK';
  String get fail => _rich ? '✗' : 'FAIL';
  String get retry => _rich ? '↺' : '~';
  String get run => _rich ? '▶' : '>>';
  String get arrow => _rich ? '→' : '->';
  String get bullet => _rich ? '·' : '.';

  // ── ANSI colours (identity in plain mode) ────────────────────────────────

  String green(String s) => _rich ? '\x1B[32m$s\x1B[0m' : s;
  String red(String s) => _rich ? '\x1B[31m$s\x1B[0m' : s;
  String yellow(String s) => _rich ? '\x1B[33m$s\x1B[0m' : s;
  String dim(String s) => _rich ? '\x1B[2m$s\x1B[0m' : s;
  String bold(String s) => _rich ? '\x1B[1m$s\x1B[0m' : s;
  String cyan(String s) => _rich ? '\x1B[36m$s\x1B[0m' : s;

  // ── Layout ───────────────────────────────────────────────────────────────

  static const _boxWidth = 56;

  /// `┌─ TITLE ────...─┐` (rich) or `=== TITLE ===` (plain).
  String boxHeader(String title) {
    if (!_rich) return '=== $title ===';
    final fill = (_boxWidth - title.length - 5).clamp(1, _boxWidth);
    return '┌─ $title ${'─' * fill}┐';
  }

  /// `│  content` (rich) or `  content` (plain).
  String boxRow(String content) => _rich ? '│  $content' : '  $content';

  /// `└────...─┘` (rich) or empty string (plain).
  String boxFooter() => _rich ? '└${'─' * (_boxWidth - 2)}┘' : '';

  /// Horizontal rule: `─` × [w] (rich) or `-` × [w] (plain).
  String separator([int w = 54]) => (_rich ? '─' : '-') * w;

  // ── Event filter ─────────────────────────────────────────────────────────

  static const _importantEvents = {
    'orchestrator_run_step_start',
    'orchestrator_run_step_outcome',
    'review_decision',
    'git_delivery_completed',
    'preflight_failed',
    'orchestrator_run_safety_halt',
    'orchestrator_run_stopped',
    'coding_agent_started',
    'hitl_gate_opened',
    'hitl_gate_resolved',
  };

  /// Returns `true` for the subset of run-log events that should be shown in
  /// the live tail (`follow` / `run --follow`).
  bool isImportantEvent(String event) => _importantEvents.contains(event);

  // ── Private helpers ──────────────────────────────────────────────────────

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
