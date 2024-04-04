{ lib, pkgs, ... }:

let
  kitty = pkgs.kitty.overrideAttrs (_: {
    doCheck = false;
    doInstallCheck = false;
  });
in {
  environment.systemPackages = [ pkgs.git kitty.terminfo ];
}
