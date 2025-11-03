{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    btop
    file
    git
    tmux
    (if stdenv.isDarwin then ghostty-bin else ghostty).terminfo
  ];
}
