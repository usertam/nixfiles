{ ... }:

{
  imports = [ ./fabric.nix ];

  # Identity.
  networking.hostName = "velvet";

  # Distinct virtio MACs.
  systemd.network.links = {
    "10-wan0".matchConfig.MACAddress = "00:1a:4a:f4:c4:42";
    "10-lan0".matchConfig.MACAddress = "00:1a:4a:f4:c4:66";
    "10-vm0".matchConfig.MACAddress  = "00:1a:4a:f4:c4:a2";
    "10-vm1".matchConfig.MACAddress  = "00:1a:4a:f4:c4:df";
  };

  # Distinct real IPs on the .3 of each subnet.
  systemd.network.networks = {
    "10-lan0".address = [ "192.168.1.3/24" ];
    "10-vm0".address  = [ "172.16.0.3/20" ];
    "10-vm1".address  = [ "172.16.16.3/20" ];
  };

  # Lower VRRP priority and start in BACKUP.
  services.keepalived.vrrpInstances = {
    lan0.state = "BACKUP";
    vm0.state  = "BACKUP";
    vm1.state  = "BACKUP";
    lan0.priority = 100;
    vm0.priority  = 100;
    vm1.priority  = 100;
  };
}
