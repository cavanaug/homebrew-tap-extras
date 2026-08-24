# typed: true
# frozen_string_literal: true

class MermaidAscii < Formula
  desc "Render Mermaid diagrams as ASCII in the terminal"
  homepage "https://github.com/AlexanderGrooff/mermaid-ascii"
  version "1.5.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Darwin_arm64.tar.gz"
      sha256 "2e0ba0d7c2b91d36a09d033a3e24e002c7ef0291e51063b8c8c0852739a10712"
    else
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Darwin_x86_64.tar.gz"
      sha256 "388b02f0cf467c0eeba8bfe9809186eca76c4e9a39f64c74b38747f311a1277d"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Linux_arm64.tar.gz"
      sha256 "517c560dbeee2042e67748b618fce75c77f5a502d82f436c0642224d9f65f507"
    else
      url "https://github.com/AlexanderGrooff/mermaid-ascii/releases/download/#{version}/mermaid-ascii_Linux_x86_64.tar.gz"
      sha256 "386a9311d04cbba6acdeda78ebf51d87fdc849dcbca86481ce3af9d2241ce203"
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
