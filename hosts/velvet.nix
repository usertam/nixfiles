{ ... }:

{
  imports = [ ./fabric.nix ];

  # Identity.
  networking.hostName = "velvet";

  # Distinct virtio MACs.
  systemd.network.links = {
    "10-wan0".matchConfig.MACAddress  = "00:1a:4a:f4:c4:42";
    "20-lan0".matchConfig.MACAddress  = "00:1a:4a:f4:c4:66";
    "30-vnet0".matchConfig.MACAddress = "00:1a:4a:f4:c4:a2";
    "40-peer0".matchConfig.MACAddress = "00:1a:4a:f4:c4:df";
  };

  # Distinct IPs on LAN.
  systemd.network.networks = {
    "30-vnet0".address = [ "172.16.0.12/20" ];
    "40-peer0".addresses = [
      { Address = "172.16.200.2/32"; Peer = "172.16.200.1/32"; }
    ];
    "50-vf0".addresses = [
      { Address = "172.16.201.2/32"; Peer = "172.16.201.1/32"; }
    ];
  };

  # Lower VRRP priority and start in BACKUP.
  services.keepalived.vrrpInstances = {
    lan0.state  = "BACKUP";
    vnet0.state = "BACKUP";
    lan0.priority  = 100;
    vnet0.priority = 100;
  };
}
