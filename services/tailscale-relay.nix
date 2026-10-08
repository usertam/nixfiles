{ config, lib, ... }:

{
  # Enable tailscale derper server.
  services.tailscale.derper = {
    enable = true;
    # Honor the choice on services.tailscale.package.
    package = config.services.tailscale.package.derper;
    domain = "derp.usertam.dev";
  };

  # Override the systemd derper service.
  systemd.services.tailscale-derper = let
    cfg = config.services.tailscale.derper;
    meshWith = [
      "2406:da1e:dbf:a600:8752:a0ad:99bf:2aea"  # castor
      "2406:da1e:dbf:a601:97b0:b008:c2e6:f604"  # pollux
    ];
    meshPSKFile = "/var/lib/tailscale-derper/mesh-psk";
  in {
    serviceConfig.ExecStart = lib.mkForce (
      "${lib.getExe' cfg.package "derper"}"
      + " -a :${toString cfg.port}"
      + " -c /var/lib/derper/derper.key"
      + " -hostname=${cfg.domain}"
      + " -stun=false"
      + " -mesh-with=${lib.concatMapStringsSep "," (ip: "${cfg.domain}/${ip}") meshWith}"
      + " -mesh-psk-file=\${CREDENTIALS_DIRECTORY}/mesh-psk"
    );
    serviceConfig.LoadCredential = "mesh-psk:${meshPSKFile}";
    unitConfig.ConditionPathExists = meshPSKFile;
  };

  systemd.paths.tailscale-derper = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists =
      config.systemd.services.tailscale-derper.unitConfig.ConditionPathExists;
  };

  # Enable ACME for derper.
  services.nginx.virtualHosts."derp.usertam.dev".enableACME = true;
  security.acme = {
    acceptTerms = true;
    defaults.email = "infra@usertam.dev";
  };

  # Enable coturn server; replacing tailscale's built-in one.
  services.coturn = {
    enable = true;
    # Reuse the TLS cert from ACME.
    cert = "/var/lib/acme/derp.usertam.dev/fullchain.pem";
    pkey = "/var/lib/acme/derp.usertam.dev/key.pem";
  };

  # Enable coturn to read the TLS cert; restart it when the cert is provisioned.
  users.users.turnserver.extraGroups = [ config.services.nginx.group ];
  security.acme.certs."derp.usertam.dev".reloadServices = [ "coturn.service" ];

  # Wait for both IPv4 and IPv6 before reaching network-online.target.
  # To let coturn to enumerate the listening addresses properly.
  networking.dhcpcd.wait = "both";

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
