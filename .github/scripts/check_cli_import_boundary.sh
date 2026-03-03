#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for boundary checks."
  exit 2
fi

mapfile -t MATCHES < <(
  rg -n "import\\s+['\"](\\.\\./cli/|package:genaisys/core/cli/)" \
    lib/core \
    --glob '!lib/core/cli/**'
)

VIOLATIONS=()
for match in "${MATCHES[@]}"; do
  VIOLATIONS+=("$match")
done

if ((${#VIOLATIONS[@]} > 0)); then
  echo "CLI import boundary violation(s) found:"
  printf '%s\n' "${VIOLATIONS[@]}"
  exit 1
fi

echo "CLI import boundary check passed."
