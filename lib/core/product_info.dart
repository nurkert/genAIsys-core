// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Product identity shared by every frontend.
///
/// Lives in `lib/core/` rather than in a frontend-specific file so the CLI and
/// the desktop GUI report the same name and version without the UI reaching
/// into `lib/core/cli/`, which the layer rules forbid.
///
/// [version] is hard-coded and must match `pubspec.yaml` and
/// `tool/pubspec.cli.yaml`; `test/core/version_consistency_test.dart` enforces
/// that. Bump all three together when cutting a release.
class ProductInfo {
  const ProductInfo._();

  static const String name = 'Genaisys';
  static const String version = '0.0.4';
  static const String binaryName = 'genaisys';
  static const String tagline = 'AI-assisted software delivery orchestrator';

  /// e.g. `Genaisys v0.0.4`
  static String get versionLine => '$name v$version';
}
