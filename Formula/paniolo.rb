# Copyright 2026 Curtis Galloway
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class Paniolo < Formula
  desc "Agent-controlled target machine wrangler for distributed bring-up"
  homepage "https://github.com/curtisgalloway/paniolo"
  version "0.1.18"
  license "Apache-2.0"

  # --HEAD: build from a git checkout, for anyone hacking on paniolo itself.
  # Only this spec needs a toolchain — the stable spec below never does. Must
  # come before the on_macos/on_linux blocks: `brew style`'s ComponentsOrder
  # cop wants `head` first among these top-level stanzas.
  head do
    url "https://github.com/curtisgalloway/paniolo.git", branch: "main"

    depends_on "rust" => :build

    on_linux do
      depends_on "cmake" => :build
      depends_on "nasm" => :build
      depends_on "pkg-config" => :build
    end
  end

  # Stable: pour the prebuilt, release-tested tarballs — no toolchain, no
  # build. `scripts/repin.sh vX.Y.Z` rewrites this version and all three
  # url/sha256 pairs on each release; see that script and AGENTS.md.
  #
  # The macOS tarball is a single universal (arm64 + x86_64) binary, so
  # on_arm/on_intel below pin the *same* url/sha256 twice rather than once
  # under a bare on_macos block: `brew style`'s ComponentsOrder cop rejects
  # `url`/`sha256` as direct children of on_macos/on_linux (only on_arch,
  # on_intel and a handful of other DSL calls are allowed there) — they must
  # be one level deeper, under an on_arm/on_intel/on_system block. repin.sh
  # rewrites both copies together, matched by filename, so they can't drift.
  on_macos do
    on_arm do
      url "https://github.com/curtisgalloway/paniolo/releases/download/v0.1.18/paniolo-0.1.18-macos-universal.tar.gz"
      sha256 "c809f43769871f6272d810b35e122f6058b0c26642b79e9d331a5fd5fd0a376b"
    end
    on_intel do
      url "https://github.com/curtisgalloway/paniolo/releases/download/v0.1.18/paniolo-0.1.18-macos-universal.tar.gz"
      sha256 "c809f43769871f6272d810b35e122f6058b0c26642b79e9d331a5fd5fd0a376b"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/curtisgalloway/paniolo/releases/download/v0.1.18/paniolo-0.1.18-linux-arm64.tar.gz"
      sha256 "de16e4cd2ae1724f62947a02efb7e6a51ab14165e66e0fe763df8938c6c48a12"
    end
    on_intel do
      url "https://github.com/curtisgalloway/paniolo/releases/download/v0.1.18/paniolo-0.1.18-linux-amd64.tar.gz"
      sha256 "903e65830f1abf10efc8bbcba795d881406c0ebc990b0b9dbdd676fcfe4ff091"
    end
  end

  def install
    if build.head?
      # Only the CLI lands on PATH; the helpers are paniolo's private plumbing,
      # installed into the keg's libexec/bin where the CLI finds them via its
      # exe-relative lookup (../libexec/bin from the resolved binary).
      system "cargo", "install", *std_cargo_args(path: "cli")

      helpers = %w[hdmicap serialcap netbootd cambrionix hidrig ch9329 shellyplug amt]
      helpers.each do |helper|
        system "cargo", "install", *std_cargo_args(root: libexec, path: helper)
      end

      if OS.mac?
        system "swiftc", "-O", "-o", libexec/"bin/visionocr", "ocr/visionocr.swift"
      else
        (libexec/"bin").install "ocr/linuxocr"
      end

      # Bundled agent skills (`paniolo skill`): the CLI reads them from
      # <keg>/share/paniolo/skills — the exe-relative share lookup in
      # cli/src/skills.rs (canonicalizes the binary, so they must live in the
      # keg, not just the opt-linked prefix). Mirror the repo's
      # skills/<name>/SKILL.md layout. Globbed so new skills need no formula edit
      # (unlike the .deb's nfpm manifest, which lists one entry per skill).
      Dir["skills/*/SKILL.md"].each do |manifest|
        name = File.basename(File.dirname(manifest))
        (pkgshare/"skills"/name).install manifest
      end
    elsif OS.mac?
      # macOS release tarball: already laid out exactly as the keg wants it —
      # bin/, libexec/bin/, share/paniolo/skills/ — so this is a straight
      # copy. Universal (arm64 + x86_64) binary, no arch split needed.
      bin.install "bin/paniolo"
      (libexec/"bin").install Dir["libexec/bin/*"]
      (pkgshare/"skills").install Dir["share/paniolo/skills/*"]
    else
      # Linux release tarball: flat — the CLI, every helper, and both OCR
      # binaries sit next to each other with no bin/libexec split, and skills
      # live under skills/ rather than share/paniolo/skills/.
      bin.install "paniolo"
      helpers = %w[hdmicap serialcap netbootd cambrionix hidrig ch9329 shellyplug amt linuxocr rapidocr]
      (libexec/"bin").install helpers
      (pkgshare/"skills").install Dir["skills/*"]
    end
  end

  def caveats
    <<~EOS
      Run `paniolo setup` once to finish platform setup (on macOS this
      installs the netbootd BPF helper with its set-user-ID bit on — one
      sudo prompt; re-run it after `brew upgrade paniolo`, since an upgrade
      clears that bit).

      Helpers are private to paniolo in:
        #{opt_libexec}/bin
      (found automatically; run one directly with `paniolo helper <name> ...`).

      The optional zigplug Zigbee helper is a Python uv tool — install it
      from a source checkout via `paniolo setup`.

      Bundled agent skills are available via `paniolo skill` (no arg lists
      them; a name prints that skill's SKILL.md).

      Linux: `brew install` pours the same prebuilt binaries as macOS — no
      Rust toolchain needed. The .deb on GitHub Releases is an alternative if
      you'd rather not use brew:
        https://github.com/curtisgalloway/paniolo/releases
    EOS
  end

  test do
    assert_match "paniolo", shell_output("#{bin}/paniolo --help")
    assert_predicate libexec/"bin/serialcap", :executable?
    assert_path_exists pkgshare/"skills/paniolo/SKILL.md"
    assert_match "paniolo", shell_output("#{bin}/paniolo skill")

    if OS.mac? && !build.head?
      lipo_info = shell_output("lipo -info #{bin}/paniolo")
      assert_match "x86_64", lipo_info
      assert_match "arm64", lipo_info
    end
  end
end
