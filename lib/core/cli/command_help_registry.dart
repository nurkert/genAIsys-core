// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:math' show min;

import 'cli_branding.dart';

/// Metadata for a single CLI command (used by the help system).
class CommandHelp {
  const CommandHelp({
    required this.name,
    required this.summary,
    required this.usage,
    this.description,
    this.options = const [],
    this.examples = const [],
    this.seeAlso = const [],
  });

  final String name;
  final String summary;
  final String usage;
  final String? description;
  final List<CommandOption> options;
  final List<CommandExample> examples;
  final List<String> seeAlso;
}

/// A single flag/option for a command.
class CommandOption {
  const CommandOption({
    required this.flag,
    required this.description,
    this.defaultValue,
  });

  final String flag;
  final String description;
  final String? defaultValue;
}

/// A usage example for a command.
class CommandExample {
  const CommandExample({required this.command, required this.description});

  final String command;
  final String description;
}

/// Static registry of every CLI command with help metadata.
///
/// [CommandHelpRegistry.commands] is the single source of truth for the
/// global help screen and per-command help output.
class CommandHelpRegistry {
  const CommandHelpRegistry._();

  /// Command groups for the global help screen.
  static const List<(String, List<String>)> groups = [
    ('Meta', ['help', 'version']),
    ('Setup', ['init', 'status']),
    ('Tasks', ['tasks', 'activate', 'deactivate', 'done', 'block', 'review']),
    ('Execution', ['do', 'run', 'step', 'stop', 'follow']),
    ('Supervisor', ['supervisor']),
    (
      'Testing & Release',
      ['smoke', 'simulate', 'candidate', 'pilot'],
    ),
    ('Maintenance', ['heal', 'improve', 'cleanup', 'diagnostics']),
    ('Configuration', ['config', 'settings', 'health']),
    ('Scaffolding', ['scaffold']),
  ];

  // ── command registry ──────────────────────────────────────────────

  static final List<CommandHelp> commands = _buildCommands();

  /// Lookup a command by exact name, or return `null`.
  static CommandHelp? lookup(String name) {
    final lower = name.toLowerCase();
    for (final cmd in commands) {
      if (cmd.name == lower) return cmd;
    }
    return null;
  }

  /// Suggest the closest command name(s) for a mistyped input.
  static List<String> suggest(String input, {int maxDistance = 3}) {
    final lower = input.toLowerCase();
    final scored = <(int, String)>[];
    for (final cmd in commands) {
      final d = _levenshtein(lower, cmd.name);
      if (d <= maxDistance) {
        scored.add((d, cmd.name));
      }
    }
    scored.sort((a, b) => a.$1.compareTo(b.$1));
    return scored.map((e) => e.$2).toList();
  }

  // ── private helpers ───────────────────────────────────────────────

  static String get _bin => CliBranding.binaryName;

  static List<CommandHelp> _buildCommands() {
    return [
      // ── Meta ──────────────────────────────────────────────────────
      CommandHelp(
        name: 'help',
        summary: 'Show help for a command',
        usage: '$_bin help [command]',
        description: 'Without arguments, shows the global help screen.\n'
            'With a command name, shows detailed help for that command.',
        examples: [
          CommandExample(
            command: '$_bin help',
            description: 'Show global help',
          ),
          CommandExample(
            command: '$_bin help run',
            description: 'Show detailed help for the run command',
          ),
        ],
      ),
      CommandHelp(
        name: 'version',
        summary: 'Show version info',
        usage: '$_bin version',
      ),

      // ── Setup ─────────────────────────────────────────────────────
      CommandHelp(
        name: 'init',
        summary: 'Initialize project in target directory',
        usage: '$_bin init [path] [options]',
        description:
            'Creates the .genaisys directory structure with default\n'
            'VISION.md, RULES.md, TASKS.md, and STATE.json files.',
        options: [
          const CommandOption(flag: '--overwrite', description: 'Overwrite existing files'),
          const CommandOption(flag: '--scan', description: 'Scan project and generate AI content'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(command: '$_bin init .', description: 'Initialize current directory'),
          CommandExample(
            command: '$_bin init ~/my-project --overwrite',
            description: 'Re-initialize with fresh templates',
          ),
        ],
        seeAlso: ['status', 'scaffold'],
      ),
      CommandHelp(
        name: 'status',
        summary: 'Show project, task, and autopilot status',
        usage: '$_bin status [path] [options]',
        description: 'Displays a combined dashboard with project state,\n'
            'active task, review status, health checks, and autopilot\n'
            'status if running.',
        options: [
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(command: '$_bin status .', description: 'Show status for current directory'),
        ],
        seeAlso: ['tasks', 'health'],
      ),

      // ── Tasks ─────────────────────────────────────────────────────
      CommandHelp(
        name: 'tasks',
        summary: 'List and filter tasks',
        usage: '$_bin tasks [path] [options]',
        options: [
          const CommandOption(flag: '--open', description: 'Show only open tasks'),
          const CommandOption(flag: '--done', description: 'Show only done tasks'),
          const CommandOption(flag: '--blocked', description: 'Show only blocked tasks'),
          const CommandOption(flag: '--active', description: 'Show only active task'),
          const CommandOption(flag: '--show-ids', description: 'Include task IDs'),
          const CommandOption(flag: '--sort-priority', description: 'Sort P1 first'),
          const CommandOption(flag: '--section <name>', description: 'Filter by section title'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(command: '$_bin tasks . --open', description: 'List open tasks'),
          CommandExample(
            command: '$_bin tasks . --blocked --show-ids',
            description: 'List blocked tasks with IDs',
          ),
        ],
        seeAlso: ['activate', 'status'],
      ),
      CommandHelp(
        name: 'activate',
        summary: 'Activate a task (next by priority, or by id/title)',
        usage: '$_bin activate [path] [options]',
        description: 'Without --id or --title, activates the next open task\n'
            'by priority order. With --id or --title, activates a\n'
            'specific task.',
        options: [
          const CommandOption(flag: '--id <id>', description: 'Activate task by ID'),
          const CommandOption(flag: '--title <text>', description: 'Activate by exact title'),
          const CommandOption(flag: '--section <name>', description: 'Limit to section (when auto-selecting)'),
          const CommandOption(flag: '--show-ids', description: 'Include task ID in output'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(
            command: '$_bin activate .',
            description: 'Activate next open task',
          ),
          CommandExample(
            command: '$_bin activate . --id abc123',
            description: 'Activate specific task',
          ),
        ],
        seeAlso: ['deactivate', 'tasks', 'done'],
      ),
      CommandHelp(
        name: 'deactivate',
        summary: 'Clear the active task',
        usage: '$_bin deactivate [path] [options]',
        options: [
          const CommandOption(
            flag: '--keep-review',
            description: 'Do not clear review status',
          ),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['activate'],
      ),
      CommandHelp(
        name: 'done',
        summary: 'Mark active task as done',
        usage: '$_bin done [path] [options]',
        options: [
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['activate', 'block'],
      ),
      CommandHelp(
        name: 'block',
        summary: 'Block active task',
        usage: '$_bin block [path] [options]',
        options: [
          const CommandOption(flag: '--reason <text>', description: 'Reason for blocking'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['activate', 'done'],
      ),
      CommandHelp(
        name: 'review',
        summary: 'Record review decision',
        usage: '$_bin review approve|reject|status|clear [path] [options]',
        description: 'Manage the review status for the active task.',
        options: [
          const CommandOption(flag: '--note <text>', description: 'Attach a note to the decision'),
          const CommandOption(flag: '--reason <text>', description: 'Alias for --note'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(
            command: '$_bin review approve . --note "LGTM"',
            description: 'Approve with a note',
          ),
          CommandExample(
            command: '$_bin review reject . --reason "Missing tests"',
            description: 'Reject with reason',
          ),
          CommandExample(
            command: '$_bin review status .',
            description: 'Check current review status',
          ),
        ],
        seeAlso: ['done', 'activate'],
      ),

      // ── Execution ─────────────────────────────────────────────────
      CommandHelp(
        name: 'do',
        summary: 'One-shot ad-hoc task from prompt',
        usage: '$_bin do "<prompt>" [path] [options]',
        description: 'Creates a temporary task from the prompt, runs one\n'
            'orchestrated step (code + review + delivery), and marks\n'
            'it done on success.',
        options: [
          const CommandOption(flag: '--test-summary <text>', description: 'Test summary for agent context'),
          const CommandOption(flag: '--overwrite', description: 'Overwrite existing spec files'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(
            command: '$_bin do "Fix the login bug" .',
            description: 'Run ad-hoc task',
          ),
        ],
        seeAlso: ['step', 'run'],
      ),
      CommandHelp(
        name: 'run',
        summary: 'Start continuous autopilot',
        usage: '$_bin run [path] [options]',
        description: 'Runs the autopilot loop continuously, executing\n'
            'orchestrated steps until stopped or idle.',
        options: [
          const CommandOption(flag: '--prompt <text>', description: 'Override default agent prompt'),
          const CommandOption(flag: '--test-summary <text>', description: 'Test summary for agent context'),
          const CommandOption(flag: '--min-open <n>', description: 'Minimum open tasks before planning'),
          const CommandOption(flag: '--max-plan-add <n>', description: 'Maximum tasks to add during planning'),
          const CommandOption(flag: '--step-sleep <s>', description: 'Seconds between steps'),
          const CommandOption(flag: '--idle-sleep <s>', description: 'Seconds to wait when idle'),
          const CommandOption(flag: '--max-steps <n>', description: 'Maximum steps before stopping'),
          const CommandOption(flag: '--stop-when-idle', description: 'Stop when no tasks available'),
          const CommandOption(flag: '--max-failures <n>', description: 'Maximum consecutive failures'),
          const CommandOption(flag: '--max-task-retries <n>', description: 'Maximum retries per task'),
          const CommandOption(flag: '--override-safety', description: 'Override safety checks'),
          const CommandOption(flag: '--overwrite', description: 'Overwrite existing spec files'),
          const CommandOption(flag: '--quiet', description: 'Suppress run log tailing'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(command: '$_bin run .', description: 'Run with defaults'),
          CommandExample(
            command: '$_bin run . --max-steps 10',
            description: 'Run at most 10 steps',
          ),
          CommandExample(
            command: '$_bin run . --stop-when-idle --quiet',
            description: 'Run quietly, stop when idle',
          ),
        ],
        seeAlso: ['step', 'stop', 'follow'],
      ),
      CommandHelp(
        name: 'step',
        summary: 'Run a single orchestrated step',
        usage: '$_bin step [path] [options]',
        description: 'Executes one autopilot step: activate task, run agent,\n'
            'review, and deliver.',
        options: [
          const CommandOption(flag: '--prompt <text>', description: 'Override default agent prompt'),
          const CommandOption(flag: '--test-summary <text>', description: 'Test summary for agent context'),
          const CommandOption(flag: '--min-open <n>', description: 'Minimum open tasks before planning'),
          const CommandOption(flag: '--max-plan-add <n>', description: 'Maximum tasks to add during planning'),
          const CommandOption(flag: '--overwrite', description: 'Overwrite existing spec files'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(command: '$_bin step .', description: 'Run one step'),
        ],
        seeAlso: ['run', 'stop'],
      ),
      CommandHelp(
        name: 'stop',
        summary: 'Signal autopilot to stop',
        usage: '$_bin stop [path] [options]',
        options: [
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['run', 'follow'],
      ),
      CommandHelp(
        name: 'follow',
        summary: 'Tail autopilot run log and status',
        usage: '$_bin follow [path] [options]',
        options: [
          const CommandOption(
            flag: '--status-interval <s>',
            description: 'Seconds between status polls',
            defaultValue: '5',
          ),
        ],
        seeAlso: ['run', 'stop'],
      ),

      // ── Supervisor ────────────────────────────────────────────────
      CommandHelp(
        name: 'supervisor',
        summary: 'Manage the autopilot supervisor process',
        usage: '$_bin supervisor start|status|stop|restart [path] [options]',
        description: 'The supervisor wraps the autopilot run loop with\n'
            'automatic restart, throughput monitoring, and low-signal\n'
            'detection.',
        options: [
          const CommandOption(
            flag: '--profile <name>',
            description: 'Supervisor profile',
            defaultValue: 'overnight',
          ),
          const CommandOption(flag: '--prompt <text>', description: 'Override default agent prompt'),
          const CommandOption(flag: '--reason <text>', description: 'Start/stop reason for audit'),
          const CommandOption(flag: '--max-restarts <n>', description: 'Maximum restart attempts'),
          const CommandOption(flag: '--restart-backoff-base <s>', description: 'Base backoff seconds'),
          const CommandOption(flag: '--restart-backoff-max <s>', description: 'Maximum backoff seconds'),
          const CommandOption(flag: '--low-signal-limit <n>', description: 'Low-signal streak limit'),
          const CommandOption(
            flag: '--throughput-window-minutes <n>',
            description: 'Throughput window size',
          ),
          const CommandOption(flag: '--throughput-max-steps <n>', description: 'Max steps in window'),
          const CommandOption(flag: '--throughput-max-rejects <n>', description: 'Max rejects in window'),
          const CommandOption(
            flag: '--throughput-max-high-retries <n>',
            description: 'Max high-retry tasks in window',
          ),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(
            command: '$_bin supervisor start . --profile overnight',
            description: 'Start with overnight profile',
          ),
          CommandExample(
            command: '$_bin supervisor status .',
            description: 'Check supervisor status',
          ),
          CommandExample(
            command: '$_bin supervisor stop . --reason "maintenance"',
            description: 'Stop with reason',
          ),
        ],
        seeAlso: ['run', 'stop'],
      ),

      // ── Testing & Release ─────────────────────────────────────────
      CommandHelp(
        name: 'smoke',
        summary: 'Run end-to-end smoke check',
        usage: '$_bin smoke [options]',
        options: [
          const CommandOption(flag: '--cleanup', description: 'Remove temporary project after check'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['simulate', 'candidate'],
      ),
      CommandHelp(
        name: 'simulate',
        summary: 'Simulate one step in an isolated workspace',
        usage: '$_bin simulate [path] [options]',
        description: 'Runs a full step simulation in a temporary copy of\n'
            'the project. No changes are made to the original.',
        options: [
          const CommandOption(flag: '--prompt <text>', description: 'Override default agent prompt'),
          const CommandOption(flag: '--test-summary <text>', description: 'Test summary for agent context'),
          const CommandOption(flag: '--min-open <n>', description: 'Minimum open tasks before planning'),
          const CommandOption(flag: '--max-plan-add <n>', description: 'Maximum tasks to add during planning'),
          const CommandOption(flag: '--overwrite', description: 'Overwrite existing spec files'),
          const CommandOption(flag: '--show-patch', description: 'Include full diff patch in output'),
          const CommandOption(flag: '--keep-workspace', description: 'Keep temporary workspace after simulation'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['step', 'smoke'],
      ),
      CommandHelp(
        name: 'candidate',
        summary: 'Run release-candidate gate checks',
        usage: '$_bin candidate [path] [options]',
        options: [
          const CommandOption(flag: '--skip-suites', description: 'Skip test suite execution'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['pilot'],
      ),
      CommandHelp(
        name: 'pilot',
        summary: 'Run a time-boxed autopilot pilot',
        usage: '$_bin pilot [path] [options]',
        description: 'Runs autopilot on an isolated branch for a fixed\n'
            'duration to validate stability before full deployment.',
        options: [
          const CommandOption(
            flag: '--duration <2h|30m|120s>',
            description: 'Time limit',
            defaultValue: '2h',
          ),
          const CommandOption(
            flag: '--max-cycles <n>',
            description: 'Maximum cycles',
            defaultValue: '120',
          ),
          const CommandOption(flag: '--branch <name>', description: 'Branch to use'),
          const CommandOption(flag: '--prompt <text>', description: 'Override default agent prompt'),
          const CommandOption(flag: '--skip-candidate', description: 'Skip candidate gate check'),
          const CommandOption(
            flag: '--auto-fix-format-drift',
            description: 'Auto-fix format drift',
          ),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['candidate', 'run'],
      ),

      // ── Maintenance ───────────────────────────────────────────────
      CommandHelp(
        name: 'heal',
        summary: 'Recover from an autopilot incident',
        usage: '$_bin heal [path] [options]',
        description: 'Creates an incident bundle, resets state, and\n'
            'optionally runs a recovery step.',
        options: [
          const CommandOption(flag: '--reason <code>', description: 'Incident reason code'),
          const CommandOption(flag: '--detail <text>', description: 'Additional detail'),
          const CommandOption(flag: '--prompt <text>', description: 'Recovery prompt'),
          const CommandOption(flag: '--min-open <n>', description: 'Minimum open tasks before planning'),
          const CommandOption(flag: '--max-plan-add <n>', description: 'Maximum tasks to add during planning'),
          const CommandOption(flag: '--max-task-retries <n>', description: 'Maximum retries per task'),
          const CommandOption(flag: '--overwrite', description: 'Overwrite existing spec files'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['diagnostics', 'run'],
      ),
      CommandHelp(
        name: 'improve',
        summary: 'Run self-improvement cycle',
        usage: '$_bin improve [path] [options]',
        description: 'Executes meta-analysis, evaluation, and self-tuning\n'
            'passes to improve orchestrator performance.',
        options: [
          const CommandOption(flag: '--no-meta', description: 'Skip meta-analysis'),
          const CommandOption(flag: '--no-eval', description: 'Skip evaluation'),
          const CommandOption(flag: '--no-tune', description: 'Skip self-tuning'),
          const CommandOption(flag: '--keep-workspaces', description: 'Keep temporary workspaces'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['heal', 'diagnostics'],
      ),
      CommandHelp(
        name: 'cleanup',
        summary: 'Delete merged task branches',
        usage: '$_bin cleanup [path] [options]',
        description: 'Removes local (and optionally remote) branches that\n'
            'have been fully merged into the base branch.',
        options: [
          const CommandOption(
            flag: '--base <branch>',
            description: 'Base branch for merge check',
          ),
          const CommandOption(flag: '--remote <name>', description: 'Remote name'),
          const CommandOption(flag: '--include-remote', description: 'Also delete remote branches'),
          const CommandOption(flag: '--dry-run', description: 'Show what would be deleted'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(
            command: '$_bin cleanup . --dry-run',
            description: 'Preview which branches would be deleted',
          ),
        ],
        seeAlso: ['run'],
      ),
      CommandHelp(
        name: 'diagnostics',
        summary: 'Show detailed diagnostic information',
        usage: '$_bin diagnostics [path] [options]',
        options: [
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['health', 'status'],
      ),

      // ── Configuration ─────────────────────────────────────────────
      CommandHelp(
        name: 'config',
        summary: 'Validate or diff project configuration',
        usage: '$_bin config validate|diff [path] [options]',
        options: [
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['settings', 'health'],
      ),
      CommandHelp(
        name: 'settings',
        summary: 'Manage global application settings',
        usage: '$_bin settings [show|set|reset] [options]',
        options: [
          const CommandOption(flag: '--theme <mode>', description: 'Color theme'),
          const CommandOption(flag: '--language <code>', description: 'UI language'),
          const CommandOption(flag: '--notifications <bool>', description: 'Enable notifications'),
          const CommandOption(flag: '--autopilot <bool>', description: 'Enable autopilot panel'),
          const CommandOption(flag: '--telemetry <bool>', description: 'Enable telemetry'),
          const CommandOption(flag: '--strict-secrets <bool>', description: 'Strict secrets mode'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(command: '$_bin settings show', description: 'Show current settings'),
          CommandExample(
            command: '$_bin settings set --theme dark',
            description: 'Set dark theme',
          ),
        ],
        seeAlso: ['config'],
      ),
      CommandHelp(
        name: 'health',
        summary: 'Run preflight and health checks',
        usage: '$_bin health [path] [options]',
        options: [
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        seeAlso: ['status', 'diagnostics'],
      ),

      // ── Scaffolding ───────────────────────────────────────────────
      CommandHelp(
        name: 'scaffold',
        summary: 'Create spec, plan, or subtask files',
        usage: '$_bin scaffold spec|plan|subtasks [path] [options]',
        description: 'Generates template files for the active task.',
        options: [
          const CommandOption(flag: '--overwrite', description: 'Overwrite existing files'),
          const CommandOption(flag: '--json', description: 'Machine-readable JSON output'),
        ],
        examples: [
          CommandExample(
            command: '$_bin scaffold spec .',
            description: 'Create spec file for active task',
          ),
          CommandExample(
            command: '$_bin scaffold plan . --overwrite',
            description: 'Regenerate plan file',
          ),
        ],
        seeAlso: ['activate', 'init'],
      ),
    ];
  }

  /// Levenshtein edit distance between two strings.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final la = a.length;
    final lb = b.length;
    var prev = List<int>.generate(lb + 1, (i) => i);
    var curr = List<int>.filled(lb + 1, 0);

    for (var i = 1; i <= la; i++) {
      curr[0] = i;
      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = min(
          min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[lb];
  }
}
