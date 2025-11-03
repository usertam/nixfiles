{ config, lib, pkgs, modulesPath, ... }:

{
  # Import common modules.
  imports = [
    ../programs/common.nix
    ../programs/nix.nix
    ../programs/tmux.nix
    ../programs/zsh.nix
    ../services/openssh.nix
    ../services/rsyncd.nix
    ../services/tailscale.nix
  ];

  # Set time zone.
  time.timeZone = "Hongkong";

  # Define global user defaults.
  users.mutableUsers = false;

  # Set default login user root.
  services.getty.autologinUser = lib.mkDefault "root";

  # Hacky way to prepend to the default `system.nixos.tags`.
  system.nixos.label = "usertam-"
    + (import "${modulesPath}/misc/label.nix" { inherit config lib; }).config.system.nixos.label.content;

  # Database compatibility defaults.
  system.stateVersion = (lib.mkOverride 900) "24.05";
}
