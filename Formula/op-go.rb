# SPDX-FileCopyrightText: 2026 Curtis Galloway
# SPDX-License-Identifier: Apache-2.0

class OpGo < Formula
  desc "Launch applications with secrets from 1Password"
  homepage "https://github.com/curtisgalloway/op-go"
  version "0.1.0"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/curtisgalloway/op-go/releases/download/v0.1.0"
    sha256 cellar: :any_skip_relocation, all:          "296b6576745e1f06a6983845f9f105ac87f1a576ac9eca0c02c8854c40ea64d7"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "fdb2af9805f86a9755f70db7acb5269e4ae8142354a188468a92dc22318df4f4"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "6060849e47845919835665bbf861bee91728c72eb32823c555a398e69ad47a24"
  end

  on_macos do
    on_arm do
      url "https://github.com/curtisgalloway/op-go/releases/download/v0.1.0/op-go-v0.1.0-darwin-universal.tar.gz"
      sha256 "30f443091ad5b36cc056baa284df25038b46f6682fe509b62767c3319a9f5f96"
    end
    on_intel do
      url "https://github.com/curtisgalloway/op-go/releases/download/v0.1.0/op-go-v0.1.0-darwin-universal.tar.gz"
      sha256 "30f443091ad5b36cc056baa284df25038b46f6682fe509b62767c3319a9f5f96"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/curtisgalloway/op-go/releases/download/v0.1.0/op-go-v0.1.0-linux-arm64.tar.gz"
      sha256 "6e08d127c1002a3fd155ca6bd1ed8654354a997ce29b46d1dec3c677170d1dab"
    end
    on_intel do
      url "https://github.com/curtisgalloway/op-go/releases/download/v0.1.0/op-go-v0.1.0-linux-amd64.tar.gz"
      sha256 "0b847a6ef0260098f7b5a959e044b777aea96f359125e8e6ca7190ca91e80bc4"
    end
  end

  def install
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
    (testpath/"app.env").write("EXAMPLE=op://fake-vault/fake-item/key\n")
    output = shell_output("#{bin}/op-go dry-run --backend file --token-file #{testpath}/missing " \
                          "--env-file #{testpath}/app.env --json -- /usr/bin/true")
    assert_equal true, JSON.parse(output).fetch("ok")
  end
end
