class Lotio < Formula
  desc "High-performance Lottie animation frame renderer using Skia. Renders animations to PNG frames for video encoding."
  homepage "https://github.com/matrunchyk/lotio"
  url "https://github.com/matrunchyk/lotio/archive/refs/tags/v1.1.88.tar.gz"
  # Note: SHA256 is automatically calculated and updated by dawidd6/action-homebrew-bump-formula
  # in the Homebrew tap repository (matrunchyk/homebrew-lotio). This file is just a template.
  sha256 "7be41221602c0e8ff76ee388179d011b170353d51f18f4194b5bc1b61fa0cd9f"  # Auto-updated in tap
  version "1.1.88"
  license "MIT"
  
  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end
  
  bottle do
    root_url "https://github.com/matrunchyk/lotio/releases/download/v1.1.88"
    sha256 arm64_big_sur: "d57a226e17850ded7bff267c4d8393bf26587190ffa66150ef61763f63342b26"  # Auto-updated
  end
  
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "harfbuzz"
  depends_on "icu4c"
  depends_on "libpng"

  def install
    # If you need to build from source, use the build scripts from the repository:
    # https://github.com/matrunchyk/lotio/blob/main/scripts/build_binary.sh
    
    odie <<~EOS
      Building from source is not supported via Homebrew.
      
      Pre-built bottles are available for all releases. If the bottle is not available
      for your system, please:
      1. Check that you're installing a released version (not HEAD)
      2. Report the issue at https://github.com/matrunchyk/lotio/issues
      3. For development builds, clone the repository and use ./scripts/build_binary.sh
    EOS
  end

  def caveats
    <<~EOS
      This formula installs:
      - Binary: #{bin}/lotio
      - Headers: #{include}/lotio/ and #{include}/skia/
      - Libraries: #{lib}/liblotio.a and Skia static libraries
      - pkg-config: #{lib}/pkgconfig/lotio.pc

      To use in C++ projects:
        #include <lotio/core/animation_setup.h>
        #include <skia/core/SkCanvas.h>
        
        Compile with:
        g++ -I#{include} -L#{lib} -llotio -lskottie -lskia ...
        
        Or use pkg-config:
        g++ $(pkg-config --cflags --libs lotio) ...
    EOS
  end

  test do
    # Test binary
    system "#{bin}/lotio", "--version"
    
    # Test that headers are installed
    assert_predicate include/"lotio/core/animation_setup.h", :exist?
    assert_predicate include/"lotio/text/text_processor.h", :exist?
    assert_predicate include/"skia/core/SkCanvas.h", :exist?
    
    # Test that libraries are installed
    assert_predicate lib/"liblotio.a", :exist?
    assert_predicate lib/"libskottie.a", :exist?
    
    # Test pkg-config
    system "pkg-config", "--exists", "lotio"
    assert_equal shell_output("pkg-config --modversion lotio").strip, version.to_s
  end
end
