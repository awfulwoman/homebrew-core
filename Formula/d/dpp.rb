class Dpp < Formula
  desc "Directly include C headers in D source code"
  homepage "https://github.com/atilaneves/dpp"
  url "https://github.com/atilaneves/dpp.git",
      tag:      "v0.6.0",
      revision: "9c2b175b32cc46581a94a7ee1c0026f0cda045fc"
  license "BSL-1.0"

  bottle do
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "7969f210787e31cf942b1f00f2146e876631d93aff67dc03feb17611640d252d"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "af3e31ce2aad958fdf07894e5004dbca6b4b0a12ecc54afab388d53021a58816"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "c9b3fe563032fb43cb4c924feb9c81b718047a80f1ea8aecb057203786098e66"
    sha256 cellar: :any_skip_relocation, sonoma:         "6f340275745bf2313d40b8a68273f885bfcc7c6ca90e313ce26ada3a9db8629d"
    sha256 cellar: :any_skip_relocation, ventura:        "f309a79d35c6143155f8f4bc19a82d1851520121a80ba8e5c3a83baa9a9e09c8"
    sha256 cellar: :any_skip_relocation, monterey:       "bc1e96e9d138f332a1a24d3ba39cdfa444b7a9d834e3df558a401492f8765b20"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "1a73c14e28ff376415c7550e127afcdf1b0ed55503c45f3dfcc0a44ee3b068bb"
  end

  depends_on "dtools" => :build
  depends_on "dub" => :build
  depends_on "ldc" => [:build, :test]

  uses_from_macos "llvm" # for libclang

  # Match versions from dub.selections.json
  # VERSION=#{version} && curl https://raw.githubusercontent.com/atilaneves/dpp/v$VERSION/dub.selections.json
  resource "libclang" do
    url "https://code.dlang.org/packages/libclang/0.3.3.zip"
    sha256 "281b1b02f96c06ef812c7069e6b7de951f10c9e1962fdcfead367f9244e77529"
  end

  resource "sumtype" do
    url "https://code.dlang.org/packages/sumtype/1.2.8.zip"
    sha256 "fd273e5b4f97ef6b6f08f9873f7d1dd11da3b9f0596293ba901be7caac05747f"
  end

  resource "unit-threaded" do
    url "https://code.dlang.org/packages/unit-threaded/2.1.9.zip"
    sha256 "1e06684e7f542e2c3d20f3b0f6179c16af2d80806a3a322d819aec62b6446d74"
  end

  def install
    resources.each do |r|
      r.stage buildpath/"dub-packages"/r.name
      system "dub", "add-local", buildpath/"dub-packages"/r.name, r.version.to_s
    end
    # Avoid linking brew LLVM on Intel macOS
    inreplace "dub-packages/libclang/dub.sdl", %r{^lflags "-L/usr/local/opt/llvm/lib"}, "//\\0"

    if OS.mac?
      toolchain_paths = []
      toolchain_paths << MacOS::CLT::PKG_PATH if MacOS::CLT.installed?
      toolchain_paths << MacOS::Xcode.toolchain_path if MacOS::Xcode.installed?
      dflags = toolchain_paths.flat_map do |path|
        %W[
          -L-L#{path}/usr/lib
          -L-rpath
          -L#{path}/usr/lib
        ]
      end
      ENV["DFLAGS"] = dflags.join(" ")
    end
    system "dub", "add-local", buildpath
    system "dub", "build", "--skip-registry=all", "dpp"
    bin.install "bin/d++"
  end

  test do
    (testpath/"c.h").write <<~EOS
      #define FOO_ID(x) (x*3)
      int twice(int i);
    EOS

    (testpath/"c.c").write <<~EOS
      int twice(int i) { return i * 2; }
    EOS

    (testpath/"foo.dpp").write <<~EOS
      #include "c.h"
      void main() {
          import std.stdio;
          writeln(twice(FOO_ID(5)));
      }
    EOS

    system ENV.cc, "-c", "c.c"
    system bin/"d++", "--compiler=ldc2", "foo.dpp", "c.o"
    assert_match "30", shell_output("./foo")
  end
end
