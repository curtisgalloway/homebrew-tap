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

**Terms:** a tap contains Homebrew installation recipes (formulae); a bottle
is a prebuilt package archive. See [GLOSSARY.md](GLOSSARY.md).

Homebrew formulae for [Curtis Galloway](https://github.com/curtisgalloway)'s
projects.

## Usage

```bash
brew tap curtisgalloway/tap
brew install panio
```

Or in one step: `brew install curtisgalloway/tap/panio`.

## Formulae

| Formula | Description |
|---|---|
| [`panio`](Formula/panio.rb) | Agent-controlled target machine wrangler — distributed bring-up control over SSH ([repo](https://github.com/curtisgalloway/panio)) |
| [`oxbox`](Formula/oxbox.rb) | Supervised harness for running an untrusted LLM against real code ([repo](https://github.com/curtisgalloway/oxbox)) |
| [`qbranch`](Formula/qbranch.rb) | Outfits a machine's coding agents from a per-machine manifest ([repo](https://github.com/curtisgalloway/qbranch)) |

`qbranch` is a binary formula: on Apple Silicon and Intel Macs alike it pours
the prebuilt, corpus-tested binary from the qbranch release, so no toolchain is
involved and nothing is built. macOS only; on Linux the `.deb` on
[GitHub Releases](https://github.com/curtisgalloway/qbranch/releases) is the
supported path, and `cargo install qbranch` covers a source build anywhere.

`panio` is a **binary formula**: `brew install` pours the prebuilt tarball
from the panio release — a universal (Apple Silicon + Intel) binary on
macOS, an arch-matched binary on Linux — with no Rust toolchain and no build
step, on either platform. `brew install --HEAD` is the exception: it builds
from a git checkout for anyone hacking on panio itself, and only that spec
needs Rust (plus `cmake`/`nasm`/`pkg-config` on Linux).

Each release asset ships with a `.sha256` sidecar file (plain
`sha256sum`-format text) alongside it on
[GitHub Releases](https://github.com/curtisgalloway/panio/releases); the
formula's `sha256` lines are copied straight from those, not computed by
hand. To re-pin the formula to a new panio release yourself:

```bash
scripts/repin.sh vX.Y.Z
```

It downloads the three sidecars, checks each one is well-formed, and rewrites
`Formula/panio.rb`'s `version` and all three `url`/`sha256` pairs in place
(the macOS pair appears twice, once under `on_arm` and once under
`on_intel`, since one universal binary covers both — see the formula's
comments). It refuses to touch the formula if any sidecar is missing, which
is normal for a release that predates this scheme or hasn't finished
publishing yet. `.github/workflows/bump-formula.yml` runs the same script
automatically on every panio release.

Bottles now wrap the release binaries in Homebrew's package layout. They live
on the project's own release alongside its ordinary tarballs; no compilation
runs in this tap.

## op-go releases

The first complete [op-go release](https://github.com/curtisgalloway/op-go/releases)
creates `Formula/op-go.rb`; there is no placeholder formula before that release.
Afterward, install it with `brew install curtisgalloway/tap/op-go` on macOS
(Apple Silicon or Intel) or Linux (ARM64 or x86-64).

The **Bump op-go formula** workflow accepts an explicit stable `vX.Y.Z` tag,
either manually or through an `op-go-release` dispatch event with
`client_payload.tag`. The op-go repository needs the
`HOMEBREW_TAP_DISPATCH_TOKEN` secret: a fine-grained GitHub token with
Contents:write permission on this tap. The tap workflow uses its own
`GITHUB_TOKEN` to commit and push the formula.

The workflow downloads all three binary tarballs, all three bottles, and
their six `.sha256` sidecars. `scripts/repin_op_go.py` verifies the actual
archive bytes against strictly named checksums before writing anything.
Missing assets, malformed checksums, mismatches, empty archives, prerelease
tags, version downgrades, and changes to an already pinned version fail
without replacing the formula. Repeating the exact same pin is a no-op. macOS uses
the universal binary and the `all` bottle; explicit Linux bottle entries
prevent Linux from selecting the macOS bottle.

The generator also supports offline release validation through `--tag`,
`--assets` (a directory of all twelve files), and `--output` (a scratch
formula path). Run its tests with `python3 -m unittest scripts/test_repin_op_go.py`.
The generated `brew test` checks version, embedded instructions, missing-file
credential diagnostics, and a fake-reference dry run without accessing real
credentials. It does not qualify live Keychain or Secret Service access.

## License

[Apache 2.0](LICENSE)
