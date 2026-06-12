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
  url "https://github.com/curtisgalloway/paniolo/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "9ada1aeb2da8f003a7c588027c7c74331962318de39cfd2a07f890e0c1b35b1b"
  license "Apache-2.0"
  head "https://github.com/curtisgalloway/paniolo.git", branch: "main"

  depends_on "rust" => :build

  on_linux do
    depends_on "cmake" => :build
    depends_on "nasm" => :build
    depends_on "pkg-config" => :build
  end

  def install
    # Only the CLI lands on PATH; the helpers are paniolo's private plumbing,
    # installed into the keg's libexec/bin where the CLI finds them via its
    # exe-relative lookup (../libexec/bin from the resolved binary).
    system "cargo", "install", *std_cargo_args(path: "cli")

    helpers = %w[hdmicap serialcap netbootd cambrionix hidrig ch9329 usbhub shellyplug]
    helpers.each do |helper|
      system "cargo", "install", *std_cargo_args(root: libexec, path: helper)
    end

    if OS.mac?
      system "swiftc", "-O", "-o", libexec/"bin/visionocr", "ocr/visionocr.swift"
    else
      (libexec/"bin").install "ocr/linuxocr"
    end
  end

  def caveats
    <<~EOS
      Helpers are private to paniolo in:
        #{opt_libexec}/bin
      (found automatically; run one directly with `paniolo helper <name> ...`).

      macOS: the netbootd raw-frame (BPF) send path needs its helper
      setuid-root once:
        sudo chown root #{opt_libexec}/bin/netbootd-bpf-helper
        sudo chmod u+s #{opt_libexec}/bin/netbootd-bpf-helper

      The optional zigplug Zigbee helper is a Python uv tool — install it
      from a source checkout via `paniolo setup`.

      Linux: prebuilt .debs on GitHub Releases are the better-tested path:
        https://github.com/curtisgalloway/paniolo/releases
    EOS
  end

  test do
    assert_match "paniolo", shell_output("#{bin}/paniolo --help")
    assert_predicate libexec/"bin/serialcap", :executable?
  end
end
