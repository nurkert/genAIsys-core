// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of 'cli_runner.dart';

extension _CliRunnerHelp on CliRunner {
  void _printHelp() {
    final out = this.stdout;
    out.writeln(
      '${CliBranding.versionLine} \u2014 ${CliBranding.tagline}',
    );
    out.writeln('');
    out.writeln(CliBranding.usageLine);
    out.writeln('');

    for (final (groupName, commandNames) in CommandHelpRegistry.groups) {
      out.writeln(groupName);
      for (final name in commandNames) {
        final cmd = CommandHelpRegistry.lookup(name);
        if (cmd == null) continue;
        out.writeln('  ${name.padRight(14)} ${cmd.summary}');
      }
      out.writeln('');
    }

    out.writeln(
      "Run '${CliBranding.binaryName} help <command>' for detailed help on any command.",
    );
  }

  void _printCommandHelp(String command) {
    final cmd = CommandHelpRegistry.lookup(command);
    if (cmd == null) {
      this.stderr.writeln('Unknown command: $command');
      final suggestions = CommandHelpRegistry.suggest(command);
      if (suggestions.isNotEmpty) {
        this.stderr.writeln(
          'Did you mean: ${suggestions.join(', ')}?',
        );
      }
      exitCode = 64;
      return;
    }

    final out = this.stdout;
    out.writeln(
      '${CliBranding.binaryName} ${cmd.name} \u2014 ${cmd.summary}',
    );
    out.writeln('');
    out.writeln('Usage: ${cmd.usage}');

    if (cmd.description != null) {
      out.writeln('');
      out.writeln('  ${cmd.description!.replaceAll('\n', '\n  ')}');
    }

    if (cmd.options.isNotEmpty) {
      out.writeln('');
      out.writeln('Options:');
      // Compute column width from the longest flag string.
      var maxFlagLen = 0;
      for (final opt in cmd.options) {
        if (opt.flag.length > maxFlagLen) maxFlagLen = opt.flag.length;
      }
      final padWidth = maxFlagLen + 4; // 2 indent + 2 gap
      for (final opt in cmd.options) {
        final defaultSuffix =
            opt.defaultValue != null ? ' (default: ${opt.defaultValue})' : '';
        out.writeln(
          '  ${opt.flag.padRight(padWidth)}${opt.description}$defaultSuffix',
        );
      }
    }

    if (cmd.examples.isNotEmpty) {
      out.writeln('');
      out.writeln('Examples:');
      for (final ex in cmd.examples) {
        out.writeln('  ${ex.command}');
        out.writeln('      ${ex.description}');
      }
    }

    if (cmd.seeAlso.isNotEmpty) {
      out.writeln('');
      out.writeln('See also: ${cmd.seeAlso.join(', ')}');
    }
  }
}
