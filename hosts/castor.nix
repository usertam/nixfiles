{ lib, ... }:

{
  imports = [
    ./common/ec2-ami.nix
    ../services/coturn.nix
    ../services/derper.nix
    ../services/upgrade.nix
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 500 "castor";

  # Enable NAT for virtual ethernet interfaces.
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "eth0";
  };

  containers.tailscale-container = {
    config = {
      imports = [
        ../services/tailscale.nix
      ];
    };
    autoStart = true;
    privateNetwork = true;
    enableTun = true;
    # Last /24 block of 172.16.0.0/12; docker starts from 172.17.0.0/24.
    hostAddress = "172.31.0.1";
    localAddress = "172.31.0.2";
    hostAddress6 = "fd00:ac1f::1";
    localAddress6 = "fd00:ac1f::2";
  };
}
