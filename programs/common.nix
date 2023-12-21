{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    home-manager
    git
    kitty.terminfo
  ];
}
