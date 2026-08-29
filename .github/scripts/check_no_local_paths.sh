#!/usr/bin/env bash
# Fails if a tracked file contains an absolute home directory path from a
# developer machine. Such paths leak the author's local filesystem layout into
# the public repository and are never meaningful to anyone else.
#
# Documentation and tests legitimately use placeholder user names; those are
# allowlisted below.
set -euo pipefail

PLACEHOLDERS='you|user|username|name|tester|runner|test|tmp|example'

if matches=$(git grep -InE '/(Users|home)/[A-Za-z0-9._-]+/' -- . \
    | grep -vE "/(Users|home)/($PLACEHOLDERS)/"); then
  echo "Found absolute local paths in tracked files:"
  echo "$matches"
  echo
  echo "Replace them with a placeholder (e.g. /Users/you/...) or a relative path."
  exit 1
fi

echo "No local absolute paths in tracked files."
