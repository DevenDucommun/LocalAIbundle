class Localaibundle < Formula
  desc "Fully local AI coding stack installer for macOS Apple Silicon"
  homepage "https://github.com/DevenDucommun/LocalAIbundle"
  url "https://github.com/DevenDucommun/LocalAIbundle/releases/download/v1.1.0/LocalAIbundle-1.1.0.tar.gz"
  sha256 "5daaefad2cbf263c31f5c3bdea2e89903ef8c8ba08cc5ab173fb2fc22c7f81ce"
  license "MIT"

  depends_on "python@3.13"

  def install
    libexec.install Dir["*"]
    bin.write_exec_script libexec/"bin/localaibundle"
  end

  test do
    system bin/"localaibundle", "--version"
    system bin/"localaibundle", "self-test", "--dry-run", "--no-network"
  end
end
