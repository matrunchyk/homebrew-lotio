class Lotio < Formula
  desc "High-performance Lottie animation frame renderer using Skia"
  homepage "https://github.com/matrunchyk/lotio"
  url "https://github.com/matrunchyk/lotio/archive/refs/tags/v20260101-48fa84c.tar.gz"
  # Note: SHA256 is automatically calculated and updated by dawidd6/action-homebrew-bump-formula
  # in the Homebrew tap repository (matrunchyk/homebrew-lotio). This file is just a template.
  sha256 "bcd0325899b581e47ff76d5f49cc5cb099704c31a7fb0c2f36ce451cf18f23cf"  # Auto-updated in tap
  version "20260101-48fa84c"
  license "MIT"
  
  # Bottle (pre-built binary) - much faster than building from source
  bottle do
    root_url "https://github.com/matrunchyk/lotio/releases/download/v20260101-48fa84c"
    sha256 arm64_big_sur: "070a7e1564c666fc2a12b97f7336390a0025986edb91b8be50f05b9d41749c35"  # Auto-updated
  end
  
  # Only build dependencies needed if bottle is not available
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "icu4c"
  depends_on "libpng"
  depends_on "jpeg-turbo"
  depends_on "webp"
  depends_on "harfbuzz"

  def install
    # If bottle is available, Homebrew will use it automatically
    # This install method is only used as fallback when bottle is not available
    
    # Fetch Skia first (not included in source archive)
    mkdir_p "third_party/skia"
    cd "third_party/skia" do
      system "git", "config", "--global", "advice.detachedHead", "false"
      system "git", "clone", "--depth", "1", "https://skia.googlesource.com/skia.git"
      cd "skia" do
        # Use custom sync script instead of broken tools/git-sync-deps
        # Parse DEPS file and clone externals with retry logic
        system "bash", "-c", <<~EOS
          # Get absolute path to skia directory
          SKIA_ROOT="$(pwd)"
          mkdir -p "$SKIA_ROOT/third_party/externals"
          grep '\"third_party/externals/' DEPS | while IFS= read -r line; do
            name=\$(echo "\$line" | sed -n 's/.*"third_party\\/externals\\/\\([^"]*\\)".*/\\1/p')
            url_commit=\$(echo "\$line" | sed -n 's/.*: "\\([^"]*\\)".*/\\1/p')
            if [ -z "\$name" ] || [ -z "\$url_commit" ]; then
              continue
            fi
            url=\$(echo "\$url_commit" | sed 's/@.*//')
            commit=\$(echo "\$url_commit" | sed 's/.*@//')
            if [ -d "$SKIA_ROOT/third_party/externals/\$name" ]; then
              echo "  ✓ \$name already exists, skipping"
              continue
            fi
            echo "  Cloning \$name..."
            cd "$SKIA_ROOT/third_party/externals"
            success=false
            for attempt in 1 2 3; do
              if git clone "\$url" "\$name" 2>&1; then
                success=true
                break
              else
                if [ \$attempt -lt 3 ]; then
                  echo "    Attempt \$attempt failed, retrying in 5 seconds..."
                  sleep 5
                fi
              fi
            done
            if [ "\$success" = true ] && [ -d "\$name" ]; then
              cd "\$name"
              git checkout "\$commit" 2>&1 || echo "    Warning: Failed to checkout \$commit"
            else
              echo "  ✗ Failed to clone \$name after 3 attempts"
              exit 1
            fi
            cd "$SKIA_ROOT"
          done
        EOS
      end
    end
    
    # Build Skia
    cd "third_party/skia/skia" do
      system "python3", "bin/fetch-gn"
      
      # Configure GN args for macOS
      # Use Hardware::CPU.arm? for reliable ARM detection
      target_cpu = Hardware::CPU.arm? ? "arm64" : "x64"
      gn_args = [
        "target_cpu=\"#{target_cpu}\"",
        "is_official_build=true",
        "is_debug=false",
        "skia_enable_skottie=true",
        "skia_enable_fontmgr_fontconfig=true",
        "skia_enable_fontmgr_custom_directory=true",
        "skia_use_freetype=true",
        "skia_use_libpng_encode=true",
        "skia_use_libpng_decode=true",
        "skia_use_libwebp_decode=true",
        "skia_use_wuffs=true",
        "skia_enable_pdf=false"
      ]
      
      # Add Homebrew include and library paths for macOS
      if OS.mac?
        homebrew_prefix = HOMEBREW_PREFIX
        freetype_include = "#{Formula["freetype"].opt_include}/freetype2"
        icu_include = "#{Formula["icu4c"].opt_include}"
        icu_lib = "#{Formula["icu4c"].opt_lib}"
        harfbuzz_include = "#{Formula["harfbuzz"].opt_include}/harfbuzz"
        harfbuzz_lib = "#{Formula["harfbuzz"].opt_lib}"
        freetype_lib = "#{Formula["freetype"].opt_lib}"
        
        gn_args << "extra_cflags=[\"-O3\", \"-march=native\", \"-I#{homebrew_prefix}/include\", \"-I#{freetype_include}\", \"-I#{icu_include}\", \"-I#{harfbuzz_include}\"]"
        gn_args << "extra_asmflags=[\"-I#{homebrew_prefix}/include\", \"-I#{freetype_include}\", \"-I#{icu_include}\", \"-I#{harfbuzz_include}\"]"
        gn_args << "extra_ldflags=[\"-L#{icu_lib}\", \"-L#{harfbuzz_lib}\", \"-L#{freetype_lib}\", \"-L#{homebrew_prefix}/lib\"]"
      end
      
      system "bin/gn", "gen", "out/Release", "--args=#{gn_args.join(' ')}"
      
      # Build gen/skia.h explicitly before full build (prevents CI failures)
      system "ninja", "-C", "out/Release", "gen/skia.h"
      
      system "ninja", "-C", "out/Release"
    end

    # Build lotio (we're back in the source root after the cd blocks)
    # Set environment variables for Homebrew library paths
    icu_prefix = Formula["icu4c"].opt_prefix
    ENV["HOMEBREW_PREFIX"] = HOMEBREW_PREFIX.to_s
    ENV["ICU_PREFIX"] = icu_prefix.to_s
    system "./build_local.sh"
    
    # Install binary
    bin.install "lotio"
    
    # Install headers (for library distribution)
    include.install Dir["src/core/*.h"] => "lotio/core"
    include.install Dir["src/text/*.h"] => "lotio/text"
    include.install Dir["src/utils/*.h"] => "lotio/utils"
    
    # Install Skia static libraries (for programmatic use)
    skia_lib_dir = "third_party/skia/skia/out/Release"
    %w[skottie skia skparagraph sksg skshaper skunicode_icu skunicode_core skresources jsonreader].each do |lib_name|
      lib_file = "#{skia_lib_dir}/lib#{lib_name}.a"
      lib.install lib_file if File.exist?(lib_file)
    end
    
    # Create and install pkg-config file
    (lib/"pkgconfig").mkpath
    pkgconfig_content = <<~EOF
      prefix=#{HOMEBREW_PREFIX}
      exec_prefix=${prefix}
      libdir=${exec_prefix}/lib
      includedir=${prefix}/include
      
      Name: lotio
      Description: High-performance Lottie animation frame renderer using Skia
      Version: #{version}
      Libs: -L${libdir} -lskottie -lskia -lskparagraph -lsksg -lskshaper -lskunicode_icu -lskunicode_core -lskresources -ljsonreader
      Cflags: -I${includedir}
    EOF
    (lib/"pkgconfig"/"lotio.pc").write(pkgconfig_content)
  end

  test do
    # Test that the binary works
    system "#{bin}/lotio", "--help"
  end
end
