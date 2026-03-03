// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import '../project_layout.dart';
import 'schema_validation/config_schema_validator.dart';
import 'schema_validation/state_schema_validator.dart';
import 'schema_validation/tasks_schema_validator.dart';

/// Thin facade that delegates to domain-specific schema validators.
class StepSchemaValidationService {
  final _stateValidator = StateSchemaValidator();
  final _configValidator = ConfigSchemaValidator();
  final _tasksValidator = TasksSchemaValidator();

  void validate(String projectRoot) {
    validateLayout(ProjectLayout(projectRoot));
  }

  void validateLayout(ProjectLayout layout) {
    _stateValidator.validate(layout.statePath);
    _configValidator.validate(layout.configPath);
    _tasksValidator.validate(layout.tasksPath);
  }
}
