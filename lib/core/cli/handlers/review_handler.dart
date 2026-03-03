// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

part of '../cli_runner.dart';

extension _CliRunnerReviewHandler on CliRunner {
  Future<void> _handleReview(List<String> options) async {
    final asJson = options.contains('--json');
    if (options.isEmpty || options.first.startsWith('-')) {
      if (asJson) {
        _writeJsonError(
          code: 'missing_subcommand',
          message: 'Missing subcommand. Use: review approve|reject [path]',
        );
      } else {
        this.stderr.writeln(
          'Missing subcommand. Use: review approve|reject [path]',
        );
      }
      exitCode = 64;
      return;
    }

    final decision = options.first.toLowerCase();
    final note =
        _readOptionValue(options, '--note') ??
        _readOptionValue(options, '--reason');

    if (decision == 'status') {
      final path = _extractPath(options.sublist(1));
      final root = _resolveRoot(path);
      final result = await _api.getReviewStatus(root);
      final data = _requireData(result, asJson: asJson);
      if (data == null) {
        return;
      }
      if (asJson) {
        _jsonPresenter.writeReviewStatus(this.stdout, data);
      } else {
        _textPresenter.writeReviewStatus(this.stdout, data);
      }
      return;
    }

    if (decision == 'clear') {
      final path = _extractPath(options.sublist(1));
      final root = _resolveRoot(path);
      final result = await _api.clearReview(root, note: note);
      final data = _requireData(result, asJson: asJson);
      if (data == null) {
        return;
      }
      if (asJson) {
        _jsonPresenter.writeReviewClear(this.stdout, data);
      } else {
        _textPresenter.writeReviewClear(this.stdout, data);
      }
      return;
    }

    if (decision != 'approve' && decision != 'reject') {
      if (asJson) {
        _writeJsonError(
          code: 'unknown_decision',
          message: 'Unknown review decision: $decision',
        );
      } else {
        this.stderr.writeln('Unknown review decision: $decision');
      }
      exitCode = 64;
      return;
    }

    final path = _extractPath(options.sublist(1));
    final root = _resolveRoot(path);

    final AppResult<ReviewDecisionDto> result = decision == 'approve'
        ? await _api.approveReview(root, note: note)
        : await _api.rejectReview(root, note: note);

    final data = _requireData(result, asJson: asJson);
    if (data == null) {
      return;
    }

    if (asJson) {
      _jsonPresenter.writeReviewDecision(this.stdout, data);
      return;
    }
    _textPresenter.writeReviewDecision(this.stdout, data, decision: decision);
  }
}
