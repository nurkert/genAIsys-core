// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../product_info.dart';

/// Central branding constants for all CLI-facing strings.
///
/// Every user-visible CLI string that mentions the product must reference this
/// class so that a single edit propagates everywhere. The values themselves
/// live in [ProductInfo], which the desktop GUI also reads — the UI layer must
/// not import from `lib/core/cli/`.
class CliBranding {
  const CliBranding._();

  static const String productName = ProductInfo.name;
  static const String version = ProductInfo.version;
  static const String binaryName = ProductInfo.binaryName;
  static const String tagline = ProductInfo.tagline;

  static String get versionLine => ProductInfo.versionLine;
  static String get usageLine => 'Usage: $binaryName <command> [path] [options]';
}
