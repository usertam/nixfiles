{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 900 "generic-installer";
  system.nixos.tags = lib.mkOverride 900 [ "generic-installer" ];

  # We didn't pick the latest kernel because we want ZFS support.

  # Make release image.
  isoImage.compressImage = true;
  system.build.release = config.system.build.isoImage;
}
