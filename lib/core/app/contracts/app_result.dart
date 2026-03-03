// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'app_error.dart';

class AppResult<T> {
  const AppResult._({required this.data, required this.error});

  final T? data;
  final AppError? error;

  bool get ok => error == null;

  static AppResult<T> success<T>(T data) {
    return AppResult<T>._(data: data, error: null);
  }

  static AppResult<T> failure<T>(AppError error) {
    return AppResult<T>._(data: null, error: error);
  }
}
