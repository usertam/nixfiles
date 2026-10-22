{ lib, pkgs, system, ... }:

{
  environment.systemPackages =
    let
      btop' = pkgs.btop.overrideAttrs (prev: {
        patches = (prev.patches or [ ]) ++ [
          (pkgs.fetchpatch {
            name = "remove-terminal-size-limit.patch";
            url = "https://github.com/usertam/btop/commit/4d9671f905881ade6c3a0e9a8118c663fc941e83.patch";
            hash = "sha256-riq+nNllVCHapqTRPt8ict8UNg8o+Z0Ik2iaW6lHwmM=";
          })
        ];
        postPatch = (prev.postPatch or "") + ''
          substituteInPlace src/btop_config.cpp \
            --replace-fail '{"theme_background", true},' '{"theme_background", false},' \
            --replace-fail '{"proc_per_core", false},' '{"proc_per_core", true},'
        '';
      });
    in
    with pkgs;
    [
      bind # dig, nslookup
      btop'
      file
      gptfdisk
      gnupg
      iperf3
      jq
      lsof
      pciutils
      nmap
      socat
      tcpdump
      usbutils
      wireguard-tools
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      conntrack-tools
      ethtool
      nftables
      ghostty.terminfo
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
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
  // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
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
