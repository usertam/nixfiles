{ pkgs, ... }:

{
  # Set time zone.
  time.timeZone = "Hongkong";

  # Define global user defaults.
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;
  };

  # Database compatibility defaults.
  system.stateVersion = "23.11";
}
