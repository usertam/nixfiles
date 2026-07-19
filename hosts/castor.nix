{ lib, ... }:

{
  imports = [
    ./common/ec2.nix
    ./common/lowmem.nix
    ../services/monitoring.nix
    ../services/tailscale.nix
    ../services/tailscale-relay.nix
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 500 "castor";
}
