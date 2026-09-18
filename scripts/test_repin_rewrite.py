#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0
"""Tests for repin_rewrite.py against a fixture formula. No network, no gh.

Run from a checkout: python3 -m unittest scripts/test_repin_rewrite.py
"""

import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "repin_rewrite.py")
FORMULA = os.path.join(HERE, "..", "Formula", "paniolo.rb")

SHA_A = "a" * 64
SHA_B = "b" * 64
SHA_C = "c" * 64
SHA_D = "d" * 64

FIXTURE = """class Paniolo < Formula
  desc "fixture"
  homepage "https://example.invalid"
  version "0.1.0"
  license "Apache-2.0"

  head do
    url "https://github.com/curtisgalloway/paniolo.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    on_arm do
      url "https://example.invalid/v0.1.0/paniolo-0.1.0-macos-universal.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://example.invalid/v0.1.0/paniolo-0.1.0-macos-universal.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  on_linux do
    on_arm do
      url "https://example.invalid/v0.1.0/paniolo-0.1.0-linux-arm64.tar.gz"
      sha256 "1111111111111111111111111111111111111111111111111111111111111111"
    end
  end

  def install
    bin.install "paniolo"
  end
end
"""

ASSET_ARGS = [
    "--version",
    "0.2.0",
    "--asset",
    "macos-universal.tar.gz",
    "https://example.invalid/v0.2.0/paniolo-0.2.0-macos-universal.tar.gz",
    SHA_A,
    "--asset",
    "linux-arm64.tar.gz",
    "https://example.invalid/v0.2.0/paniolo-0.2.0-linux-arm64.tar.gz",
    SHA_B,
]

BOTTLE_ARGS = [
    "--bottle-root-url",
    "https://example.invalid/v0.2.0",
    "--bottle",
    "all",
    SHA_C,
    "--bottle",
    "arm64_linux",
    SHA_D,
]


def run(formula_text, *extra):
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "paniolo.rb")
        with open(path, "w", encoding="utf-8") as f:
            f.write(formula_text)
        proc = subprocess.run(
            [sys.executable, SCRIPT, path, *ASSET_ARGS, *extra],
            capture_output=True,
            text=True,
            check=False,
        )
        with open(path, encoding="utf-8") as f:
            return proc, f.read()


class RepinRewriteTest(unittest.TestCase):
    def test_inserts_bottle_block_between_license_and_head(self):
        proc, out = run(FIXTURE, *BOTTLE_ARGS)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("bottle block: inserted (all, arm64_linux)", proc.stdout)
        bottle_at = out.index("  bottle do\n")
        self.assertGreater(bottle_at, out.index('  license "Apache-2.0"\n'))
        self.assertLess(bottle_at, out.index("  head do\n"))
        self.assertIn('    root_url "https://example.invalid/v0.2.0"\n', out)
        # Digests aligned on the longest tag (brew style BottleDigestIndentation).
        self.assertIn(f'    sha256 cellar: :any_skip_relocation, all:         "{SHA_C}"\n', out)
        self.assertIn(f'    sha256 cellar: :any_skip_relocation, arm64_linux: "{SHA_D}"\n', out)
        self.assertIn("  # Bottles:", out)
        # Blank line on both sides of the block, never two.
        self.assertIn('  license "Apache-2.0"\n\n  # Bottles:', out)
        self.assertIn(f'arm64_linux: "{SHA_D}"\n  end\n\n  head do', out)
        self.assertNotIn("\n\n\n", out)

    def test_rewrite_is_idempotent_and_replaces_in_place(self):
        proc, once = run(FIXTURE, *BOTTLE_ARGS)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        proc, twice = run(once, *BOTTLE_ARGS)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("bottle block: replaced", proc.stdout)
        self.assertEqual(once, twice)
        self.assertEqual(once.count("bottle do"), 1)

    def test_no_bottles_removes_existing_block(self):
        _, with_block = run(FIXTURE, *BOTTLE_ARGS)
        proc, out = run(with_block)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("bottle block: removed", proc.stdout)
        self.assertNotIn("bottle do", out)
        self.assertNotIn("# Bottles:", out)
        self.assertNotIn("\n\n\n", out)
        # Everything but the pins is back to the fixture.
        expected = FIXTURE.replace('version "0.1.0"', 'version "0.2.0"')
        expected = expected.replace(
            "https://example.invalid/v0.1.0/paniolo-0.1.0-macos-universal.tar.gz",
            "https://example.invalid/v0.2.0/paniolo-0.2.0-macos-universal.tar.gz",
        ).replace("0" * 64, SHA_A)
        expected = expected.replace(
            "https://example.invalid/v0.1.0/paniolo-0.1.0-linux-arm64.tar.gz",
            "https://example.invalid/v0.2.0/paniolo-0.2.0-linux-arm64.tar.gz",
        ).replace("1" * 64, SHA_B)
        self.assertEqual(out, expected)

    def test_no_bottles_on_formula_without_block_is_a_no_op(self):
        proc, out = run(FIXTURE)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("bottle block: absent", proc.stdout)
        self.assertNotIn("bottle do", out)

    def test_head_block_is_never_touched(self):
        _, out = run(FIXTURE, *BOTTLE_ARGS)
        self.assertIn(
            '    url "https://github.com/curtisgalloway/paniolo.git", branch: "main"\n', out
        )

    def test_bottle_without_root_url_is_refused(self):
        proc, out = run(FIXTURE, "--bottle", "all", SHA_C)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("--bottle needs --bottle-root-url", proc.stderr)
        self.assertEqual(out, FIXTURE)

    def test_bad_sha_is_refused(self):
        proc, out = run(FIXTURE, "--bottle-root-url", "https://x", "--bottle", "all", "nope")
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(out, FIXTURE)

    def test_real_formula_round_trips(self):
        with open(FORMULA, encoding="utf-8") as f:
            real = f.read()
        proc, out = run(real, *BOTTLE_ARGS)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(out.count("bottle do"), 1)
        self.assertLess(out.index("bottle do"), out.index("head do"))
        self.assertGreater(out.index("bottle do"), out.index('license "Apache-2.0"'))


if __name__ == "__main__":
    unittest.main()
