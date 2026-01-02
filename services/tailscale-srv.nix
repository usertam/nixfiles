{ config, pkgs, ... }:

{
  # Enable tailscale derper server.
  services.tailscale.derper = {
    enable = true;
    # Honor the choice on services.tailscale.package.
    package = config.services.tailscale.package.derper;
    domain = "derp.usertam.dev" + " -stun=false"; # Hack to disable STUN.
    configureNginx = false;
  };

  # Enable coturn server, replacing tailscale's built-in one.
  services.coturn.enable = true;

  # Set memory limits for derper and coturn services.
  systemd.services.tailscale-derper.serviceConfig = {
    MemoryHigh = "160M";
    MemoryMax = "192M";
  };

  systemd.services.coturn.serviceConfig = {
    MemoryHigh = "96M";
    MemoryMax = "128M";
  };
}
