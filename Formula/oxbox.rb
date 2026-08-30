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
  url "https://github.com/curtisgalloway/oxbox/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "58784f4186ca31afbc4cee287a6bb73d1d6fdf5d5d4cb6c6ffcea4bd9416237d"
  license "Apache-2.0"
  head "https://github.com/curtisgalloway/oxbox.git", branch: "main"

  on_linux do
    # The Linux jail backend. Without it oxbox refuses to run — deliberately,
    # there is no "best effort" mode.
    depends_on "bubblewrap"
  end

  def install
    bin.install "ox", "oxbox", "oxapply", "oxseed"
    # The seatbelt profile (macOS jail). oxbox resolves it exe-relative:
    # ../share/oxbox/jail.sb from the installed binary — see find_profile.
    (share/"oxbox").install "profiles/jail.sb"
    # The ox-review skill, resolved the same exe-relative way by find_skill --
    # ../share/oxbox/ox-review -- which all four tools carry a copy of. Without
    # it every one of them refuses --skill, so a tap that ships only the four
    # executables leaves a broken flag on a supported install path. The .deb
    # ships it to /usr/share/oxbox/ox-review for the same reason.
    (share/"oxbox").install ".claude/skills/ox-review"
    doc.install "README.md", "AGENTS.md"
  end

  def caveats
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

  test do
    assert_match "ox 0", shell_output("#{bin}/ox --version")
    assert_match "oxbox 0", shell_output("#{bin}/oxbox --version")
    assert_match "oxapply 0", shell_output("#{bin}/oxapply --version")
    assert_match "oxseed 0", shell_output("#{bin}/oxseed --version")
    assert_path_exists share/"oxbox/jail.sb"
    assert_path_exists share/"oxbox/ox-review/SKILL.md"
    # --skill has to print the runbook with THIS prefix's script paths, or the
    # commands an agent reads are commands it cannot run. find_skill/print_skill
    # is duplicated per tool by design, so all four get asked.
    %w[ox oxbox oxapply oxseed].each do |tool|
      skill = shell_output("#{bin}/#{tool} --skill")
      assert_match "name: ox-review", skill
      assert_match((share/"oxbox/ox-review/scripts").to_s, skill)
    end
    # The dry run needs no key or network and proves working-directory
    # anchoring: the log must land in testpath, not anywhere script-relative.
    system bin/"ox", "--mode", "ask", "--dry-run", "hello"
    assert_predicate testpath/"logs", :directory?
  end
end
