{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bind # dig, nslookup
    btop
    ethtool
    file
    git
    iperf3
    nmap
    socat
    tmux
    wireguard-tools
    (if stdenv.isDarwin then ghostty-bin else ghostty).terminfo
  ];
}
