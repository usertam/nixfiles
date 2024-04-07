{ lib, pkgs, ... }:

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

  # Database compatibility defaults.
  system.stateVersion = "23.11";
}
