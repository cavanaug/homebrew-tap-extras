# typed: true
# frozen_string_literal: true

class CopilotApi < Formula
  desc "Turn GitHub Copilot into an OpenAI/Anthropic-compatible API server"
  homepage "https://github.com/caozhiyuan/copilot-api"
  url "https://github.com/caozhiyuan/copilot-api/archive/refs/tags/v1.9.15.tar.gz"
  sha256 "db5b4c9c094e4183d880deda0e4aa99ab09e18d39f7d39059b38f2506b5b35ad"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "oven-sh/bun/bun"

  def install
    system "bun", "install", "--frozen-lockfile"
    system "bun", "run", "build"

    # tsdown code-splits but does not bundle node_modules — runtime needs them.
    # pages/ must be a sibling of dist/ under libexec — server.ts resolves
    # pages/index.html via new URL("../pages/index.html", import.meta.url)
    libexec.install "dist", "pages", "node_modules"

    (bin/"copilot-api").write <<~EOS
      #!/bin/bash
      exec "#{Formula["oven-sh/bun/bun"].opt_bin}/bun" "#{libexec}/dist/main.js" "$@"
    EOS

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
