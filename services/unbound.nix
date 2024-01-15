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
        zonefile = config.secrets."unbound/usertam.dev.zone".path;
      };
    };
  };

  networking.firewall = with config.services.unbound.settings; {
    allowedTCPPorts = server.port;
    allowedUDPPorts = server.port;
  };

  secrets."unbound/usertam.dev.zone".enable = true;
}
