{ lib, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = lib.mkDefault 100;
    priority = 100;
  };

  swapDevices = [
    { device = "/var/lib/swapfile"; size = 2 * 1024; }
  ];
}
