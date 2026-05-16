# typed: true
# frozen_string_literal: true

class MermaidAscii < Formula
  desc "Render Mermaid diagrams as ASCII in the terminal"
  homepage "https://github.com/AlexanderGrooff/mermaid-ascii"
  version "1.2.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Darwin_arm64.tar.gz"
      sha256 "61b6f53a45c81a11c43994fa111b214fa96a27610b09b2f23b2f1644adaf60f0"
    else
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Darwin_x86_64.tar.gz"
      sha256 "3eff96d6feca8de351ec5fe77c5b781bc0e159345b535807fde121731c0054c2"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Linux_arm64.tar.gz"
      sha256 "3517e43d6d8732c7bc4f1f0cd894a79793488292817d590dad60a7211e622f4f"
    else
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Linux_x86_64.tar.gz"
      sha256 "e0752558626b924b1198470ce57eb9aa580522c22e3138e4b48dc5e60f3943c7"
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
