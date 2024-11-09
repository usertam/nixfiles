{ lib, pkgs, ... }:

let
  kitty.terminfo = pkgs.stdenv.mkDerivation {
    pname = pkgs.kitty.pname + "-terminfo";
    version = pkgs.kitty.version;
    src = pkgs.kitty.src;
    buildInputs = [ pkgs.ncurses ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/terminfo
      tic -x -o$out/share/terminfo $src/terminfo/kitty.terminfo
    '';
  };
in {
  environment.systemPackages = [ pkgs.git kitty.terminfo ];
}
