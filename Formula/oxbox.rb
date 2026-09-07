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

class Oxbox < Formula
  desc "Supervised harness for running an untrusted LLM against real code"
  homepage "https://github.com/curtisgalloway/oxbox"
  version "1.0.1"
  license "Apache-2.0"

  # --HEAD: build the Rust workspace from a git checkout, for anyone hacking
  # on oxbox itself. Only this spec needs a toolchain; the stable spec below
  # never does. Must come before the on_macos/on_linux blocks: `brew style`'s
  # ComponentsOrder cop wants `head` first among these top-level stanzas.
  head do
    url "https://github.com/curtisgalloway/oxbox.git", branch: "main"

    depends_on "rust" => :build
  end

  # Stable: pour the prebuilt, release-tested tarballs -- no toolchain, no
  # build. `REPIN_PROJECT=oxbox scripts/repin.sh vX.Y.Z` rewrites this
  # version and all the url/sha256 pairs on each release, after verifying
  # each asset's `.sha256` sidecar on the release; see that script.
  #
  # The macOS tarball is a single universal (arm64 + x86_64) build, so
  # on_arm/on_intel below pin the *same* url/sha256 twice rather than once
  # under a bare on_macos block: `brew style`'s ComponentsOrder cop rejects
  # `url`/`sha256` as direct children of on_macos/on_linux -- they must be
  # one level deeper, under an on_arm/on_intel block. repin.sh rewrites both
  # copies together, matched by filename, so they cannot drift.
  on_macos do
    on_arm do
      url "https://github.com/curtisgalloway/oxbox/releases/download/v1.0.1/oxbox-1.0.1-macos-universal.tar.gz"
      sha256 "d20e010b40e0d4b2eff616ca4d9a18974a0eee24e707bd49002d5d77dff8d07d"
    end
    on_intel do
      url "https://github.com/curtisgalloway/oxbox/releases/download/v1.0.1/oxbox-1.0.1-macos-universal.tar.gz"
      sha256 "d20e010b40e0d4b2eff616ca4d9a18974a0eee24e707bd49002d5d77dff8d07d"
    end
  end

  on_linux do
    # The Linux jail backend. Without it oxbox refuses to run -- deliberately,
    # there is no "best effort" mode.
    depends_on "bubblewrap"

    on_arm do
      url "https://github.com/curtisgalloway/oxbox/releases/download/v1.0.1/oxbox-1.0.1-linux-arm64.tar.gz"
      sha256 "9efa2032be847642c3c791b255d72541eae40864ff46db7e7d6697d9a20c7150"
    end
    on_intel do
      url "https://github.com/curtisgalloway/oxbox/releases/download/v1.0.1/oxbox-1.0.1-linux-amd64.tar.gz"
      sha256 "81788ed6d47fbfb6196be7ee4f5caf4eb9c29f58ff701a4d3c8eb106c8e10f92"
    end
  end

  def install
    if build.head?
      # oxbox is the one command on PATH; the four helpers it runs live off
      # PATH in the keg's libexec/bin, where oxbox finds them at ../libexec/bin
      # from its own real location (Homebrew links bin/ and share/ into the
      # prefix but never libexec/, and helper_dirs resolves the symlink before
      # walking up). `oxbox <sub>` execs oxbox-<sub>; `oxbox helper <sub>`
      # runs one directly.
      system "cargo", "install", *std_cargo_args(path: "crates/oxbox")
      %w[oxbox-sandbox oxbox-send oxbox-patch oxbox-jail].each do |helper|
        system "cargo", "install", *std_cargo_args(root: libexec, path: "crates/#{helper}")
      end
      # The seatbelt profile (macOS jail) and the ox-review skill, resolved
      # from the executable: ../share/oxbox from bin, or two levels up from
      # libexec/bin. Without the skill every tool refuses --skill.
      pkgshare.install "profiles/jail.sb"
      pkgshare.install ".claude/skills/ox-review"
      doc.install "README.md", "AGENTS.md"
      (doc/"docs").install "docs/comparison.md"
    else
      # The release tarballs are laid out exactly as the keg wants them --
      # bin/, libexec/bin/, share/oxbox/, share/doc/oxbox/ -- on macOS and
      # Linux alike, so this is a straight copy.
      bin.install "bin/oxbox"
      (libexec/"bin").install Dir["libexec/bin/*"]
      pkgshare.install Dir["share/oxbox/*"]
      doc.install Dir["share/doc/oxbox/*"]
    end
  end

  def caveats
    <<~EOS
      The tools operate on the current directory: oxbox sandbox builds
      ./sandbox, oxbox send logs to ./logs, oxbox jail runs in ./sandbox/work
      -- stand in your project directory. Only oxbox is on PATH; `oxbox helper`
      lists the executables it runs for you.

      The jail verification suites assert against a source checkout's layout;
      to verify the jail on this machine:
        git clone https://github.com/curtisgalloway/oxbox
        cd oxbox && python3 guardtest.py

      Linux: `brew install` pours the same prebuilt binaries as macOS -- no
      Rust toolchain needed. bubblewrap needs unprivileged user namespaces;
      some hardened distros (and Ubuntu 24.04's AppArmor default) restrict
      them. The .deb on GitHub Releases is the better-tested Linux path:
        https://github.com/curtisgalloway/oxbox/releases
    EOS
  end

  test do
    assert_path_exists pkgshare/"jail.sb"
    assert_path_exists pkgshare/"ox-review/SKILL.md"
    assert_match "oxbox #{version}", shell_output("#{bin}/oxbox --version")
    # Through the front door: each subcommand has to find its executable in
    # the keg's libexec from the linked bin/oxbox, which is the lookup this
    # formula's layout exists to satisfy.
    assert_match "oxbox-send #{version}", shell_output("#{bin}/oxbox send --version")
    assert_match "oxbox-patch #{version}", shell_output("#{bin}/oxbox patch --version")
    assert_match "oxbox-sandbox #{version}", shell_output("#{bin}/oxbox sandbox --version")
    assert_match "oxbox-jail #{version}", shell_output("#{bin}/oxbox jail --version")
    assert_match "oxbox-send #{version}", shell_output("#{bin}/oxbox helper send --version")
    # --skill has to print the runbook with THIS prefix's script paths, or
    # the commands an agent reads are commands it cannot run. All five tools
    # answer it, so all five get asked.
    forms = {
      "oxbox"   => "--skill",
      "sandbox" => "helper sandbox --skill",
      "send"    => "helper send --skill",
      "patch"   => "helper patch --skill",
      "jail"    => "helper jail --skill",
    }
    forms.each do |tool, form|
      skill = shell_output("#{bin}/oxbox #{form}")
      assert_match "name: ox-review", skill, "#{tool} --skill"
      assert_match((pkgshare/"ox-review/scripts").to_s, skill, "#{tool} --skill")
    end
    # The dry run needs no key or network and proves working-directory
    # anchoring: the log must land in testpath, not anywhere exe-relative.
    # --model is explicit because no venue carries a default.
    system bin/"oxbox", "send", "--model", "smoke-test", "--mode", "ask", "--dry-run", "hello"
    assert_predicate testpath/"logs", :directory?

    if OS.mac? && !build.head?
      lipo_info = shell_output("lipo -info #{bin}/oxbox")
      assert_match "x86_64", lipo_info
      assert_match "arm64", lipo_info
    end
  end
end
