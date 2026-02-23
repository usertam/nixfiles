{ ... }:

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
}
