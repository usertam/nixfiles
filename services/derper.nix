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

  # Set a default regular memory limit, of 10x average.
  systemd.services.tailscale-derper.serviceConfig = {
    MemoryHigh = lib.mkDefault "128M";
    MemoryMax = lib.mkDefault "192M";
  };
}
