const tasksFixtureBasic = '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha
''';

const tasksFixtureTwoSections = '''# Tasks

## Backlog
- [ ] [P1] [CORE] Alpha

## Doing
- [ ] [P2] [UI] Beta
''';

const configFixtureMinimal = '''policies:
  safe_write:
    enabled: true
  shell_allowlist:
    - "flutter test"
  diff_budget:
    max_files: 10
    max_additions: 100
    max_deletions: 80
''';

List<String> runLogFixture({String event = 'orchestrator_run_start'}) {
  return [
    '{"timestamp":"2025-01-01T00:00:00Z","event":"$event","message":"Autopilot run started","data":{"root":"."}}',
  ];
}
