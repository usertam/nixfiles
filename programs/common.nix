{ lib, pkgs, system, ... }:

{
  environment.systemPackages =
    let
      btop' = pkgs.btop.overrideAttrs (prev: {
        patches = (prev.patches or [ ]) ++ [
          (pkgs.fetchpatch {
            name = "remove-terminal-size-limit.patch";
            url = "https://github.com/usertam/btop/commit/85c1c7568ab08818526f85057919a04c2d6e5dd1.patch";
            hash = "sha256-q6SjePiygFv/cYqzniOM5MZPkmMvAZ1B5aEW0wWSQos=";
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
