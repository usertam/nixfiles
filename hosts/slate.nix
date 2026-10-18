{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ./common/nixos.nix
  ];

  # Host identity.
  networking.hostName = "slate";

  # Enable auto login as root.
  services.getty.autologinUser = lib.mkDefault "root";

  # Disable ZFS support to have the latest kernel. 
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # Use zram instead of zswap, no swapfile.
  boot.zswap.enable = false;
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  # Make release image.
  system.build.release = config.system.build.sdImage;
}
