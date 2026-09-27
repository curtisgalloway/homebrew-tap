# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0

# A binary formula: it pours the prebuilt, corpus-tested tarball from the
# qbranch release rather than building from source, one url per
# architecture. No bottle, no Rust dependency, no `head`; `cargo install
# qbranch` covers anyone who wants a source build. macOS only: Linux users
# take the .deb from the releases page. bump-qbranch-formula.yml rewrites the
# version line and both url/sha256 pairs on each release.
class Qbranch < Formula
  desc "Outfits a machine's coding agents from a per-machine manifest"
  homepage "https://github.com/curtisgalloway/qbranch"
  version "0.5.0"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/curtisgalloway/qbranch/releases/download/v0.5.0/qbranch-v0.5.0-aarch64-apple-darwin.tar.gz"
      sha256 "ca9b552e20b02d40fb93a18e152eb8fcde9a3af66b9756a157e94770d7d37b33"
    end
    on_intel do
      url "https://github.com/curtisgalloway/qbranch/releases/download/v0.5.0/qbranch-v0.5.0-x86_64-apple-darwin.tar.gz"
      sha256 "d503135fc76db62134d70167fc9b12063566e0aa0c7b0d8ae25b9492898e123e"
    end
  end

  def install
    bin.install "qbranch"
    # The tool's own two skills (review-plugins, agent-audit), beside bin as
    # on every other channel. Tarballs carry skills/ from 0.3.1 on; the guard
    # covers the 0.3.0 pin and can go once the pin has moved past it.
    (share/"qbranch").install "skills" if File.directory?("skills")
    doc.install "README.md"
  end

  def caveats
    <<~EOS
      Point qbranch at your config root once; the root and the manifest name
      are remembered, so afterwards a plain `qbranch` re-syncs:
        qbranch --root ~/src/my-agent-config --manifest <name>
    EOS
  end

  test do
    assert_match "qbranch #{version}", shell_output("#{bin}/qbranch --version")
    # A dry run against a real, if empty, manifest: proves the binary runs
    # and reads a config root, and changes nothing.
    (testpath/"root/manifests").mkpath
    (testpath/"root/manifests/test.json").write '{"schema": 2, "name": "test"}'
    system bin/"qbranch", "--root", testpath/"root", "--manifest", "test", "--dry-run"
  end
end
