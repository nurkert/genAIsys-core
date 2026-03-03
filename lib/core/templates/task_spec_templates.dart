// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class TaskSpecTemplates {
  static String plan(String title) {
    return '''# Task Plan

Title: $title

## Goal
- 

## Approach
1. 

## Risks
- 

## Dependencies
- 
''';
  }

  static String spec(String title) {
    return '''# Task Spec

Title: $title

## Scope
- Define the minimal scope for this task.

## Non-Goals
- 

## Files
- 

## Steps
1. 

## Tests
- 

## Acceptance (Required)
- 
''';
  }

  static String subtasks(String title) {
    return '''# Subtasks

Parent: $title

## Subtasks
1.
2.
3.
''';
  }

  static String subtaskComplexityReview(
    String title,
    List<String> subtaskList,
  ) {
    final numbered = subtaskList
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return '''# Subtask Complexity Review

Parent: $title

## Current Subtasks
$numbered

## Instructions
For each subtask: can it be done in one focused coding step touching ≤3 files?

If ALL are well-scoped, output ONLY:
REFINED: NO_CHANGES_NEEDED

Otherwise output a revised numbered list, splitting oversized subtasks into
2-3 smaller steps. Keep well-scoped subtasks unchanged.
Output ONLY the list or NO_CHANGES_NEEDED.
''';
  }

  static String subtaskFeasibilityCheck(
    String taskLine,
    List<String> subtaskList,
  ) {
    final numbered = subtaskList
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return '''# Subtask Feasibility Check

## Task (with Acceptance Criteria)
$taskLine

## Proposed Subtasks
$numbered

## Assessment
First line: FEASIBLE or NOT_FEASIBLE
If NOT_FEASIBLE: brief explanation of what is missing.
''';
  }

  static String acSelfCheck(String requirement, String diffSummary) {
    return '''# Implementation Self-Check

## Requirement
$requirement

## Changes Made (summary)
$diffSummary

## Assessment
First line MUST be exactly: PASS or FAIL
If FAIL: one sentence explaining what is missing.
''';
  }

  static String subtaskReactiveSplit(String subtask, String rejectNote) {
    return '''# Subtask Split Request

## Rejected Subtask
$subtask

## Reviewer Feedback
$rejectNote

## Instructions
Split into 2-3 smaller subtasks touching ≤3 files each.
Start each with an action verb.
Output ONLY a numbered list.
''';
  }
}
