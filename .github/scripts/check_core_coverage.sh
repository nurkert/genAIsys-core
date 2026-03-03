#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <lcov-info> <orchestration-threshold-percent> <policy-threshold-percent>" >&2
  exit 2
fi

lcov_file="$1"
orchestration_threshold="$2"
policy_threshold="$3"

if [[ ! -f "$lcov_file" ]]; then
  echo "Coverage file not found: $lcov_file" >&2
  exit 2
fi

coverage_for_regex() {
  local regex="$1"
  awk -v regex="$regex" '
    BEGIN {
      include = 0;
      total = 0;
      hit = 0;
    }
    /^SF:/ {
      path = substr($0, 4);
      include = (path ~ regex) ? 1 : 0;
      next;
    }
    include && /^LF:/ {
      total += substr($0, 4) + 0;
      next;
    }
    include && /^LH:/ {
      hit += substr($0, 4) + 0;
      next;
    }
    END {
      if (total == 0) {
        printf "0.00 0 0\n";
      } else {
        printf "%.2f %d %d\n", (hit * 100.0) / total, hit, total;
      }
    }
  ' "$lcov_file"
}

evaluate_scope() {
  local scope_name="$1"
  local regex="$2"
  local threshold="$3"

  local data
  data="$(coverage_for_regex "$regex")"

  local percent
  local hit
  local total
  percent="$(awk '{print $1}' <<< "$data")"
  hit="$(awk '{print $2}' <<< "$data")"
  total="$(awk '{print $3}' <<< "$data")"

  echo "$scope_name coverage: ${percent}% (${hit}/${total}) [min ${threshold}%]"

  awk -v percent="$percent" -v threshold="$threshold" '
    BEGIN {
      if (percent + 0 < threshold + 0) {
        exit 1;
      }
    }
  '
}

orchestration_regex='lib/core/services/orchestrator/|lib/core/services/orchestrator_run_service\.dart|lib/core/services/orchestrator_step_service\.dart|lib/core/services/task_cycle/|lib/core/services/task_cycle_service\.dart'
policy_regex='lib/core/policy/|lib/core/security/redaction_policy\.dart|lib/core/security/redaction_service\.dart'

evaluate_scope "Orchestration" "$orchestration_regex" "$orchestration_threshold"
evaluate_scope "Policy" "$policy_regex" "$policy_threshold"

