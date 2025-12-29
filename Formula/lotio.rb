class Lotio < Formula
  desc "High-performance Lottie animation frame renderer using Skia"
  homepage "https://github.com/matrunchyk/lotio"
  url "https://github.com/matrunchyk/lotio/archive/refs/tags/v1.1.0.tar.gz"
  # Note: SHA256 is automatically calculated and updated by dawidd6/action-homebrew-bump-formula
  # in the Homebrew tap repository (matrunchyk/homebrew-lotio). This file is just a template.
  sha256 "1a096ffc65a9c416597c74901cb6c68a2c139e6b3df469a99beded5d04542ca2"  # Auto-updated in tap
  version "1.1.0"
  license "MIT"
  depends_on "ninja" => :build
  depends_on "python@3.11" => :build
  depends_on "git" => :build
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "icu4c"
  depends_on "libpng"
  depends_on "jpeg-turbo"
  depends_on "webp"
  depends_on "harfbuzz"

  def install
    # Fetch Skia first (not included in source archive)
    mkdir_p "third_party/skia"
    cd "third_party/skia" do
      system "git", "clone", "--depth", "1", "https://skia.googlesource.com/skia.git"
      cd "skia" do
        # Retry git-sync-deps as it can fail due to network issues
        retries = 3
        begin
          system "python3", "tools/git-sync-deps"
        rescue
          retries -= 1
          if retries > 0
            sleep 2
            retry
          else
            raise
          end
        end
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

