{ config, lib, pkgs, inputs, ... }:

{
  # Import common modules, for darwin.
  imports = [
    ../../programs/common.nix
    ../../programs/nix.nix
    ../../programs/nix-no-gc.nix
    ../../programs/tmux.nix
    ../../programs/zsh.nix
    ../../services/darwin-builder.nix
    ../../services/openssh.nix
    ../../services/tailscale.nix
  ];

  # Override darwin-rebuild in systemPackages.
  # Also, I want coreutils in /nix/var/nix/profiles/system/sw/bin.
  environment.systemPackages =
    let
      darwin-rebuild' = pkgs.runCommand "darwin-rebuild" {
        src = [ inputs.darwin.packages.${pkgs.stdenv.hostPlatform.system}.darwin-rebuild ];
        meta.priority = -10;
      } ''
        cp -a $src $out
        chmod +w $out/bin $out/bin/darwin-rebuild
        sed -i 's+^flake=+flake=${config.environment.darwinConfig}+' $out/bin/darwin-rebuild
      '';
    in
    [
      darwin-rebuild'
      pkgs.coreutils
    ];

  # Override default system profiles.
  environment.profiles = lib.mkForce [
    "$HOME/.nix-profile"
    "/run/current-system/sw" # was: /nix/var/nix/profiles/system/sw
    "/nix/var/nix/profiles/default"
  ];

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
