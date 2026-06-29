class Localaibundle < Formula
  desc "Fully local AI coding stack installer for macOS Apple Silicon"
  homepage "https://github.com/DevenDucommun/LocalAIbundle"
  url "https://github.com/DevenDucommun/LocalAIbundle/releases/download/v1.1.0/LocalAIbundle-1.1.0.tar.gz"
  sha256 "4fc98ff254074cd2c88f73b4f1dc73423cfab785dd695fedddcb2b21a953514f"
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
