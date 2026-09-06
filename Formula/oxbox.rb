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
  url "https://github.com/curtisgalloway/oxbox/archive/refs/tags/v0.7.0.tar.gz"
  sha256 "21b5f24f33a3a451fa64bb46c5753dfa5a1f6668b8b353170d29d4aa7913b461"
  license "Apache-2.0"
  head "https://github.com/curtisgalloway/oxbox.git", branch: "main"

  on_linux do
    # The Linux jail backend. Without it oxbox refuses to run — deliberately,
    # there is no "best effort" mode.
    depends_on "bubblewrap"
  end

  def install
    # Two layouts, one formula. From the release after 0.6.0, oxbox is the one
    # command and the four scripts it runs live off PATH in the keg's libexec:
    # oxbox finds them at ../libexec/bin from its own real location (Homebrew
    # links bin/ and share/ into the prefix but never libexec/, and
    # helper_dirs resolves the symlink before walking up); `oxbox <sub>` execs
    # oxbox-<sub> and `oxbox helper <sub>` runs one directly. Up to 0.6.0 the
    # tarball has four tools that all go on PATH. Keying on the file rather
    # than the version lets this land ahead of the release and survive the
    # automated re-pin unchanged.
    if File.exist?("oxbox-send")
      bin.install "oxbox"
      (libexec/"bin").install "oxbox-sandbox", "oxbox-send", "oxbox-patch", "oxbox-jail"
    else
      bin.install "ox", "oxbox", "oxapply", "oxseed"
    end
    # The seatbelt profile (macOS jail), resolved from the script: ../share/oxbox
    # from bin, or two levels up from libexec/bin — see find_profile.
    pkgshare.install "profiles/jail.sb"
    # The ox-review skill, resolved the same script-relative way by find_skill,
    # which every tool carries a copy of. Without it every one of them refuses
    # --skill, so a tap that ships only the executables leaves a broken flag on
    # a supported install path. The .deb ships it to /usr/share/oxbox/ox-review
    # for the same reason.
    pkgshare.install ".claude/skills/ox-review"
    doc.install "README.md", "AGENTS.md"
  end

  def front_door?
    (libexec/"bin/oxbox-send").exist?
  end

  def caveats
    if front_door?
      <<~EOS
        The tools are pure Python (3.9+, the system python3 works) and operate
        on the current directory: oxbox sandbox builds ./sandbox, oxbox send
        logs to ./logs, oxbox jail runs in ./sandbox/work — stand in your
        project directory. Only oxbox is on PATH; `oxbox helper` lists the
        scripts it runs for you.

        The jail verification suites assert against a source checkout's layout;
        to verify the jail on this machine:
          git clone https://github.com/curtisgalloway/oxbox
          cd oxbox && python3 guardtest.py

        Linux: bubblewrap needs unprivileged user namespaces; some hardened
        distros (and Ubuntu 24.04's AppArmor default) restrict them. The .deb
        on GitHub Releases is the better-tested Linux path:
          https://github.com/curtisgalloway/oxbox/releases
      EOS
    else
      <<~EOS
        The tools are pure Python (3.9+, the system python3 works) and operate
        on the current directory: oxseed builds ./sandbox, ox logs to ./logs,
        oxbox jails into ./sandbox/work — stand in your project directory.

        The jail verification suites assert against a source checkout's layout;
        to verify the jail on this machine:
          git clone https://github.com/curtisgalloway/oxbox
          cd oxbox && python3 guardtest.py

        Linux: bubblewrap needs unprivileged user namespaces; some hardened
        distros (and Ubuntu 24.04's AppArmor default) restrict them. The .deb
        on GitHub Releases is the better-tested Linux path:
          https://github.com/curtisgalloway/oxbox/releases
      EOS
    end
  end

  test do
    assert_path_exists pkgshare/"jail.sb"
    assert_path_exists pkgshare/"ox-review/SKILL.md"
    if front_door?
      assert_match "oxbox 0", shell_output("#{bin}/oxbox --version")
      # Through the front door: each subcommand has to find its script in the
      # keg's libexec from the linked bin/oxbox, which is the lookup this
      # formula's layout exists to satisfy.
      assert_match "oxbox-send 0", shell_output("#{bin}/oxbox send --version")
      assert_match "oxbox-patch 0", shell_output("#{bin}/oxbox patch --version")
      assert_match "oxbox-sandbox 0", shell_output("#{bin}/oxbox sandbox --version")
      assert_match "oxbox-jail 0", shell_output("#{bin}/oxbox jail --version")
      assert_match "oxbox-send 0", shell_output("#{bin}/oxbox helper send --version")
      # --skill has to print the runbook with THIS prefix's script paths, or
      # the commands an agent reads are commands it cannot run.
      # find_skill/print_skill is duplicated per tool by design, so all five
      # get asked.
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
      # anchoring: the log must land in testpath, not anywhere script-relative.
      # --model is explicit because no venue carries a default.
      system bin/"oxbox", "send", "--model", "smoke-test", "--mode", "ask", "--dry-run", "hello"
    else
      assert_match "ox 0", shell_output("#{bin}/ox --version")
      assert_match "oxbox 0", shell_output("#{bin}/oxbox --version")
      assert_match "oxapply 0", shell_output("#{bin}/oxapply --version")
      assert_match "oxseed 0", shell_output("#{bin}/oxseed --version")
      %w[ox oxbox oxapply oxseed].each do |tool|
        skill = shell_output("#{bin}/#{tool} --skill")
        assert_match "name: ox-review", skill
        assert_match((pkgshare/"ox-review/scripts").to_s, skill)
      end
      # --model is explicit: 0.6.0 dropped the default model, and this asserts
      # where the log lands, not how a model is chosen.
      system bin/"ox", "--model", "smoke-test", "--mode", "ask", "--dry-run", "hello"
    end
    assert_predicate testpath/"logs", :directory?
  end
end
