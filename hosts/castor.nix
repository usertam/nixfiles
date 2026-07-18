{ lib, ... }:

{
  imports = [
    ./common/ec2-ami.nix
    ../services/coturn.nix
    ../services/derper.nix
    ../services/tailscale.nix
    ../services/upgrade.nix
  ];

  # Set up swapfile.
  swapDevices = [
    { device = "/var/lib/swapfile"; size = 2 * 1024; }
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 500 "castor";
}
