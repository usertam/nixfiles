{ config, lib, pkgs, modulesPath, ... }:

{
  # Set time zone.
  time.timeZone = "Hongkong";

  # Define permissible login shells.
  environment.shells = lib.singleton pkgs.zsh;

  # Define global user defaults.
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;
  };

  # For clout purposes. Intend to add this to `system.nixos.tags`, but it will be sorted and be last.
  system.nixos.label = "usertam-"
    + (import "${modulesPath}/misc/label.nix" { inherit config lib; }).config.system.nixos.label.content;

  # Database compatibility defaults.
  system.stateVersion = "24.05";
}
