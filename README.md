<!--
Copyright 2026 Curtis Galloway

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# curtisgalloway/homebrew-tap

Homebrew formulae for [Curtis Galloway](https://github.com/curtisgalloway)'s
projects.

## Usage

```bash
brew tap curtisgalloway/tap
brew install paniolo
```

Or in one step: `brew install curtisgalloway/tap/paniolo`.

## Formulae

| Formula | Description |
|---|---|
| [`paniolo`](Formula/paniolo.rb) | Agent-controlled target machine wrangler — distributed bring-up control over SSH ([repo](https://github.com/curtisgalloway/paniolo)) |
| [`oxbox`](Formula/oxbox.rb) | Supervised harness for running an untrusted LLM against real code ([repo](https://github.com/curtisgalloway/oxbox)) |
| [`qbranch`](Formula/qbranch.rb) | Outfits a machine's coding agents from a per-machine manifest ([repo](https://github.com/curtisgalloway/qbranch)) |

`qbranch` is a binary formula: on Apple Silicon and Intel Macs alike it pours
the prebuilt, corpus-tested binary from the qbranch release, so no toolchain is
involved and nothing is built. macOS only; on Linux the `.deb` on
[GitHub Releases](https://github.com/curtisgalloway/qbranch/releases) is the
supported path, and `cargo install qbranch` covers a source build anywhere.

`paniolo` is a **binary formula**: `brew install` pours the prebuilt tarball
from the paniolo release — a universal (Apple Silicon + Intel) binary on
macOS, an arch-matched binary on Linux — with no Rust toolchain and no build
step, on either platform. `brew install --HEAD` is the exception: it builds
from a git checkout for anyone hacking on paniolo itself, and only that spec
needs Rust (plus `cmake`/`nasm`/`pkg-config` on Linux).

Each release asset ships with a `.sha256` sidecar file (plain
`sha256sum`-format text) alongside it on
[GitHub Releases](https://github.com/curtisgalloway/paniolo/releases); the
formula's `sha256` lines are copied straight from those, not computed by
hand. To re-pin the formula to a new paniolo release yourself:

```bash
scripts/repin.sh vX.Y.Z
```

It downloads the three sidecars, checks each one is well-formed, and rewrites
`Formula/paniolo.rb`'s `version` and all three `url`/`sha256` pairs in place
(the macOS pair appears twice, once under `on_arm` and once under
`on_intel`, since one universal binary covers both — see the formula's
comments). It refuses to touch the formula if any sidecar is missing, which
is normal for a release that predates this scheme or hasn't finished
publishing yet. `.github/workflows/bump-formula.yml` runs the same script
automatically on every paniolo release.

There are no bottles any more — a prebuilt binary formula has nothing left
for a bottle to precompile. The `paniolo-<ver>` Releases on this repo that
used to host them are stale and can be deleted at leisure.

## License

[Apache 2.0](LICENSE)
