{ config, lib, ... }:

{
  # Enable tailscale derper server.
  services.tailscale.derper = {
    enable = true;
    # Honor the choice on services.tailscale.package.
    package = config.services.tailscale.package.derper;
    domain =
      "derp.usertam.dev"
      + lib.optionalString config.services.coturn.enable " -stun=false"; # Hack to disable STUN.
    configureNginx = false;
  };

  # Enable coturn server; replacing tailscale's built-in one.
  services.coturn.enable = true;

  # Firewall rules for the relay.
  networking.firewall = {
    allowedTCPPorts = [
      80    # ACME HTTP-01 + captive portal checks (derper)
      443   # DERP over TLS
      3478  # coturn STUN/TURN
      5349  # coturn TURNS
    ];

    allowedUDPPorts = [
      3478  # coturn STUN/TURN
      5349  # coturn DTLS
    ];

    allowedUDPPortRanges = [
      { # coturn relay allocations
        from = config.services.coturn.min-port;
        to   = config.services.coturn.max-port;
      }
    ];
  };
}
