{ specialArgs, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bind # dig, nslookup
    btop
    file
    gptfdisk
    iperf3
    nmap
    socat
    wireguard-tools
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    ethtool
    ghostty.terminfo
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    ghostty-bin.terminfo
  ];

  programs = {
    tmux = {
      enable = true;
      extraConfig = ''
        set -g mouse on
        set -g status-style bg=default,fg=green
      '';
    };
  } 
  # Hack around nix.linux-builder with specialArgs and system.
  // lib.optionalAttrs (lib.hasAttr "system" specialArgs && lib.hasSuffix "-linux" specialArgs.system) {
    git = {
      enable = true;
      config = {
        user.name = "Samuel Tam";
        user.email = "code@usertam.dev";
        commit.gpgSign = true;
      };
    };
  };
}
