# typed: true
# frozen_string_literal: true

class CopilotApi < Formula
  desc "Turn GitHub Copilot into an OpenAI/Anthropic-compatible API server"
  homepage "https://github.com/caozhiyuan/copilot-api"
  url "https://registry.npmjs.org/@jeffreycao/copilot-api/-/copilot-api-1.14.18.tgz"
  sha256 "c986bc666af6a46ef1dca4f99149c43afe5db76733c2f26cd2df6c724a7bb1ee"
  license "MIT"

  livecheck do
    url "https://registry.npmjs.org/@jeffreycao/copilot-api/latest"
    regex(/["']version["']:\s*["'](\d+(?:\.\d+)+)["']/i)
  end

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec.glob("bin/*")

    (share/"copilot-api").mkpath
    (share/"copilot-api/copilot-api.service").write <<~EOS
      [Unit]
      Description=copilot-api — GitHub Copilot OpenAI/Anthropic-compatible proxy
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=simple
      EnvironmentFile=-%h/.config/copilot-api/env
      ExecStart=#{bin}/copilot-api start
      Restart=on-failure
      RestartSec=5

      [Install]
      WantedBy=default.target
    EOS
  end

  def post_install
    # Restart the user systemd service only if it is both enabled and currently running,
    # so the new binary is picked up without affecting stopped or disabled installs.
    if OS.linux?
      enabled = quiet_system "systemctl", "--user", "is-enabled", "--quiet", "copilot-api"
      active  = quiet_system "systemctl", "--user", "is-active",  "--quiet", "copilot-api"
      if enabled && active
        ohai "Restarting copilot-api user service..."
        system "systemctl", "--user", "restart", "copilot-api"
      end
    end
  end

  test do
    assert_match "copilot-api", shell_output("#{bin}/copilot-api --help 2>&1")
  end
end
