# typed: true
# frozen_string_literal: true

class MermaidAscii < Formula
  desc "Render Mermaid diagrams as ASCII in the terminal"
  homepage "https://github.com/AlexanderGrooff/mermaid-ascii"
  version "1.4.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Darwin_arm64.tar.gz"
      sha256 "bdaa335ac574828645ac22bc381460f55c0170a3bb1c3f9037df986fa31bec57"
    else
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Darwin_x86_64.tar.gz"
      sha256 "f718ec6e186952803a9fd06d84307c108208877576534b65fc57fbb5ec2fd9d9"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Linux_arm64.tar.gz"
      sha256 "b256faf57feea83058a4bfcdedffd60a3724c47b7d2f096207c7a55f51d387d5"
    else
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Linux_x86_64.tar.gz"
      sha256 "a59974c74e3fddfd040f80618a0f7eae535ebe58d91aa1d8d876bc99815dc037"
    end
  end

  def install
    bin.install "mermaid-ascii"
    doc.install "README.md", "LICENSE" if File.exist?("README.md")
  end

  test do
    (testpath/"test.mmd").write <<~EOS
      graph LR
      A --> B
    EOS

    output = shell_output("#{bin}/mermaid-ascii --file #{testpath}/test.mmd")
    assert_match "A", output
    assert_match "B", output
  end
end
