{ lib, ... }:

{
  imports = [
    ./common/ec2-ami.nix
    ../services/coturn.nix
    ../services/derper.nix
    ../services/tailscale.nix
    ../services/upgrade.nix
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 500 "castor";
}
