{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bind # dig, nslookup
    btop
    file
    git
    iperf3
    nmap
    socat
    tmux
    wireguard-tools
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    ethtool
    ghostty.terminfo
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    ghostty-bin.terminfo
  ];
}
