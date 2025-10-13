{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    btop
    file
    git
    kitty.terminfo
  ];
}
