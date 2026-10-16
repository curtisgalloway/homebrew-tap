# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0

# A binary formula: it pours the prebuilt, corpus-tested tarball from the
# qbranch release rather than building from source, one url per
# architecture. No bottle, no Rust dependency, no `head`; `cargo install
# qbranch` covers anyone who wants a source build. On Linux it pours the
# static musl tarballs, which run on any distribution; Debian-family hosts
# can take the .deb from the releases page instead. bump-qbranch-formula.yml
# rewrites the version line and all four url/sha256 pairs on each release.
class Qbranch < Formula
  desc "Outfits a machine's coding agents from a per-machine manifest"
  homepage "https://github.com/curtisgalloway/qbranch"
  version "0.6.0"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/curtisgalloway/qbranch/releases/download/v0.6.0/qbranch-v0.6.0-aarch64-apple-darwin.tar.gz"
      sha256 "6c28519121f622773c47e32d18e88fdcaf3ffc899a443ef2a8dd4a2dc1cc2089"
    end
    on_intel do
      url "https://github.com/curtisgalloway/qbranch/releases/download/v0.6.0/qbranch-v0.6.0-x86_64-apple-darwin.tar.gz"
      sha256 "5a73622140d832d0a26e62a051a23ee3dc2cb843e26d25bb488fbd6cb275dd25"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/curtisgalloway/qbranch/releases/download/v0.6.0/qbranch-v0.6.0-aarch64-unknown-linux-musl.tar.gz"
      sha256 "2541893469669d243538c1221d5fb198a7055277d07e897ab496c9580cf8ff9a"
    end
    on_intel do
      url "https://github.com/curtisgalloway/qbranch/releases/download/v0.6.0/qbranch-v0.6.0-x86_64-unknown-linux-musl.tar.gz"
      sha256 "aedf0f05ef8abae43e5fee15f23ee995fede97ba266365e8420679d9c5ccdcff"
    end
  end

  def install
    bin.install "qbranch"
    # The tool's own bundled skills, beside bin as on every other channel. Tarballs carry skills/ from 0.3.1 on; the guard
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
