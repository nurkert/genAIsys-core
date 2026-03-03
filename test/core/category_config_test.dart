import 'dart:io';

import 'package:test/test.dart';

import 'package:genaisys/core/config/project_config.dart';
import 'package:genaisys/core/project_layout.dart';

void main() {
  group('Category-based config parsing', () {
    test('parses reasoning_effort_by_category from providers section', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cat_reasoning_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: codex
  reasoning_effort_by_category:
    docs: low
    security: high
    core: medium
    ui: high
    default: medium
''');

      final config = ProjectConfig.load(temp.path);
      expect(config.reasoningEffortByCategory['docs'], 'low');
      expect(config.reasoningEffortByCategory['security'], 'high');
      expect(config.reasoningEffortByCategory['core'], 'medium');
      expect(config.reasoningEffortByCategory['ui'], 'high');
      expect(config.reasoningEffortByCategory['default'], 'medium');
    });

    test('rejects invalid reasoning effort values', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cat_reasoning_invalid_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
providers:
  reasoning_effort_by_category:
    docs: invalid_value
    security: HIGH
    core: Low
''');

      final config = ProjectConfig.load(temp.path);
      // 'invalid_value' should be rejected, keep default.
      expect(
        config.reasoningEffortByCategory['docs'],
        ProjectConfig.defaultReasoningEffortByCategory['docs'],
      );
      // Case-insensitive: 'HIGH' -> 'high'.
      expect(config.reasoningEffortByCategory['security'], 'high');
      // Case-insensitive: 'Low' -> 'low'.
      expect(config.reasoningEffortByCategory['core'], 'low');
    });

    test('parses agent_seconds_by_category from policies.timeouts section', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cat_timeout_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
policies:
  timeouts:
    agent_seconds: 600
    agent_seconds_by_category:
      docs: 120
      refactor: 900
      security: 720
      default: 400
''');

      final config = ProjectConfig.load(temp.path);
      expect(config.agentTimeoutByCategory['docs'], 120);
      expect(config.agentTimeoutByCategory['refactor'], 900);
      expect(config.agentTimeoutByCategory['security'], 720);
      expect(config.agentTimeoutByCategory['default'], 400);
      // Global agent_seconds should also be parsed.
      expect(config.agentTimeout, const Duration(seconds: 600));
    });

    test(
      'parses context_injection_max_tokens_by_category from pipeline section',
      () {
        final temp = Directory.systemTemp.createTempSync(
          'genaisys_cat_ctx_tokens_',
        );
        addTearDown(() => temp.deleteSync(recursive: true));

        final layout = ProjectLayout(temp.path);
        Directory(layout.genaisysDir).createSync(recursive: true);
        File(layout.configPath).writeAsStringSync('''
pipeline:
  context_injection_enabled: true
  context_injection_max_tokens: 10000
  context_injection_max_tokens_by_category:
    docs: 1500
    refactor: 15000
    core: 10000
    default: 9000
''');

        final config = ProjectConfig.load(temp.path);
        expect(config.contextInjectionMaxTokensByCategory['docs'], 1500);
        expect(config.contextInjectionMaxTokensByCategory['refactor'], 15000);
        expect(config.contextInjectionMaxTokensByCategory['core'], 10000);
        expect(config.contextInjectionMaxTokensByCategory['default'], 9000);
        // Global tokens should also be parsed.
        expect(config.pipelineContextInjectionMaxTokens, 10000);
      },
    );

    test('rejects invalid integer values in category maps', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cat_invalid_int_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
policies:
  timeouts:
    agent_seconds_by_category:
      docs: not_a_number
      refactor: -5
      core: 0
      security: 600
''');

      final config = ProjectConfig.load(temp.path);
      // 'not_a_number', -5, and 0 should be rejected (must be > 0).
      expect(
        config.agentTimeoutByCategory['docs'],
        ProjectConfig.defaultAgentTimeoutByCategory['docs'],
      );
      expect(
        config.agentTimeoutByCategory['refactor'],
        ProjectConfig.defaultAgentTimeoutByCategory['refactor'],
      );
      expect(
        config.agentTimeoutByCategory['core'],
        ProjectConfig.defaultAgentTimeoutByCategory['core'],
      );
      // Valid value should be accepted.
      expect(config.agentTimeoutByCategory['security'], 600);
    });

    test('defaults are used when no category config is provided', () {
      final temp = Directory.systemTemp.createTempSync(
        'genaisys_cat_defaults_',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      File(layout.configPath).writeAsStringSync('''
providers:
  primary: codex
''');

      final config = ProjectConfig.load(temp.path);
      expect(
        config.reasoningEffortByCategory,
        equals(ProjectConfig.defaultReasoningEffortByCategory),
      );
      expect(
        config.agentTimeoutByCategory,
        equals(ProjectConfig.defaultAgentTimeoutByCategory),
      );
      expect(
        config.contextInjectionMaxTokensByCategory,
        equals(ProjectConfig.defaultContextInjectionMaxTokensByCategory),
      );
    });

    test('section transition resets category map key', () {
      final temp = Directory.systemTemp.createTempSync('genaisys_cat_reset_');
      addTearDown(() => temp.deleteSync(recursive: true));

      final layout = ProjectLayout(temp.path);
      Directory(layout.genaisysDir).createSync(recursive: true);
      // Ensure that switching from providers to git section does not
      // leak category map state.
      File(layout.configPath).writeAsStringSync('''
providers:
  reasoning_effort_by_category:
    docs: low
git:
  base_branch: develop
''');

      final config = ProjectConfig.load(temp.path);
      expect(config.reasoningEffortByCategory['docs'], 'low');
      expect(config.gitBaseBranch, 'develop');
    });
  });

  group('Category resolver methods', () {
    test('reasoningEffortForCategory resolves known category', () {
      final config = ProjectConfig();
      expect(config.reasoningEffortForCategory('docs'), 'low');
      expect(config.reasoningEffortForCategory('security'), 'high');
      expect(config.reasoningEffortForCategory('refactor'), 'high');
      expect(config.reasoningEffortForCategory('core'), 'medium');
    });

    test('reasoningEffortForCategory falls back to default for unknown', () {
      final config = ProjectConfig();
      expect(config.reasoningEffortForCategory('unknown_category'), 'medium');
    });

    test('reasoningEffortForCategory is case-insensitive', () {
      final config = ProjectConfig();
      expect(config.reasoningEffortForCategory('DOCS'), 'low');
      expect(config.reasoningEffortForCategory('Security'), 'high');
    });

    test('agentTimeoutForCategory resolves known category', () {
      final config = ProjectConfig();
      expect(
        config.agentTimeoutForCategory('docs'),
        const Duration(seconds: 180),
      );
      expect(
        config.agentTimeoutForCategory('refactor'),
        const Duration(seconds: 480),
      );
    });

    test('agentTimeoutForCategory falls back to default for unknown', () {
      final config = ProjectConfig();
      expect(
        config.agentTimeoutForCategory('unknown_category'),
        const Duration(seconds: 360),
      );
    });

    test('contextInjectionMaxTokensForCategory resolves known category', () {
      final config = ProjectConfig();
      expect(config.contextInjectionMaxTokensForCategory('docs'), 2000);
      expect(config.contextInjectionMaxTokensForCategory('refactor'), 12000);
      expect(config.contextInjectionMaxTokensForCategory('core'), 8000);
    });

    test(
      'contextInjectionMaxTokensForCategory falls back to default for unknown',
      () {
        final config = ProjectConfig();
        expect(
          config.contextInjectionMaxTokensForCategory('unknown_category'),
          8000,
        );
      },
    );

    test('resolver uses custom map values when provided', () {
      final config = ProjectConfig(
        reasoningEffortByCategory: const {'docs': 'high', 'default': 'low'},
        agentTimeoutByCategory: const {'docs': 60, 'default': 120},
        contextInjectionMaxTokensByCategory: const {
          'docs': 500,
          'default': 1000,
        },
      );

      expect(config.reasoningEffortForCategory('docs'), 'high');
      expect(config.reasoningEffortForCategory('unknown'), 'low');
      expect(
        config.agentTimeoutForCategory('docs'),
        const Duration(seconds: 60),
      );
      expect(
        config.agentTimeoutForCategory('unknown'),
        const Duration(seconds: 120),
      );
      expect(config.contextInjectionMaxTokensForCategory('docs'), 500);
      expect(config.contextInjectionMaxTokensForCategory('unknown'), 1000);
    });
  });
}
