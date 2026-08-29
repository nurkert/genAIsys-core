[Home](../README.md) > [Contributing](README.md) > Releasing

# Releasing

Genaisys ships the desktop GUI and the CLI together. A release is cut by pushing a version
tag; GitHub Actions builds every platform and publishes the artifacts.

---

## What a release contains

| Artifact | Platform | Contents |
|---|---|---|
| `genaisys_<version>_amd64.deb` | Linux | GUI in `/opt/genaisys`, `genaisys` CLI and `genaisys-gui` on `PATH`, desktop entry, hicolor icons |
| `genaisys-linux-x64.tar.gz` | Linux | Portable GUI bundle |
| `genaisys-cli-linux-x64` | Linux | Standalone CLI binary |
| `genaisys-macos-arm64.zip` | macOS | `genaisys.app` (unsigned) |
| `genaisys-cli-macos-arm64` | macOS | Standalone CLI binary |
| `genaisys-windows-x64.zip` | Windows | GUI bundle |
| `genaisys-cli-windows-x64.exe` | Windows | Standalone CLI binary |
| `SHA256SUMS` | — | Checksums for every artifact |

---

## Cutting a release

1. **Land all work** on `main` with a green pipeline.
2. **Bump the version** in `pubspec.yaml`. The release workflow refuses to build if the tag
   does not match this value exactly — that mismatch is a hard failure, not a warning.
3. **Update `CHANGELOG.md`** — move the relevant `[Unreleased]` entries under the new version.
4. **Tag and push**:
   ```bash
   git tag v0.0.5
   git push origin v0.0.5
   ```
5. The `Release` workflow builds Linux, macOS, and Windows in parallel, then publishes a
   GitHub Release with generated notes, install instructions, and checksums.

To verify the build without publishing, run the workflow manually
(`Actions → Release → Run workflow`). The publish step is skipped for non-tag runs.

---

## How the CLI binary is built

`dart compile exe` cannot build against the root `pubspec.yaml`: Flutter pulls in
`objective_c` (via `path_provider_foundation`), which uses build hooks that
`dart compile exe` does not support.

`.github/scripts/build_cli.sh` therefore compiles the CLI in a scratch copy of `bin/` and
`lib/` against `tool/pubspec.cli.yaml`, a Flutter-free dependency set. This is sound because
`lib/core/` has zero Flutter imports — a boundary enforced by CI.

Two consequences for contributors:

- When you add a **non-Flutter** dependency used by `lib/core/`, add it to
  `tool/pubspec.cli.yaml` as well, or the CLI build breaks.
- `tool/pubspec.cli.yaml` and `CliBranding.version` must carry the same version as
  `pubspec.yaml`. `test/core/version_consistency_test.dart` enforces this.

---

## The Flutter version is pinned

Both workflows pin `FLUTTER_VERSION` instead of tracking `channel: stable`.

`stable` floats. Combined with `dart analyze --fatal-infos`, a new SDK's new lints turn CI red
without anyone changing a line of code — and release artifacts would be built by whichever SDK
happened to be current that day. Neither is acceptable under the CI determinism rule.

**To bump the SDK**, in its own delivery:

1. Upgrade locally (`flutter upgrade`) and note the exact version.
2. `flutter pub get && dart analyze --fatal-infos --fatal-warnings .` — new lints usually appear
   here; fix them.
3. `flutter test` in full, and `flutter build <platform> --release` for at least one desktop
   target. A dependency can compile against one SDK and not the next; the analyzer will not tell
   you, because it does not analyze dependency sources.
4. Update `FLUTTER_VERSION` in `.github/workflows/flutter-ci.yml` and
   `.github/workflows/release.yml`.

Do not fold an SDK bump into a feature delivery: when CI then breaks, you cannot tell which
change caused it.

---

## Branding assets

All icons derive from a single source: `assets/branding/genaisys.svg`.

```bash
# PNG sizes used by the .deb (hicolor) and the macOS AppIcon set
for s in 16 24 32 48 64 128 256 512; do
  rsvg-convert -w $s -h $s assets/branding/genaisys.svg -o assets/branding/genaisys-$s.png
done
```

Regenerate the platform icons from the same SVG when the mark changes:
`macos/Runner/Assets.xcassets/AppIcon.appiconset/`, `windows/runner/resources/app_icon.ico`,
`web/favicon.png`, `web/icons/`. Linux resolves its icon by name (`genaisys`) from the
hicolor set the `.deb` installs — see `packaging/linux/`.

---

## Signing

macOS and Windows builds are currently **unsigned**. macOS users need
right-click → Open on first launch; Windows may show a SmartScreen prompt. Code signing
requires certificates in repository secrets and is not yet configured.
