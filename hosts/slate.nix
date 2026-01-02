{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./common/nixos.nix
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  # Host identity.
  networking.hostName = "slate";

  # Use latest kernel, but disable ZFS support.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # Make release image.
  system.build.release = config.system.build.sdImage;
}
