{ config, ... }:

{
  imports = [
    ./common/darwin.nix
  ];

  # Host identity.
  networking.hostName = "gale";

  # Prohibit self-login via SSH.
  users.sshUsers = [ ];

  # Set darwin dock icons.
  system.defaults.dock.persistent-apps = map (app: { inherit app; }) [
    "/System/Applications/Launchpad.app"
    "/System/Cryptexes/App/System/Applications/Safari.app"
    "${config.system.primaryUserHome}/Applications/Home Manager Apps/VSCodium.app"
    "${config.system.primaryUserHome}/Applications/Home Manager Apps/Ghostty.app"
    "/Applications/Spotify.app"
  ];
}
