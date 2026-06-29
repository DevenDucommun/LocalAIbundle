class Localaibundle < Formula
  desc "Fully local AI coding stack installer for macOS Apple Silicon"
  homepage "https://github.com/DevenDucommun/LocalAIbundle"
  url "https://github.com/DevenDucommun/LocalAIbundle/releases/download/v1.1.1/LocalAIbundle-1.1.1.tar.gz"
  sha256 "2f373e97d924a7cdded104668252ff68ba2923972eb79c7274dd84b733639094"
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
