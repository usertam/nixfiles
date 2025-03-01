{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git kitty.terminfo
  ];
}
