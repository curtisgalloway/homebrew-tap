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

The url/sha bump **and** the precompiled macOS bottles are automated. When
paniolo's release workflow publishes a `vX.Y.Z` Release it fires a
`repository_dispatch` (`event_type: paniolo-release`) at this repo, and
`.github/workflows/bump-formula.yml` runs three jobs in order:

1. **bump** (ubuntu) — re-pin `Formula/paniolo.rb` (url + source-tarball
   sha256), strip any stale `bottle do` block, commit & push.
2. **bottle** (macos-14, Apple Silicon only) — source-build the re-pinned
   formula with `brew install --build-bottle`, `brew bottle` it, and upload the
   `.bottle.tar.gz` to a `paniolo-<version>` Release **on this repo** (that's
   the bottles' `root_url`). The bottle JSON is stashed as a build artifact.
3. **merge** (ubuntu) — `brew bottle --merge` the sha256 into the formula,
   `brew style --fix`, commit & push.

So a normal release needs nothing here. After it runs, an Apple Silicon Mac
installs the precompiled bottle — **no Rust toolchain**. A macOS newer than the
build host (macos-14 → `arm64_sonoma`) uses that newest tag ≤ its own. Intel
Macs, and any Linux install, have no bottle and fall back to the source build,
which `depends_on "rust" => :build` makes automatic.

Requires the `HOMEBREW_TAP_DISPATCH_TOKEN` secret in the *paniolo* repo — a
fine-grained PAT with Contents:write on this repo — so paniolo can fire the
dispatch (the default `GITHUB_TOKEN` can't trigger cross-repo). Without it the
paniolo job warns and skips; the formula just won't move until bumped by hand.
The bottle/merge jobs need no extra secret — they push and host bottles with
this repo's own `GITHUB_TOKEN` (`contents: write`).

Manual / catch-up bump (re-pins **and** rebuilds bottles): run the **Bump
paniolo formula** workflow here (`workflow_dispatch`) — leave `tag` blank to
pin paniolo's latest release, or pass an explicit `vX.Y.Z`. From a checkout:
`gh workflow run bump-formula.yml -f tag=vX.Y.Z`.

After any bump, verify on a Mac: `brew update && brew upgrade paniolo` (a
`Pouring paniolo--<ver>.<tag>.bottle.tar.gz` line confirms the bottle was used,
not a source build), then `brew test paniolo`. To force the source path for
comparison: `brew reinstall --build-from-source paniolo`.

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
- Changing the formula's install logic (or anything that alters the built
  keg) at an **unchanged** paniolo version requires a `revision N` bump —
  brew keys upgrades on the version string, so without it `brew upgrade` is a
  no-op and existing installs need `brew reinstall paniolo` to pick up the
  change. (Seen once: the automated url/sha bump shipped 0.1.4 with no skills,
  then a manual PR added the skills block still at 0.1.4 — same-version kegs
  never rebuilt.) The automated bump only rewrites url/sha, so a normal
  release is always a new version and is exempt; this only bites a hand edit
  that keeps the version.
- macOS is the tested platform. The `on_linux` build deps mirror paniolo's
  `make check-deps` list, but Linux-via-brew is untested — the README points
  Linux users at the .deb instead. No Linux bottles are built.
- The `bottle` and `merge` jobs **must** reset the tap onto
  `needs.bump.outputs.sha` before doing anything else (the "Pin the tap to the
  re-pinned commit" step). `Homebrew/actions/setup-homebrew` taps this repo at
  `$GITHUB_SHA` — main's tip when the dispatch fired, i.e. *before* `bump`
  pushed the re-pin — and it does that by re-initialising the job workspace, so
  it overrides `actions/checkout` too. Without the reset the pipeline works from
  the previous version's formula: `bottle` builds the OLD version and uploads it
  under the new version's Release, and `merge`'s push is rejected as
  non-fast-forward. This is why `repository_dispatch` runs failed while a manual
  `workflow_dispatch` re-run succeeded — on the re-run main's tip already
  carried the re-pin, so `$GITHUB_SHA` happened to be right. Seen on 0.1.10
  (a 0.1.9 bottle landed in the `paniolo-0.1.10` Release) and 0.1.11 (a 0.1.10
  bottle in `paniolo-0.1.11`). The tag/filename guards in `bottle` now fail the
  job loudly instead of shipping a mislabelled tarball.
- Keep the literal word `setuid` out of `def caveats`: `brew style`'s
  `FormulaAudit/Caveats` cop flags it ("suggest `sudo`"), and the merge job runs
  `brew style --fix ... || true`, so the offence never fails a build — it just
  prints misleading `##[error]` lines in otherwise-green runs. The caveat says
  "set-user-ID bit", which is the POSIX term chmod(2)/execve(2) use and is
  precise about what `paniolo setup` does, while the "one sudo prompt" wording
  gives the cop the `sudo` mention it's after. Reword around it rather than
  reaching for a `rubocop:disable` (a directive that stops matching is itself an
  offence under `Lint/RedundantCopDisableDirective`).
- Bottles are hosted on this repo's Releases under a `paniolo-<version>` tag
  (the formula's `bottle do` `root_url`). Don't delete those Releases — doing
  so makes `brew install` 404 the bottle and silently fall back to a source
  build. The `bottle do` block is machine-generated by the `merge` job; never
  hand-edit its sha256s.
- **Apple Silicon only.** Bottles build on **macos-14** (the oldest GA arm64
  runner, → `arm64_sonoma`, covering Sonoma and newer). Intel (x86_64) is
  intentionally unsupported: those Macs source-build. Intel was dropped because
  public-repo `macos-13` runners queue unpredictably (observed: a single bottle
  job stuck >25 min waiting for a runner, blocking the whole pipeline), and the
  Intel runners are being sunset by GitHub anyway. To add an arch later, give
  the `bottle` job a matrix again — but note `merge` then needs every leg's JSON
  before it runs, so a laggard/queued leg blocks the lot.
