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

  # Additionally, open port 80 and 443 for DERP server.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
