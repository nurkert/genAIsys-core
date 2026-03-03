// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'telemetry_dto.dart';

class AppRunLogPageDto {
  const AppRunLogPageDto({required this.events, this.nextBeforeOffset});

  /// Log entries ordered from newest to oldest.
  ///
  /// This ordering matches typical log viewers where the newest event is shown
  /// at the bottom when used with `ListView(reverse: true)`.
  final List<AppRunLogEventDto> events;

  /// Byte offset (exclusive) cursor for pagination. When non-null, request the
  /// next page by passing this value as `beforeOffset`.
  ///
  /// When null, there are no older entries available.
  final int? nextBeforeOffset;
}
