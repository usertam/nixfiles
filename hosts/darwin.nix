{ lib, config, pkgs, inputs, ... }:

{
  # Use a custom configuration.nix location.
  environment.darwinConfig = "$HOME/Desktop/projects/nixfiles";

  # Override darwin-rebuild in systemPackages.
  environment.systemPackages = lib.singleton (pkgs.runCommand "darwin-rebuild" {
    src = [ inputs.darwin.packages.${pkgs.system}.darwin-rebuild ];
    meta.priority = -10;
  } ''
    cp -a $src $out
    chmod +w $out/bin $out/bin/darwin-rebuild
    sed -i 's+^flake=+flake=${config.environment.darwinConfig}+' $out/bin/darwin-rebuild
  '');

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
