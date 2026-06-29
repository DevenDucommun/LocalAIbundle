class Localaibundle < Formula
  desc "Fully local AI coding stack installer for macOS Apple Silicon"
  homepage "https://github.com/DevenDucommun/LocalAIbundle"
  url "https://github.com/DevenDucommun/LocalAIbundle/releases/download/v1.0.0/LocalAIbundle-1.0.0.tar.gz"
  sha256 "ad9604a9a8e53e7e57506354e827b090e56f984513c92f8149e38df0a78fcc09"
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
