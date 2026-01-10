{ lib, ... }:

{
  # Enable coturn server; replacing tailscale's built-in one.
  services.coturn.enable = true;

  # Set a default regular memory limit, of 10x average.
  systemd.services.coturn.serviceConfig = {
    MemoryHigh = lib.mkDefault "128M";
    MemoryMax = lib.mkDefault "192M";
  };
}
