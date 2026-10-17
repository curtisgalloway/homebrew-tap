#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0
"""Generate an op-go formula only after verifying every release asset."""

import argparse
import hashlib
from pathlib import Path
import re
import sys


def version_tuple(tag):
    """Validate a stable tag and return its numeric version."""
    if not re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag):
        raise ValueError("tag must be a stable vX.Y.Z version")
    return tuple(map(int, tag[1:].split(".")))


def asset_names(tag):
    """Return all required tarballs and bottles in deterministic order."""
    version_tuple(tag)
    return [
        f"op-go-{tag}-{target}.tar.gz"
        for target in ("darwin-universal", "linux-amd64", "linux-arm64")
    ] + [
        f"op-go-{tag[1:]}.{target}.bottle.tar.gz"
        for target in ("all", "x86_64_linux", "arm64_linux")
    ]


def verified_hash(directory, name):
    """Check a strict sha256sum sidecar against the actual nonempty asset."""
    sidecar = (directory / (name + ".sha256")).read_text(encoding="ascii")
    match = re.fullmatch(r"([0-9a-fA-F]{64}) [ *]" + re.escape(name) + r"\n?", sidecar)
    if not match:
        raise ValueError(f"invalid checksum sidecar for {name}")
    digest = hashlib.sha256()
    size = 0
    with (directory / name).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
            size += len(block)
    if not size or digest.hexdigest() != match[1].lower():
        raise ValueError(f"checksum mismatch or empty asset: {name}")
    return digest.hexdigest()


def render(tag, hashes):
    """Render the complete binary formula from validated release metadata."""
    names = asset_names(tag)
    base = f"https://github.com/curtisgalloway/op-go/releases/download/{tag}"
    lines = [
        "# SPDX-FileCopyrightText: 2026 Curtis Galloway",
        "# SPDX-License-Identifier: Apache-2.0",
        "",
        "class OpGo < Formula",
        '  desc "Launch applications with secrets from 1Password"',
        '  homepage "https://github.com/curtisgalloway/op-go"',
        f'  version "{tag[1:]}"',
        '  license "Apache-2.0"',
        "",
        "  bottle do",
        f'    root_url "{base}"',
    ]
    for target, name in zip(("all", "x86_64_linux", "arm64_linux"), names[3:]):
        lines.append(
            f'    sha256 cellar: :any_skip_relocation, {target}: "{hashes[name]}"'
        )
    lines.extend(["  end", ""])
    for platform, targets in (
        ("macos", (("arm", names[0]), ("intel", names[0]))),
        ("linux", (("arm", names[2]), ("intel", names[1]))),
    ):
        lines.append(f"  on_{platform} do")
        for architecture, name in targets:
            lines.extend(
                [
                    f"    on_{architecture} do",
                    f'      url "{base}/{name}"',
                    f'      sha256 "{hashes[name]}"',
                    "    end",
                ]
            )
        lines.extend(["  end", ""])
    lines.append("""  def install
    bin.install "op-go"
    doc.install "README.md", "LICENSE"
  end

  def caveats
    <<~EOS
      Enroll your service-account token with `op-go enroll` from a terminal.
      Start that shell without OP_SERVICE_ACCOUNT_TOKEN in its environment.
      macOS uses Keychain; Linux uses the desktop Secret Service by default.
    EOS
  end

  test do
    ENV.delete("OP_SERVICE_ACCOUNT_TOKEN")
    assert_match version.to_s, shell_output("#{bin}/op-go --version")
    assert_match "op-go", shell_output("#{bin}/op-go --skill")
    output = shell_output("#{bin}/op-go doctor --backend file --token-file #{testpath}/missing --json", 3)
    assert_equal false, JSON.parse(output).fetch("ok")
    (testpath/"app.env").write("EXAMPLE=op://fake-vault/fake-item/key\\n")
    output = shell_output("#{bin}/op-go dry-run --backend file --token-file #{testpath}/missing " \\
                          "--env-file #{testpath}/app.env --json -- /usr/bin/true")
    assert_equal true, JSON.parse(output).fetch("ok")
  end
end
""")
    return "\n".join(lines)


def generate(tag, assets, output):
    """Verify all inputs and refuse downgrades before replacing the formula."""
    target = version_tuple(tag)
    if output.exists():
        match = re.search(
            r'^  version "([0-9]+\.[0-9]+\.[0-9]+)"$', output.read_text(), re.M
        )
        if not match:
            raise ValueError("existing formula has no recognizable version")
        if target < version_tuple("v" + match[1]):
            raise ValueError("refusing to downgrade existing formula")
    hashes = {name: verified_hash(assets, name) for name in asset_names(tag)}
    content = render(tag, hashes)
    output.write_text(content, encoding="utf-8")


def main():
    """Parse arguments and report failures without printing local paths."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--assets", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        generate(args.tag, args.assets, args.output)
    except (OSError, UnicodeError, ValueError) as error:
        message = (
            str(error)
            if isinstance(error, ValueError)
            else "cannot read/write release inputs"
        )
        print(f"op-go pin failed: {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
