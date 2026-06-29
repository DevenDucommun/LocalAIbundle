class Localaibundle < Formula
  desc "Fully local AI coding stack installer for macOS Apple Silicon"
  homepage "https://github.com/DevenDucommun/LocalAIbundle"
  url "https://github.com/DevenDucommun/LocalAIbundle/releases/download/v1.1.0/LocalAIbundle-1.1.0.tar.gz"
  sha256 "c1291ef10d907735e2095c79b5f2c38309f8ff6360cb74a6c4f0173102cb6a2b"
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
