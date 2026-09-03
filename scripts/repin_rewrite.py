#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0
"""Rewrite the stable pins in a Homebrew formula, in place.

The pure, no-network half of scripts/repin.sh: given a formula file, a new
version, and one (filename-suffix, url, sha256) triple per release asset, it
rewrites the matching `url`/`sha256` line pairs and the top-level `version`
line. Kept separate from repin.sh (which does the `gh release download` and
sidecar verification) so the rewrite itself can be unit-tested against a
fixture formula with no network access and no `gh` invocation.

Matching is by filename suffix, not by line position or block nesting, so it
finds a `url` line wherever it lives in the file and is indifferent to how
many times a given asset is pinned (Formula/paniolo.rb pins the macOS
tarball twice, once under on_arm and once under on_intel, because both
architectures share one universal binary). It refuses to touch anything
inside a `head do ... end` block — the --HEAD spec builds from a git
checkout and must keep its own `url`, not a release tarball's.
"""

import argparse
import re
import sys

VERSION_RE = re.compile(r'^(?P<indent>\s*)version "(?P<value>[^"]*)"\s*$')
URL_RE = re.compile(r'^(?P<indent>\s*)url "(?P<value>[^"]*)"\s*$')
SHA256_RE = re.compile(r'^(?P<indent>\s*)sha256 "(?P<value>[0-9a-fA-F]{64})"\s*$')
HEAD_START_RE = re.compile(r'^(?P<indent>\s*)head do\s*$')


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("formula", help="path to the formula file to rewrite in place")
    parser.add_argument("--version", required=True, help='new "X.Y.Z" to write to the version line')
    parser.add_argument(
        "--asset",
        action="append",
        nargs=3,
        metavar=("SUFFIX", "URL", "SHA256"),
        default=[],
        help="repeatable: a release asset's filename suffix (e.g. macos-universal.tar.gz), "
        "its new url, and its new sha256",
    )
    args = parser.parse_args(argv)
    if not args.asset:
        parser.error("at least one --asset is required")
    return args


def find_head_block(lines):
    """Return the (start, end) 0-based line-index range of `head do ... end`,
    inclusive, or None if the formula has no head block. `end` is matched at
    the same indentation as `head do`, so nested `end`s (on_linux, etc.)
    don't terminate the search early.
    """
    for i, line in enumerate(lines):
        match = HEAD_START_RE.match(line)
        if not match:
            continue
        indent = match.group("indent")
        end_re = re.compile(r"^" + re.escape(indent) + r"end\s*$")
        for j in range(i + 1, len(lines)):
            if end_re.match(lines[j]):
                return (i, j)
        raise ValueError(f"line {i + 1}: 'head do' has no matching 'end'")
    return None


def rewrite_version(lines, new_version):
    matches = [i for i, line in enumerate(lines) if VERSION_RE.match(line)]
    if len(matches) != 1:
        raise ValueError(f"expected exactly one 'version \"...\"' line, found {len(matches)}")
    i = matches[0]
    indent = VERSION_RE.match(lines[i]).group("indent")
    old_value = VERSION_RE.match(lines[i]).group("value")
    lines[i] = f'{indent}version "{new_version}"\n'
    return old_value, i


def rewrite_asset(lines, suffix, new_url, new_sha256, head_range):
    """Replace every `url "...<suffix>"` line (and the sha256 line right
    after each one) with the new url/sha256. Returns the number of
    occurrences rewritten.
    """
    targets = []
    for i, line in enumerate(lines):
        match = URL_RE.match(line)
        if not match or not match.group("value").endswith(suffix):
            continue
        targets.append(i)

    if not targets:
        raise ValueError(f"no 'url \"...{suffix}\"' line found")

    for i in targets:
        if head_range and head_range[0] <= i <= head_range[1]:
            raise ValueError(f"line {i + 1}: refusing to rewrite a url inside the head block")
        sha_i = i + 1
        if sha_i >= len(lines) or not SHA256_RE.match(lines[sha_i]):
            raise ValueError(f"line {i + 1}: 'url \"...{suffix}\"' is not followed by a sha256 line")
        url_indent = URL_RE.match(lines[i]).group("indent")
        sha_indent = SHA256_RE.match(lines[sha_i]).group("indent")
        lines[i] = f'{url_indent}url "{new_url}"\n'
        lines[sha_i] = f'{sha_indent}sha256 "{new_sha256}"\n'

    return len(targets)


def main(argv):
    args = parse_args(argv)

    with open(args.formula, encoding="utf-8") as f:
        lines = f.readlines()

    head_range = find_head_block(lines)

    old_version, version_line = rewrite_version(lines, args.version)
    print(f"version: {old_version!r} -> {args.version!r} (line {version_line + 1})")

    for suffix, url, sha256 in args.asset:
        count = rewrite_asset(lines, suffix, url, sha256, head_range)
        plural = "occurrence" if count == 1 else "occurrences"
        print(f"...{suffix}: {count} {plural} repinned -> {url}")

    with open(args.formula, "w", encoding="utf-8") as f:
        f.writelines(lines)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
