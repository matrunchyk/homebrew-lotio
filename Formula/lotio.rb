class Lotio < Formula
  desc "High-performance Lottie animation frame renderer using Skia"
  homepage "https://github.com/matrunchyk/lotio"
  url "https://github.com/matrunchyk/lotio/archive/refs/tags/v1.1.15.tar.gz"
  # Note: SHA256 is automatically calculated and updated by dawidd6/action-homebrew-bump-formula
  # in the Homebrew tap repository (matrunchyk/homebrew-lotio). This file is just a template.
  sha256 "9317a34d59f80bb2b2398b8c4f3e07ee461ff4179572fc7ed5db65226d0e19cd"  # Auto-updated in tap
  version "1.1.15"
  license "MIT"
  
  # Bottle (pre-built binary) - much faster than building from source
  bottle do
    root_url "https://github.com/matrunchyk/lotio/releases/download/v1.1.15"
    sha256 arm64_big_sur: "700354c109ccb7b949c5968d90ccc83d31ee6fa20b0dd629f5c253e7e0bd5465"  # Auto-updated
  end
  
  # Runtime dependencies (bottles are always provided, so build deps not needed)
  # These are listed for documentation purposes
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "icu4c"
  depends_on "libpng"
  depends_on "harfbuzz"

  def install
    # Bottles are always provided for releases, so this method should rarely be called.
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

  test do
    # Test that the binary works
    system "#{bin}/lotio", "--help"
  end
end
