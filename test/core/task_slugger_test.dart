import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/core.dart';

void main() {
  test('TaskSlugger creates stable slug', () {
    expect(TaskSlugger.slug('Hello World!'), 'hello-world');
  });

  test('TaskSlugger truncates long slugs to maxSlugLength', () {
    final longTitle =
        'Add config keys for operative intelligence features '
        '(pipeline.forensic_recovery_enabled, '
        'pipeline.error_pattern_learning_enabled, '
        'pipeline.impact_context_max_files) '
        'with defaults matching current behavior';
    final slug = TaskSlugger.slug(longTitle);
    expect(slug.length, lessThanOrEqualTo(TaskSlugger.maxSlugLength));
    // Must not end with a trailing dash after truncation.
    expect(slug, isNot(endsWith('-')));
  });

  test('TaskSlugger does not truncate short slugs', () {
    expect(TaskSlugger.slug('fix broken import'), 'fix-broken-import');
  });
}
