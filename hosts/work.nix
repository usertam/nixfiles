{ config, ... }:

{
  imports = [
    ./common/darwin.nix
  ];

  # Host identity.
  networking.hostName = "work";

  # Set primary user.
  system.primaryUser = "samueltam";

  # Prohibit self-login via SSH.
  users.sshUsers = [ ];

  # Always caffeinate.
  launchd.daemons.caffeinate = {
    script = "/usr/bin/caffeinate -disu";
    serviceConfig = {
      Label = "org.nixos.caffeinate";
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # Set darwin dock icons.
  system.defaults.dock.persistent-apps = map (app: { inherit app; }) [
    "/System/Applications/Launchpad.app"
    "/System/Cryptexes/App/System/Applications/Safari.app"
    "${config.system.primaryUserHome}/Applications/Home Manager Apps/VSCodium.app"
    "${config.system.primaryUserHome}/Applications/Home Manager Apps/Ghostty.app"
    "${config.system.primaryUserHome}/Applications/Home Manager Apps/Slack.app"
  ];
}
