# Linux packaging

Artifacts produced by `.github/workflows/release.yml` on a `v*` tag:

| Artifact | Contents |
|---|---|
| `genaisys_<version>_amd64.deb` | GUI in `/opt/genaisys`, `genaisys-gui` + `genaisys` CLI on `PATH`, desktop entry, hicolor icons |
| `genaisys-linux-x64.tar.gz` | Portable GUI bundle — unpack and run `./genaisys` |
| `genaisys-cli-linux-x64` | Standalone CLI binary (no Flutter runtime needed) |

The `.desktop` entry and icons come from this directory and `assets/branding/`.
