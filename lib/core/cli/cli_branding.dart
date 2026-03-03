// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

/// Central branding constants for all CLI-facing strings.
///
/// The product name will change later.  Every user-visible string
/// that mentions the product must reference this class so that a
/// single edit propagates everywhere.
class CliBranding {
  const CliBranding._();

  static const String productName = 'Genaisys';
  static const String version = '0.0.4';
  static const String binaryName = 'genaisys';
  static const String tagline = 'AI-assisted software delivery orchestrator';

  static String get versionLine => '$productName v$version';
  static String get usageLine => 'Usage: $binaryName <command> [path] [options]';
}
