require 'formula'

class MacvimAlloy < Formula
  homepage 'https://github.com/alloy/macvim/wiki'
  head 'https://github.com/alloy/macvim.git', :branch => 'split-browser'

  options "custom-icons", "Try to generate custom document icons."
  options "override-system-vim", "Override system vim"
  options "with-cscope", "Build with Cscope support"
  options "with-lua", "Build with Lua scripting support"
  options "with-envycoder", "Build with Envy Code R Bold font."
  options "enable-clipboard", "Enable System clipboard handling in the terminal"

  depends_on 'cscope' if build.include? 'with-cscope'
  depends_on 'lua' if build.include? 'with-lua'

  depends_on :xcode # For xcodebuild.

  def install
    # Set ARCHFLAGS so the Python app (with C extension) that is
    # used to create the custom icons will not try to compile in
    # PPC support (which isn't needed in Homebrew-supported systems.)
    arch = MacOS.prefer_64_bit? ? 'x86_64' : 'i386'
    ENV['ARCHFLAGS'] = "-arch #{arch}"

    # If building for 10.8, make sure that CC is set to "clang".
    # Reference: https://github.com/b4winckler/macvim/wiki/building
    ENV['CC'] = "clang" if MacOS.version >= :mountain_lion

    args = %W[
      --with-features=huge
      --with-tlib=ncurses
      --enable-multibyte
      --with-macarchs=#{arch}
      --enable-perlinterp
      --enable-pythoninterp
      --enable-rubyinterp
      --enable-tclinterp
      --with-ruby-command=/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby
    ]

    args << "--enable-cscope" if build.include? "with-cscope"

    if build.include? "with-lua"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    system "./configure", *args

    # Building custom icons fails for many users, so off by default.
    unless build.include? "custom-icons"
      inreplace "src/MacVim/icons/Makefile", "$(MAKE) -C makeicns", ""
      inreplace "src/MacVim/icons/make_icons.py", "dont_create = False", "dont_create = True"
    end

    # Reference: https://github.com/b4winckler/macvim/wiki/building
    cd 'src/MacVim/icons' do
      system "make getenvy"
    end

    unless build.include? "with-envycoder"
      # Remove the font from the build dependencies
      inreplace "src/MacVim/icons/Makefile",
        '$(OUTDIR)/MacVim-generic.icns: make_icons.py vim-noshadow-512.png loadfont.so Envy\ Code\ R\ Bold.ttf',
        '$(OUTDIR)/MacVim-generic.icons: make_icons.py vim-noshadow-512.png loadfont.so'
    end

    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    inreplace "src/MacVim/mvim", /^# VIM_APP_DIR=\/Applications$/,
                                 "VIM_APP_DIR=#{prefix}"
    bin.install "src/MacVim/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    executables = %w[mvimdiff mview mvimex]
    executables += %w[vi vim vimdiff view vimex] if build.include? "override-system-vim"
    executables.each {|f| ln_s bin+'mvim', bin+f}
  end

  def caveats; <<-EOS.undent
    MacVim.app installed to:
      #{prefix}

    To link the application to a normal Mac OS X location:
        brew linkapps
    or:
        ln -s #{prefix}/MacVim.app /Applications
    EOS
  end
end
