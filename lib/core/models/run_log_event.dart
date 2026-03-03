// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class RunLogEvent {
  RunLogEvent({
    required this.timestamp,
    this.eventId,
    this.correlationId,
    required this.event,
    this.message,
    this.correlation,
    this.data,
  });

  final String? timestamp;
  final String? eventId;
  final String? correlationId;
  final String event;
  final String? message;
  final Map<String, Object?>? correlation;
  final Map<String, Object?>? data;
}
