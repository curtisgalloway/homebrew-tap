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

# homebrew-tap — Agent Instructions

Homebrew tap for paniolo (and future formulae). Users install with
`brew install curtisgalloway/tap/paniolo`.

## Releasing a new paniolo version

1. Tag the release in the paniolo repo (`vX.Y.Z`) — its release workflow
   builds the Linux packages; the formula here builds from the source
   tarball GitHub generates for the tag.
2. Compute the tarball digest:
   `curl -fsSL https://github.com/curtisgalloway/paniolo/archive/refs/tags/vX.Y.Z.tar.gz | sha256sum`
3. Update `url` and `sha256` in `Formula/paniolo.rb`, commit, push.
4. Verify on a Mac: `brew update && brew upgrade paniolo` (or
   `brew install --build-from-source Formula/paniolo.rb` from a checkout),
   then `brew test paniolo`.

## Constraints

- The formula must pin a paniolo tag ≥ v0.1.1 — that release added the
  exe-relative libexec lookup (`exe_relative_dirs` in `cli/src/daemons.rs`)
  that lets a keg-installed CLI find its helpers. Older tags build fine but
  the helpers are invisible to the CLI.
- Helper list in the formula mirrors `HELPER_CRATES` in paniolo's
  `cli/src/setup.rs` — keep them in sync when helpers are added.
- `std_cargo_args` passes `--locked`: every paniolo crate keeps a committed
  `Cargo.lock`, so a version bump needs no formula changes beyond url/sha.
- macOS is the tested platform. The `on_linux` build deps mirror paniolo's
  `make check-deps` list, but Linux-via-brew is untested — the README points
  Linux users at the .deb instead.
