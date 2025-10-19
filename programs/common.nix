{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    btop
    file
    git
    (if stdenv.isDarwin then ghostty-bin else ghostty).terminfo
  ];
}
