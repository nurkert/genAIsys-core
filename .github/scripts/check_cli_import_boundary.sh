#!/usr/bin/env bash
# Enforces the one-way dependency rule: nothing under lib/core/ may import from
# lib/core/cli/. The CLI is an adapter over the core, never the other way round.
#
# Uses `git grep` rather than ripgrep: the CI determinism rule forbids assuming
# host-installed tools, and the previous ripgrep dependency made this job fail
# on runners that do not ship it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# lib/core/legacy/ holds the documented back-compat GUI-over-CLI bridge and is
# exempt by design; test/core/architecture_imports_test.dart carves out the same
# exemption. Keep both guards in agreement.
if violations=$(git grep -nE "import[[:space:]]+['\"](\.\./cli/|package:genaisys/core/cli/)" \
    -- lib/core ':(exclude)lib/core/cli' ':(exclude)lib/core/legacy'); then
  echo "CLI import boundary violation(s) found:"
  echo "$violations"
  exit 1
fi

echo "CLI import boundary check passed."
