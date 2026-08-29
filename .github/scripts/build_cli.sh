#!/usr/bin/env bash
# Compiles the standalone `genaisys` CLI binary to the path given as $1.
#
# The CLI is built in a scratch copy of bin/ and lib/ against
# tool/pubspec.cli.yaml rather than the root pubspec. The root pubspec pulls
# Flutter, and one of its transitive dependencies (objective_c, via
# path_provider_foundation) uses build hooks, which `dart compile exe` does not
# support. lib/core/ has zero Flutter imports, so the reduced dependency set
# produces an identical binary — and the GUI build in the same job keeps its
# unmodified pubspec.
set -euo pipefail

# The output name is resolved against the repository root rather than taken as a
# raw path: on Windows runners $GITHUB_WORKSPACE is a backslash path that bash
# cannot use.
name="${1:?usage: build_cli.sh <output-file-name>}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output="$repo/$name"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cp -R "$repo/bin" "$repo/lib" "$workdir/"
cp "$repo/tool/pubspec.cli.yaml" "$workdir/pubspec.yaml"

cd "$workdir"
dart pub get
dart compile exe bin/genaisys_cli.dart -o "$output"

"$output" version
