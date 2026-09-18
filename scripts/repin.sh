#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0
#
# Re-pin a binary formula to a release: rewrites the version line and the
# url/sha256 pair for each of the three stable-spec assets (macOS universal,
# Linux arm64, Linux amd64). The formula pours release tarballs, so this is
# the whole bump — no bottle build, no source-hash computation.
#
# Usage: scripts/repin.sh vX.Y.Z
#        REPIN_PROJECT=oxbox scripts/repin.sh vX.Y.Z
#
# REPIN_PROJECT names the project (default paniolo): the GitHub repo is
# curtisgalloway/<project>, the formula is Formula/<project>.rb, and the
# assets are <project>-<version>-<suffix>.tar.gz. paniolo and oxbox publish
# the same three suffixes with the same sha256 sidecars, so one script
# serves both.
#
# Verifies each asset's `.sha256` sidecar before writing anything: if a
# release is missing one (as every release through v0.1.17 is, since the
# macOS tarball and its sidecar are only added from v0.1.18 on) this refuses
# to touch the formula rather than pin an incomplete stable spec. The actual
# line-level rewrite is scripts/repin_rewrite.py; see that file to test the
# rewrite alone, with no network access, against a fixture formula.
#
# Runnable by hand from a checkout, or from CI (bump-formula.yml): both just
# need `gh` authenticated for curtisgalloway/paniolo, a public repo, so an
# unauthenticated `gh` (subject to lower rate limits) also works.
#
# For testing the download+verify step without hitting a real release, set
# REPIN_SIDECAR_DIR to a local directory already holding the three
# `<asset>.sha256` files instead of fetching them with `gh release download`.

set -euo pipefail

usage() {
  echo "usage: $(basename "$0") vX.Y.Z" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
fi

tag="$1"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: tag must look like vX.Y.Z, got '${tag}'" >&2
  exit 1
fi
version="${tag#v}"

project="${REPIN_PROJECT:-paniolo}"
repo="curtisgalloway/${project}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
formula="${script_dir}/../Formula/${project}.rb"
rewrite_script="${script_dir}/repin_rewrite.py"

if [ ! -f "$formula" ]; then
  echo "error: ${formula} not found" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# suffix (matched against the formula's existing url lines by
# repin_rewrite.py) : full release asset filename for this tag/version.
asset_macos="${project}-${version}-macos-universal.tar.gz"
asset_linux_arm64="${project}-${version}-linux-arm64.tar.gz"
asset_linux_amd64="${project}-${version}-linux-amd64.tar.gz"

# Downloads <asset>.sha256 into workdir, from REPIN_SIDECAR_DIR if set
# (testing path, no network) or otherwise from the release (production
# path). Exits with an error — refusing to touch the formula — if the
# sidecar isn't there: a release missing an asset's sidecar has either not
# finished publishing yet or predates sidecars altogether, and either way
# the formula must not be re-pinned to it.
fetch_sidecar() {
  asset="$1"
  sidecar="${asset}.sha256"
  if [ -n "${REPIN_SIDECAR_DIR:-}" ]; then
    if [ ! -f "${REPIN_SIDECAR_DIR}/${sidecar}" ]; then
      echo "error: missing ${sidecar} in REPIN_SIDECAR_DIR=${REPIN_SIDECAR_DIR} -- refusing to re-pin" >&2
      exit 1
    fi
    cp "${REPIN_SIDECAR_DIR}/${sidecar}" "${workdir}/${sidecar}"
    return
  fi
  if ! gh release download "$tag" -R "$repo" -p "$sidecar" -D "$workdir" --clobber 2>/dev/null; then
    echo "error: missing ${sidecar} on release ${tag} -- refusing to re-pin" >&2
    exit 1
  fi
}

# Reads workdir/<asset>.sha256, checks it is exactly a 64-hex sha256sum line
# for that asset (sha256sum's own format, `<hex>  <filename>`, optionally
# with the `*` binary-mode marker sha256sum sometimes prepends to the
# filename), and prints the hex hash on success.
read_sha256() {
  asset="$1"
  sidecar_path="${workdir}/${asset}.sha256"
  content="$(tr -d '\r' < "$sidecar_path")"
  if [[ ! "$content" =~ ^([0-9a-f]{64})[[:space:]]+\*?${asset}$ ]]; then
    echo "error: ${asset}.sha256 does not look like 'sha256  ${asset}': got '${content}'" >&2
    exit 1
  fi
  echo "${BASH_REMATCH[1]}"
}

# Like fetch_sidecar, but a missing sidecar returns 1 instead of exiting:
# for the bottle sidecars, which releases before paniolo v0.4.0 do not have.
fetch_sidecar_optional() {
  asset="$1"
  sidecar="${asset}.sha256"
  if [ -n "${REPIN_SIDECAR_DIR:-}" ]; then
    if [ ! -f "${REPIN_SIDECAR_DIR}/${sidecar}" ]; then
      return 1
    fi
    cp "${REPIN_SIDECAR_DIR}/${sidecar}" "${workdir}/${sidecar}"
    return 0
  fi
  gh release download "$tag" -R "$repo" -p "$sidecar" -D "$workdir" --clobber 2>/dev/null
}

echo "Fetching sidecars for ${tag}..."
fetch_sidecar "$asset_macos"
fetch_sidecar "$asset_linux_arm64"
fetch_sidecar "$asset_linux_amd64"

sha_macos="$(read_sha256 "$asset_macos")"
sha_linux_arm64="$(read_sha256 "$asset_linux_arm64")"
sha_linux_amd64="$(read_sha256 "$asset_linux_amd64")"

base_url="https://github.com/${repo}/releases/download/${tag}"

# Bottles: <project>-<version>.<tag>.bottle.tar.gz, one `all` for macOS
# (universal binary) and one per Linux arch, each with a sidecar like the
# tarballs. A release has either all three or none: none means a release
# from before bottles existed and the formula pours tarballs; all three are
# handed to the rewrite as the bottle block; anything in between is a
# half-published release and this refuses to pin it, as with the tarballs.
bottle_tags="all arm64_linux x86_64_linux"
bottle_args=()
have_bottles=0
for bottle_tag in $bottle_tags; do
  asset_bottle="${project}-${version}.${bottle_tag}.bottle.tar.gz"
  if fetch_sidecar_optional "$asset_bottle"; then
    have_bottles=$((have_bottles + 1))
    bottle_args+=(--bottle "$bottle_tag" "$(read_sha256 "$asset_bottle")")
  fi
done
case "$have_bottles" in
  0) echo "No bottle sidecars on ${tag}; the formula will pour tarballs only." ;;
  3) bottle_args=(--bottle-root-url "$base_url" "${bottle_args[@]}") ;;
  *)
    echo "error: ${tag} has ${have_bottles} of 3 bottle sidecars (${bottle_tags}) -- refusing to re-pin" >&2
    exit 1
    ;;
esac

echo "Rewriting ${formula}..."
# ${arr[@]+"${arr[@]}"} rather than a bare "${arr[@]}": under `set -u` an
# empty array expansion is an unbound-variable error in bash 3.2, which is
# what a Mac runs this with by hand.
python3 "$rewrite_script" "$formula" \
  --version "$version" \
  --asset "macos-universal.tar.gz" "${base_url}/${asset_macos}" "$sha_macos" \
  --asset "linux-arm64.tar.gz" "${base_url}/${asset_linux_arm64}" "$sha_linux_arm64" \
  --asset "linux-amd64.tar.gz" "${base_url}/${asset_linux_amd64}" "$sha_linux_amd64" \
  ${bottle_args[@]+"${bottle_args[@]}"}

echo "Done. Formula/${project}.rb now pins ${tag}."
