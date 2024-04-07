{ pkgs, ... }:

{
  # Use a custom configuration.nix location.
  environment.darwinConfig = "$HOME/Desktop/projects/nixfiles/flake.nix";

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Enable tailscaled.
  services.tailscale.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
