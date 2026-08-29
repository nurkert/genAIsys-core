import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/policy/diff_budget_policy.dart';

void main() {
  test('DiffBudgetPolicy allows stats within budget', () {
    final policy = DiffBudgetPolicy(
      budget: DiffBudget(maxFiles: 5, maxAdditions: 100, maxDeletions: 50),
    );

    final stats = DiffStats(filesChanged: 3, additions: 80, deletions: 20);

    expect(policy.allows(stats), isTrue);
  });

  test('DiffBudgetPolicy rejects stats over budget', () {
    final policy = DiffBudgetPolicy(
      budget: DiffBudget(maxFiles: 2, maxAdditions: 10, maxDeletions: 5),
    );

    expect(
      policy.allows(DiffStats(filesChanged: 3, additions: 1, deletions: 1)),
      isFalse,
    );
    expect(
      policy.allows(DiffStats(filesChanged: 1, additions: 11, deletions: 1)),
      isFalse,
    );
    expect(
      policy.allows(DiffStats(filesChanged: 1, additions: 1, deletions: 6)),
      isFalse,
    );
  });
}
