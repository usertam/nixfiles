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

  # Low-latency network tuning.
  boot.kernel.sysctl = {
    "net.core.busy_poll" = 50;
    "net.core.busy_read" = 50;
  };

  # Disable interrupt coalescing on the ENA interface, equivalent to
  # ethtool -C eth0 adaptive-rx off rx-usecs 0 tx-usecs 0.
  systemd.network.links."10-ena" = {
    matchConfig.Driver = "ena";
    linkConfig = {
      UseAdaptiveRxCoalesce = false;
      RxCoalesceSec = 0;
      TxCoalesceSec = 0;
    };
  };
}
