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

The url/sha bump is automated. When paniolo's release workflow publishes a
`vX.Y.Z` Release it fires a `repository_dispatch` (`event_type:
paniolo-release`) at this repo, and `.github/workflows/bump-formula.yml`
re-pins `Formula/paniolo.rb` (url + source-tarball sha256) and commits. So a
normal release needs nothing here.

Requires the `HOMEBREW_TAP_DISPATCH_TOKEN` secret in the *paniolo* repo — a
fine-grained PAT with Contents:write on this repo — so paniolo can fire the
dispatch (the default `GITHUB_TOKEN` can't trigger cross-repo). Without it the
paniolo job warns and skips; the formula just won't move until bumped by hand.

Manual / catch-up bump (no release needed): run the **Bump paniolo formula**
workflow here (`workflow_dispatch`) — leave `tag` blank to pin paniolo's
latest release, or pass an explicit `vX.Y.Z`. From a checkout:
`gh workflow run bump-formula.yml -f tag=vX.Y.Z`.

After any bump, verify on a Mac: `brew update && brew upgrade paniolo` (or
`brew install --build-from-source Formula/paniolo.rb` from a checkout), then
`brew test paniolo`.

## Constraints

- The formula must pin a paniolo tag ≥ v0.1.2: v0.1.1 added the
  exe-relative libexec lookup (`exe_relative_dirs` in `cli/src/daemons.rs`)
  that lets a keg-installed CLI find its helpers; v0.1.2 made
  `paniolo setup` work without a source checkout (the caveat tells users to
  run it for the macOS setuid step). Older tags build fine but break one or
  both of those flows.
- Helper list in the formula mirrors `HELPER_CRATES` in paniolo's
  `cli/src/setup.rs` — keep them in sync when helpers are added.
- Bundled skills (`paniolo skill`) install from a `skills/*/SKILL.md` glob
  into the keg's `share/paniolo/skills` (the canonicalized exe-relative dir in
  `cli/src/skills.rs`), so new skills need no formula edit. Requires a pin ≥
  v0.1.4, where the `skills/` tree and the `skill` subcommand first exist.
- `std_cargo_args` passes `--locked`: every paniolo crate keeps a committed
  `Cargo.lock`, so a version bump needs no formula changes beyond url/sha.
- macOS is the tested platform. The `on_linux` build deps mirror paniolo's
  `make check-deps` list, but Linux-via-brew is untested — the README points
  Linux users at the .deb instead.
