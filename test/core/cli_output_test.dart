import 'package:test/test.dart';

import 'package:genaisys/core/cli/output/cli_output.dart';

void main() {
  group('CliOutput.plain', () {
    const o = CliOutput.plain;

    test('isRich is false', () {
      expect(o.isRich, isFalse);
    });

    test('symbols use ASCII fallbacks', () {
      expect(o.ok, 'OK');
      expect(o.fail, 'FAIL');
      expect(o.retry, '~');
      expect(o.run, '>>');
      expect(o.arrow, '->');
      expect(o.bullet, '.');
    });

    test('colour methods are identity', () {
      expect(o.green('hello'), 'hello');
      expect(o.red('hello'), 'hello');
      expect(o.yellow('hello'), 'hello');
      expect(o.dim('hello'), 'hello');
      expect(o.bold('hello'), 'hello');
      expect(o.cyan('hello'), 'hello');
    });

    test('boxHeader returns === title === format', () {
      expect(o.boxHeader('TEST'), '=== TEST ===');
    });

    test('boxRow returns indented content', () {
      expect(o.boxRow('content'), '  content');
    });

    test('boxFooter returns empty string', () {
      expect(o.boxFooter(), '');
    });

    test('separator returns dashes', () {
      expect(o.separator(10), '----------');
    });
  });

  group('CliOutput.rich', () {
    const o = CliOutput.rich;

    test('isRich is true', () {
      expect(o.isRich, isTrue);
    });

    test('symbols use Unicode', () {
      expect(o.ok, '✓');
      expect(o.fail, '✗');
      expect(o.retry, '↺');
      expect(o.run, '▶');
      expect(o.arrow, '→');
      expect(o.bullet, '·');
    });

    test('colour methods wrap with ANSI codes', () {
      expect(o.green('x'), '\x1B[32mx\x1B[0m');
      expect(o.red('x'), '\x1B[31mx\x1B[0m');
      expect(o.yellow('x'), '\x1B[33mx\x1B[0m');
      expect(o.dim('x'), '\x1B[2mx\x1B[0m');
      expect(o.bold('x'), '\x1B[1mx\x1B[0m');
      expect(o.cyan('x'), '\x1B[36mx\x1B[0m');
    });

    test('boxHeader returns box-drawing format', () {
      final header = o.boxHeader('HI');
      expect(header, startsWith('┌─ HI '));
      expect(header, endsWith('┐'));
    });

    test('boxRow returns │-prefixed content', () {
      expect(o.boxRow('content'), '│  content');
    });

    test('boxFooter returns └─...─┘', () {
      final footer = o.boxFooter();
      expect(footer, startsWith('└'));
      expect(footer, endsWith('┘'));
    });

    test('separator returns em-dashes', () {
      expect(o.separator(5), '─────');
    });
  });

  group('CliOutput.timestamp', () {
    test('formats UTC DateTime as HH:MM:SS using its own hour/min/sec', () {
      final dt = DateTime.parse('2026-02-11T14:32:05Z'); // UTC
      expect(CliOutput.plain.timestamp(dt), '14:32:05');
    });

    test('pads single-digit values', () {
      final dt = DateTime.utc(2026, 1, 1, 1, 2, 3);
      expect(CliOutput.plain.timestamp(dt), '01:02:03');
    });
  });

  group('CliOutput.parseTimestamp', () {
    test('parses ISO string to HH:MM:SS', () {
      expect(
        CliOutput.plain.parseTimestamp('2026-02-11T10:05:00Z'),
        '10:05:00',
      );
    });

    test('returns (none) for null', () {
      expect(CliOutput.plain.parseTimestamp(null), '(none)');
    });

    test('returns (none) for empty string', () {
      expect(CliOutput.plain.parseTimestamp(''), '(none)');
    });

    test('returns raw string for unparseable input', () {
      expect(CliOutput.plain.parseTimestamp('not-a-date'), 'not-a-date');
    });
  });

  group('CliOutput.isImportantEvent', () {
    const o = CliOutput.plain;

    test('returns true for important events', () {
      expect(o.isImportantEvent('orchestrator_run_step_start'), isTrue);
      expect(o.isImportantEvent('orchestrator_run_step_outcome'), isTrue);
      expect(o.isImportantEvent('review_decision'), isTrue);
      expect(o.isImportantEvent('git_delivery_completed'), isTrue);
      expect(o.isImportantEvent('preflight_failed'), isTrue);
      expect(o.isImportantEvent('orchestrator_run_safety_halt'), isTrue);
      expect(o.isImportantEvent('orchestrator_run_stopped'), isTrue);
      expect(o.isImportantEvent('coding_agent_started'), isTrue);
    });

    test('returns false for non-important events', () {
      expect(o.isImportantEvent('orchestrator_run_loop'), isFalse);
      expect(o.isImportantEvent('lock_heartbeat'), isFalse);
      expect(o.isImportantEvent(''), isFalse);
      expect(o.isImportantEvent('unknown_event'), isFalse);
    });
  });
}
