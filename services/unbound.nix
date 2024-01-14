{ config, ... }:

{
  services.unbound = {
    enable = true;
    settings = {
      server = rec {
        interface = [ "0.0.0.0" "::0" ];
        port = [ 53 ];
        access-control = map (x: x + "/0 allow") interface;
      };
      auth-zone = {
        name = "usertam.dev.";
        zonefile = builtins.toFile "usertam.dev.zone" ''
          $ORIGIN usertam.dev.
          $TTL    10m
          @ IN SOA ns.usertam.dev. root.usertam.dev. (
            2024010101 ; serial
            10m        ; refresh
            5m         ; retry
            1w         ; expire
            5m         ; negative
          )
          @     IN NS     ns.usertam.dev.
          ns    IN A      20.205.110.200
          www   IN CNAME  usertam.dev.
        '';
      };
    };
  };

  networking.firewall = with config.services.unbound.settings; {
    allowedTCPPorts = server.port;
    allowedUDPPorts = server.port;
  };
}
