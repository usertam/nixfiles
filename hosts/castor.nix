{ ... }:

{
  imports = [
    ./common/ec2-ami.nix
    ../services/tailscale-srv.nix
  ];

  # Host identity.
  networking.hostName = "castor";
}
