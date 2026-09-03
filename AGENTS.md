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

Homebrew tap for paniolo, oxbox and qbranch. Users install with
`brew install curtisgalloway/tap/<formula>`.

## Releasing a new paniolo version

`Formula/paniolo.rb` is a **binary formula**: it pours the prebuilt,
release-tested tarballs from the paniolo GitHub Release — one for macOS
(universal, arm64 + x86_64) and one each for Linux arm64/amd64 — with no
Rust toolchain and no build step on either platform. `brew install --HEAD`
is the one exception: it builds from a git checkout, for anyone hacking on
paniolo itself, and only that spec pulls in `depends_on "rust" => :build`
(plus `cmake`/`nasm`/`pkg-config` on Linux).

Each release asset ships with a `.sha256` sidecar (plain `sha256sum`-format
text) from v0.1.18 on — earlier releases, and any release that predates the
macOS tarball, have no sidecar for it and can't be pinned by this mechanism.

The bump is one job. When paniolo's release workflow publishes a `vX.Y.Z`
Release it fires `repository_dispatch` (`event_type: paniolo-release`) here,
and `.github/workflows/bump-formula.yml` runs `scripts/repin.sh "$tag"`,
which downloads the three sidecars, verifies each is a well-formed
`sha256sum` line for its asset, and rewrites `Formula/paniolo.rb`'s
`version` and all three `url`/`sha256` pairs in place — then a best-effort
`brew style` (skipped if the runner has no Homebrew, which GitHub's
`ubuntu-latest` doesn't), commit & push. It refuses to touch the formula if
any sidecar is missing, so a release without one can't leave the formula
pinned to an incomplete stable spec.

The actual line-level rewrite lives in `scripts/repin_rewrite.py`, kept
separate from `repin.sh` so it can be tested with no network access at all
— run it directly against a fixture formula to check the rewrite alone. It
matches `url` lines by asset filename suffix rather than by position, so it
finds and rewrites the macOS pin's *two* occurrences (once under `on_arm`,
once under `on_intel` — see the comment above `on_macos do` in the formula
for why one universal binary is pinned twice), and it refuses outright to
touch anything inside the formula's `head do ... end` block.

Requires the `HOMEBREW_TAP_DISPATCH_TOKEN` secret in the *paniolo* repo — a
fine-grained PAT with Contents:write on this repo — so paniolo can fire the
dispatch (the default `GITHUB_TOKEN` can't trigger cross-repo). Without it
the paniolo job warns and skips; the formula just won't move until bumped by
hand. The bump job itself needs no extra secret beyond that dispatch trigger
and its own `GITHUB_TOKEN` (`contents: write`) to commit and push, and
`gh release download` works unauthenticated against paniolo's public repo
too (subject to the lower unauthenticated rate limit).

Manual / catch-up bump: run the **Bump paniolo formula** workflow here
(`workflow_dispatch`) — leave `tag` blank to pin paniolo's latest release,
or pass an explicit `vX.Y.Z`. From a checkout: `gh workflow run
bump-formula.yml -f tag=vX.Y.Z`. To re-pin by hand instead, from a checkout
of this repo: `scripts/repin.sh vX.Y.Z` (needs `gh` and `python3`; see that
script's header for the `REPIN_SIDECAR_DIR` testing hook).

After any bump, verify on a Mac or Linux box: `brew update && brew upgrade
paniolo` (the install log shows a plain download+extract, no `cargo build`
line — that's how you know it poured the binary rather than compiling),
then `brew test paniolo`. To exercise the source build for comparison:
`brew install --HEAD --build-from-source curtisgalloway/tap/paniolo`.

There are no bottles any more — nothing is compiled, so there is nothing
for a bottle to precompile. The `paniolo-<ver>` Releases on this repo that
used to host bottle tarballs are stale; they can be deleted at leisure.

## Releasing a new qbranch version

`Formula/qbranch.rb` is a **binary formula**: it pours the prebuilt tarball from
the qbranch GitHub Release, one `url`/`sha256` pair per architecture inside
`on_macos` / `on_arm` / `on_intel`, with no bottle, no `depends_on "rust"` and
no `head`. Those tarballs were built and corpus-tested by qbranch's own release
workflow, so the tap ships exactly what that workflow proved rather than a
rebuild. Source builders use `cargo install qbranch`; Linux users take the
`.deb` from the release. This differs from paniolo's pattern on purpose:
paniolo has helper crates and per-platform OCR that need a source build, and
qbranch is one static executable.

The bump is one job. When qbranch's release workflow publishes a `vX.Y.Z`
Release it fires `repository_dispatch` (`event_type: qbranch-release`) here, and
`.github/workflows/bump-qbranch-formula.yml` hashes both macOS tarballs,
rewrites the `version` line and both `url`/`sha256` pairs, checks with `ruby -c`
that the formula still parses and that both url lines carry the new tag, and
pushes to main. No macOS runner, no bottle Release, nothing to prune. It needs
`HOMEBREW_TAP_DISPATCH_TOKEN` in the *qbranch* repo, the same fine-grained PAT
with Contents:write on this repo that paniolo and oxbox hold. Manual or
catch-up bump: run the **Bump qbranch formula** workflow (`workflow_dispatch`),
tag blank for the latest release, or
`gh workflow run bump-qbranch-formula.yml -f tag=vX.Y.Z`.

Constraints specific to this formula:

- The tag must be plain `vX.Y.Z`; the workflow refuses anything else, because
  the tag lands in sed patterns and because a prerelease should not move every
  brew user.
- The `version` line is explicit and the bump rewrites it. The url/sha lines
  are matched by their target name, and each sha256 line must stay directly
  under its url line.
- The install block guards the `skills/` install with `File.directory?`
  because the 0.3.0 tarballs predate the `skills/` directory. From 0.3.1 every
  tarball carries it, and the guard can go once the pin has moved past 0.3.0.
- Changing the install block at an unchanged qbranch version needs a
  `revision N` bump, for the same reason as paniolo.
- Assets are named `qbranch-vX.Y.Z-<target>.tar.gz` and hold one top-level
  directory, which Homebrew strips. Renaming the assets in qbranch's
  `release.yml` breaks the bump's sed patterns; change both together.

## Constraints

- The stable spec's three release assets must all come from the same tag,
  and that tag must be ≥ v0.1.2: v0.1.1 added the exe-relative libexec
  lookup (`exe_relative_dirs` in `cli/src/daemons.rs`) that lets a
  keg-installed CLI find its helpers; v0.1.2 made `paniolo setup` work
  without a source checkout (the caveat tells users to run it for the
  macOS setuid step). `scripts/repin.sh` doesn't check this — it trusts
  whatever tag it's given — so don't hand-run it against an old tag.
- Helper list is duplicated three ways in `def install` — the `--HEAD`
  branch's `cargo install` loop, the macOS branch's
  `Dir["libexec/bin/*"]` glob (no explicit list needed there, since the
  tarball only contains what should ship), and the Linux branch's
  explicit array — and mirrors `HELPER_CRATES` in paniolo's
  `cli/src/setup.rs` and the `HELPERS` list in paniolo's
  `.github/workflows/release.yml`. Keep all of these in sync when helpers
  are added; the Linux branch's explicit list is the one most likely to
  drift, since nothing fails loudly if it's short — the missing helper is
  just absent from the keg.
- Bundled skills (`paniolo skill`) land in the keg's `share/paniolo/skills`
  (`pkgshare/"skills"` in the formula — the canonicalized exe-relative dir
  in `cli/src/skills.rs`). The `--HEAD` branch builds that from a
  `skills/*/SKILL.md` glob over the checkout; the stable branches just
  copy the tarball's own already-built skills tree (`share/paniolo/skills/*`
  on macOS, `skills/*` on Linux — see release.yml's asset layout), so new
  skills need no formula edit either way.
- `std_cargo_args` (with its `--locked`) is used only in the `--HEAD`
  branch — the stable branches never invoke cargo at all.
- Changing the formula's install logic (or anything that alters the built
  keg) at an **unchanged** paniolo version requires a `revision N` bump —
  brew keys upgrades on the version string, so without it `brew upgrade` is a
  no-op and existing installs need `brew reinstall paniolo` to pick up the
  change. (Seen once, back when the formula source-built: the automated
  bump shipped 0.1.4 with no skills, then a manual PR added the skills
  block still at 0.1.4 — same-version kegs never rebuilt.) `repin.sh` only
  rewrites `version`/`url`/`sha256`, so a normal release is always a new
  version and is exempt; this only bites a hand edit to `def install` that
  keeps the version.
- Linux is a first-class, tested-by-CI install path now (it pours the same
  release tarball macOS does), not a source build — see paniolo's
  `release.yml`, which builds and smoke-tests the Linux tarball before it's
  attached to a Release. The `on_linux` build deps under `head do` (mirroring
  paniolo's `make check-deps`) are needed only for `--HEAD`.
- Keep the literal word `setuid` out of `def caveats`: `brew style`'s
  `FormulaAudit/Caveats` cop flags it ("suggest `sudo`"). The bump job's
  `brew style` step is best-effort (skipped entirely if the runner has no
  Homebrew, which is normal for `ubuntu-latest`) but unlike the old
  bottle-era `merge` job it does **not** run with `--fix ... || true`, so on
  a runner that *does* have Homebrew this offence would actually fail the
  job. The caveat says "set-user-ID bit", the POSIX term chmod(2)/execve(2)
  use, which is precise about what `paniolo setup` does and avoids the
  flagged word. Reword around it rather than reaching for a
  `rubocop:disable` (a directive that stops matching is itself an offence
  under `Lint/RedundantCopDisableDirective`).
- The macOS pin appears **twice** in the formula — once under `on_arm`,
  once under `on_intel`, both pointing at the same universal-binary url and
  sha256 — because `brew style`'s `FormulaAudit/ComponentsOrder` cop
  rejects `url`/`sha256` as direct children of a bare `on_macos do` block
  (only `on_arch`, `on_intel`, a few other DSL calls and nested `on_*`
  blocks are allowed there; `url`/`sha256` must be one level deeper).
  `scripts/repin_rewrite.py` rewrites both copies together, matched by
  filename suffix, so hand-editing one without the other is the only way
  they'd drift.
