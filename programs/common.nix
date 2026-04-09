{ specialArgs, lib, pkgs, ... }:

let
  btop' = pkgs.btop.overrideAttrs (prev: {
    src = pkgs.fetchFromGitHub {
      owner = "aristocratos";
      repo = "btop";
      rev = "6164470cb8ed316accc2b5662dadee49036f9b49";
      hash = "sha256-daVlChULDoMEMqIlJi8TeJa+7IGqC8y0kLQI6i9uyks=";
    };
    patches = (prev.patches or []) ++ [
      (pkgs.fetchpatch {
        name = "remove-terminal-size-limit.patch";
        url = "https://github.com/usertam/btop/commit/4d9671f905881ade6c3a0e9a8118c663fc941e83.patch";
        hash = "sha256-riq+nNllVCHapqTRPt8ict8UNg8o+Z0Ik2iaW6lHwmM=";
      })
      (pkgs.fetchpatch {
        name = "change-default-theme-background-to-false.patch";
        url = "https://github.com/usertam/btop/commit/e37aa387c6702cdf6ece63fadda65e61262f9f9b.patch";
        hash = "sha256-9bpcwZXW/+Tz7tq5XjbDNrKQEkUG4hhb+CMsP+/Ny9E=";
      })
    ];
  });
in

{
  environment.systemPackages = with pkgs; [
    bind # dig, nslookup
    btop'
    file
    gptfdisk
    gnupg
    iperf3
    pciutils
    nmap
    socat
    tcpdump
    usbutils
    wireguard-tools
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    ethtool
    nftables
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
