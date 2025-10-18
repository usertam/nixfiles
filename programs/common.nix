{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    btop
    file
    git
    (if pkgs.stdenv.isDarwin then ghostty-bin else ghostty).terminfo
  ];
}
