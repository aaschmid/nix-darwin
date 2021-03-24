{ stdenv, lib, pkgs, userName, varDir ? "/Users/${userName}/.local/share/homebrew", ... }:

# assert user != null;

stdenv.mkDerivation rec {
  pname = "brew";
  version = "3.0.5";

  src = pkgs.fetchurl {
    url = "https://github.com/Homebrew/brew/tarball/${version}";
    name = "${pname}-${version}.tar.gz";
    hash = "sha256:1likxalr10b5ja2j6ibz52zyhcy796z77m98cr4y7y0hzni0x1cz";
  };

  inherit varDir;

  doCheck = true;

  # TODO only checked while building the package but not at the time of using it -> prefer that
  checkPhase = ''
    if ! [ -d "$varDir" ]; then
      echo "error: 'varDir' does not exist or is not accessible (set to $varDir)."
      exit 1
    fi

    dirs=("tmp" "var" "Caskroom" "Cellar" "Taps")
    for dir in "''${dirs[@]}"; do
      if ! [ -d "$varDir/$dir" ]; then
        echo "error: 'varDir' must contain accessible folders for mutable but persistent data: ''${dirs[@]}."
        echo "       Reason: homebrew usually uses its home directory for mutable data which does not fit to nix philosophie."
        echo "  - '$dir' not existing or accessible."
        exit 1
      fi
    done
  '';

  # TODO manpages/ -> how to generate and where to put man page is located?
  # TODO completions/ -> required and where to put?
  installPhase = ''
    runHook preInstall

    echo using varDir $varDir

    mkdir -p $out/{bin,org}
    cp -a bin/brew $out/bin/brew
    cp -a Library/ manpages/ $out

    # Symlink all required mutable folders to $varDir
    ln -s {$varDir,$out}/var
    ln -s {$varDir,$out}/Caskroom
    # TODO really required? and for what?
    ln -s {$varDir,$out}/Cellar
    ln -s {$varDir,$out/Library}/Taps

    # TODO better place for mutable and permanent $varDir and create it and it's required folders
    # chmod 777 -R $varDir

    # TODO test if below below works also without Xcode installed... or manipulate Xcode path
    # Replace tools curl, git and ruby with one from nixpkgs
    sed -i "294d" $out/Library/Homebrew/brew.sh
    sed -i "294i \ \ HOMEBREW_CURL=\"${pkgs.curl}/bin/curl\"" $out/Library/Homebrew/brew.sh
    sed -i "306d" $out/Library/Homebrew/brew.sh
    sed -i "306i \ \ HOMEBREW_GIT=\"${pkgs.git}/bin/git\"" $out/Library/Homebrew/brew.sh
    sed -i "46a \ \ export HOMEBREW_RUBY_PATH=\"${pkgs.ruby}/bin/ruby\"\n  return\n" $out/Library/Homebrew/utils/ruby.sh

    # Remove block 22ff because line 23 and 24 cause errors like "compgen: not a shell builtin"
    sed -i "22,30d" $out/bin/brew

    # Remove check that brew package dir is not writable and update of `brew` itself
    sed -i "356,365d" $out/Library/Homebrew/cmd/update.sh
    sed -i "345,354d" $out/Library/Homebrew/cmd/update.sh
    sed -i "28,46d" $out/Library/Homebrew/cmd/update.sh

    # Replace tmp files for update task, usually part of `.git` folder
    sed -i 's#update_failed_file=".*"#update_failed_file="$varDir/tmp/HOMEBREW_UPDATE_FAILED"#' $out/Library/Homebrew/cmd/update.sh
    sed -i 's#missing_remote_ref_dirs_file=".*"#missing_remote_ref_dirs_file="$varDir/tmp/HOMEBREW_FAILED_FETCH_DIRS"#' $out/Library/Homebrew/cmd/update.sh
    sed -i 's#tmp_failure_file=".*"#tmp_failure_file="$varDir/tmp/HOMEBREW_FETCH_FAILURES"#' $out/Library/Homebrew/cmd/update.sh

    # remove update-report for `brew` itself and linkage of updated manpages and docs
    sed -i "171d" $out/Library/Homebrew/cmd/update-report.rb
    sed -i "78,98d" $out/Library/Homebrew/cmd/update-report.rb

    # remove failure of access check -> required by brew upgrade and brew outdated
    sed -i "365,375d" $out/Library/Homebrew/diagnostic.rb

    runHook postInstall
  '';

  meta = with lib; {
    description = "The Missing Package Manager for macOS (or Linux)";
    homepage = "https://brew.sh/";
    license = licenses.bsd2;
    # maintainers = with maintainers; [ aaschmid ];
    platforms = platforms.darwin;
  };
}
