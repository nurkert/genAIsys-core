// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;

import '../app/app.dart';
import '../app/dto/diagnostics_dto.dart';
import '../app/use_cases/diagnostics_use_cases.dart';
import '../project_layout.dart';
import '../security/redaction_service.dart';
import '../services/autopilot/autopilot_supervisor_service.dart';
import '../settings/application_settings.dart';
import '../settings/application_settings_repository.dart';
import 'cli_branding.dart';
import 'command_help_registry.dart';
import 'output/cli_output.dart';
import 'presenters/json_presenter.dart';
import 'presenters/text_presenter.dart';
import 'shared/cli_error_presenter.dart';
import 'shared/cli_follow_status_presenter.dart';
import 'shared/cli_run_log_tailer.dart';

part 'cli_runner_handlers.dart';
part 'cli_runner_utils.dart';
part 'cli_runner_help.dart';
part 'handlers/init_handler.dart';
part 'handlers/status_handler.dart';
part 'handlers/done_handler.dart';
part 'handlers/block_handler.dart';
part 'handlers/tasks_handler.dart';
part 'handlers/activate_handler.dart';
part 'handlers/deactivate_handler.dart';
part 'handlers/spec_files_handler.dart';
part 'handlers/app_settings_handler.dart';
part 'handlers/review_handler.dart';
part 'handlers/autopilot_handlers.dart';
part 'handlers/autopilot_supervisor_handlers.dart';
part 'handlers/config_validate_handler.dart';
part 'handlers/health_handler.dart';
part 'handlers/diagnostics_handler.dart';
part 'handlers/config_diff_handler.dart';
part 'handlers/hitl_handler.dart';

class CliRunner {
  CliRunner({
    GenaisysApi? api,
    AutopilotStepUseCase? autopilotStep,
    AutopilotRunUseCase? autopilotRun,
    AutopilotStatusUseCase? autopilotStatus,
    AutopilotStopUseCase? autopilotStop,
    AutopilotSupervisorService? autopilotSupervisorService,
    AutopilotSupervisorStartUseCase? autopilotSupervisorStart,
    AutopilotSupervisorStatusUseCase? autopilotSupervisorStatus,
    AutopilotSupervisorStopUseCase? autopilotSupervisorStop,
    AutopilotSupervisorRestartUseCase? autopilotSupervisorRestart,
    AutopilotSmokeUseCase? autopilotSmoke,
    AutopilotSimulationUseCase? autopilotSimulation,
    AutopilotImproveUseCase? autopilotImprove,
    AutopilotHealUseCase? autopilotHeal,
    AutopilotCandidateUseCase? autopilotCandidate,
    AutopilotPilotUseCase? autopilotPilot,
    AutopilotBranchCleanupUseCase? autopilotCleanupBranches,
    JsonPresenter? jsonPresenter,
    TextPresenter? textPresenter,
    CliOutput? cliOutput,
    ApplicationSettingsRepository? applicationSettingsRepository,
    IOSink? stdout,
    IOSink? stderr,
  }) : _cliOutput = cliOutput ?? CliOutput.auto(),
       _api = api ?? InProcessGenaisysApi(),
       _autopilotStep = autopilotStep ?? AutopilotStepUseCase(),
       _autopilotRun = autopilotRun ?? AutopilotRunUseCase(),
       _autopilotStatus = autopilotStatus ?? AutopilotStatusUseCase(),
       _autopilotStop = autopilotStop ?? AutopilotStopUseCase(),
       _autopilotSupervisorService =
           autopilotSupervisorService ?? AutopilotSupervisorService(),
       _autopilotSupervisorStart =
           autopilotSupervisorStart ??
           AutopilotSupervisorStartUseCase(service: autopilotSupervisorService),
       _autopilotSupervisorStatus =
           autopilotSupervisorStatus ??
           AutopilotSupervisorStatusUseCase(
             service: autopilotSupervisorService,
           ),
       _autopilotSupervisorStop =
           autopilotSupervisorStop ??
           AutopilotSupervisorStopUseCase(service: autopilotSupervisorService),
       _autopilotSupervisorRestart =
           autopilotSupervisorRestart ??
           AutopilotSupervisorRestartUseCase(
             service: autopilotSupervisorService,
           ),
       _autopilotSmoke = autopilotSmoke ?? AutopilotSmokeUseCase(),
       _autopilotSimulation =
           autopilotSimulation ?? AutopilotSimulationUseCase(),
       _autopilotImprove = autopilotImprove ?? AutopilotImproveUseCase(),
       _autopilotHeal = autopilotHeal ?? AutopilotHealUseCase(),
       _autopilotCandidate = autopilotCandidate ?? AutopilotCandidateUseCase(),
       _autopilotPilot = autopilotPilot ?? AutopilotPilotUseCase(),
       _autopilotCleanupBranches =
           autopilotCleanupBranches ?? AutopilotBranchCleanupUseCase(),
       _jsonPresenter = jsonPresenter ?? const JsonPresenter(),
       _textPresenter =
           textPresenter ?? TextPresenter(cliOutput ?? CliOutput.auto()),
       _applicationSettingsRepository =
           applicationSettingsRepository ?? FileApplicationSettingsRepository(),
       _stdout = _SanitizingSink(
         stdout ?? io.stdout,
         redactionService: RedactionService.shared,
       ),
       _stderr = _SanitizingSink(
         stderr ?? io.stderr,
         redactionService: RedactionService.shared,
       );

  final CliOutput _cliOutput;
  final GenaisysApi _api;
  final AutopilotStepUseCase _autopilotStep;
  final AutopilotRunUseCase _autopilotRun;
  final AutopilotStatusUseCase _autopilotStatus;
  final AutopilotStopUseCase _autopilotStop;
  final AutopilotSupervisorService _autopilotSupervisorService;
  final AutopilotSupervisorStartUseCase _autopilotSupervisorStart;
  final AutopilotSupervisorStatusUseCase _autopilotSupervisorStatus;
  final AutopilotSupervisorStopUseCase _autopilotSupervisorStop;
  final AutopilotSupervisorRestartUseCase _autopilotSupervisorRestart;
  final AutopilotSmokeUseCase _autopilotSmoke;
  final AutopilotSimulationUseCase _autopilotSimulation;
  final AutopilotImproveUseCase _autopilotImprove;
  final AutopilotHealUseCase _autopilotHeal;
  final AutopilotCandidateUseCase _autopilotCandidate;
  final AutopilotPilotUseCase _autopilotPilot;
  final AutopilotBranchCleanupUseCase _autopilotCleanupBranches;
  final JsonPresenter _jsonPresenter;
  final TextPresenter _textPresenter;
  final ApplicationSettingsRepository _applicationSettingsRepository;
  final IOSink _stdout;
  final IOSink _stderr;

  IOSink get stdout => _stdout;
  IOSink get stderr => _stderr;

  int get exitCode => io.exitCode;
  set exitCode(int value) => io.exitCode = value;

  Future<void> runAsync(List<String> args) => run(args);

  Future<void> run(List<String> args) async {
    if (args.isEmpty) {
      _printHelp();
      exitCode = 64;
      return;
    }

    final command = args.first.toLowerCase();
    final options = args.skip(1).toList();

    switch (command) {
      // ── Meta ────────────────────────────────────────────────────
      case 'version':
        stdout.writeln(CliBranding.versionLine);
        break;
      case 'help':
      case '--help':
      case '-h':
        if (options.isNotEmpty && !options.first.startsWith('-')) {
          _printCommandHelp(options.first);
        } else {
          _printHelp();
        }
        break;

      // ── Setup ───────────────────────────────────────────────────
      case 'init':
        await _handleInit(options);
        break;
      case 'status':
        await _handleStatus(options);
        break;

      // ── Tasks ───────────────────────────────────────────────────
      case 'tasks':
        await _handleTasks(options);
        break;
      case 'activate':
        await _handleActivate(options);
        break;
      case 'deactivate':
        await _handleDeactivate(options);
        break;
      case 'done':
        await _handleDone(options);
        break;
      case 'block':
        await _handleBlock(options);
        break;
      case 'review':
        await _handleReview(options);
        break;

      // ── Execution ───────────────────────────────────────────────
      case 'run':
        await _handleAutopilotRun(options);
        break;
      case 'step':
        await _handleAutopilotStep(options);
        break;
      case 'stop':
        await _handleAutopilotStop(options);
        break;
      case 'follow':
        await _handleAutopilotFollow(options);
        break;

      // ── Supervisor ──────────────────────────────────────────────
      case 'supervisor':
        await _handleAutopilotSupervisor(options);
        break;

      // ── Testing & Release ───────────────────────────────────────
      case 'smoke':
        await _handleAutopilotSmoke(options);
        break;
      case 'simulate':
        await _handleAutopilotSimulate(options);
        break;
      case 'candidate':
        await _handleAutopilotCandidate(options);
        break;
      case 'pilot':
        await _handleAutopilotPilot(options);
        break;

      // ── Maintenance ─────────────────────────────────────────────
      case 'heal':
        await _handleAutopilotHeal(options);
        break;
      case 'improve':
        await _handleAutopilotImprove(options);
        break;
      case 'cleanup':
        await _handleAutopilotCleanupBranches(options);
        break;
      case 'diagnostics':
        await _handleAutopilotDiagnostics(options);
        break;

      // ── Configuration ───────────────────────────────────────────
      case 'config':
        await _handleConfig(options);
        break;
      case 'settings':
        await _handleAppSettings(options);
        break;
      case 'health':
        await _handleHealth(options);
        break;

      // ── Scaffolding ─────────────────────────────────────────────
      case 'scaffold':
        await _handleScaffold(options);
        break;

      // ── Human-in-the-Loop ────────────────────────────────────────
      case 'hitl':
        await _handleHitl(options);
        break;

      default:
        final asJson = options.contains('--json');
        if (asJson) {
          _writeJsonError(
            code: 'unknown_command',
            message: 'Unknown command: $command',
          );
        } else {
          _stderr.writeln('Unknown command: $command');
          final suggestions = CommandHelpRegistry.suggest(command);
          if (suggestions.isNotEmpty) {
            _stderr.writeln(
              'Did you mean: ${suggestions.join(', ')}?',
            );
          }
        }
        exitCode = 64;
    }
  }
}

class _SanitizingSink implements IOSink {
  _SanitizingSink(this._inner, {required RedactionService redactionService})
    : _redactionService = redactionService;

  final IOSink _inner;
  final RedactionService _redactionService;

  @override
  Encoding encoding = utf8;

  @override
  void write(Object? obj) {
    _inner.write(_sanitize(obj));
  }

  @override
  void writeln([Object? obj = '']) {
    _inner.writeln(_sanitize(obj));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    final sanitized = objects
        .map((item) => _sanitize(item))
        .toList(growable: false);
    _inner.writeAll(sanitized, separator);
  }

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(_sanitize(error), stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  Future<void> flush() => _inner.flush();

  @override
  Future<void> close() => _inner.close();

  @override
  Future<void> get done => _inner.done;

  String _sanitize(Object? value) {
    final text = value?.toString() ?? '';
    return _redactionService.sanitizeText(text).value;
  }
}
