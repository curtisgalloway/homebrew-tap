# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0
"""Offline tests for complete, verified op-go release pins."""

import hashlib
from pathlib import Path
import tempfile
import unittest

from scripts import repin_op_go


class RepinTest(unittest.TestCase):
    """Exercise verification before modifying an existing formula."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.output = self.directory / "op-go.rb"
        self.tag = "v1.2.3"
        self.names = repin_op_go.asset_names(self.tag)
        for name in self.names:
            data = name.encode()
            (self.directory / name).write_bytes(data)
            (self.directory / (name + ".sha256")).write_text(
                f"{hashlib.sha256(data).hexdigest()}  {name}\n"
            )

    def generate(self):
        """Generate using the fixture paths."""
        repin_op_go.generate(self.tag, self.directory, self.output)

    def test_complete_release(self):
        self.generate()
        content = self.output.read_text()
        for name in self.names[:3]:
            self.assertIn(name, content)
        for target in ("all", "x86_64_linux", "arm64_linux"):
            self.assertIn(f"{target}:", content)
        self.assertEqual(content.count(self.names[0]), 2)
        self.generate()
        self.assertEqual(self.output.read_text(), content)

    def test_invalid_inputs_preserve_formula(self):
        self.generate()
        original = self.output.read_text()
        sidecar = self.directory / (self.names[-1] + ".sha256")
        good = sidecar.read_text()
        for bad in (
            "",
            good.replace(self.names[-1], "../other"),
            good + good,
            "0" * 64 + good[64:],
        ):
            sidecar.write_text(bad)
            with self.assertRaises(ValueError):
                self.generate()
            self.assertEqual(original, self.output.read_text())
        sidecar.unlink()
        with self.assertRaises(OSError):
            self.generate()
        self.assertEqual(original, self.output.read_text())

    def test_corrupt_or_missing_asset(self):
        for payload in (b"", b"corrupt"):
            (self.directory / self.names[0]).write_bytes(payload)
            with self.assertRaises(ValueError):
                self.generate()
            self.assertFalse(self.output.exists())
        (self.directory / self.names[0]).unlink()
        with self.assertRaises(OSError):
            self.generate()

    def test_reject_tag_injection(self):
        for tag in ("v1.2.3;id", "v1.2.3\n", "v1.2.3-rc1", "v01.2.3", "../v1.2.3"):
            with self.assertRaises(ValueError):
                repin_op_go.generate(tag, self.directory, self.output)
        self.assertFalse(self.output.exists())

    def test_reject_downgrade(self):
        self.output.write_text('  version "1.10.0"\n')
        with self.assertRaisesRegex(ValueError, "downgrade"):
            self.generate()
        self.assertEqual(self.output.read_text(), '  version "1.10.0"\n')

    def test_reject_same_version_changed_content(self):
        self.generate()
        original = self.output.read_text()
        name = self.names[0]
        data = b"replacement archive"
        (self.directory / name).write_bytes(data)
        (self.directory / (name + ".sha256")).write_text(
            f"{hashlib.sha256(data).hexdigest()}  {name}\n"
        )
        with self.assertRaisesRegex(ValueError, "immutable"):
            self.generate()
        self.assertEqual(self.output.read_text(), original)


if __name__ == "__main__":
    unittest.main()
