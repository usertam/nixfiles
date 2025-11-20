{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    btop
    file
    git
    socat
    tmux
    (if stdenv.isDarwin then ghostty-bin else ghostty).terminfo
  ];
}
