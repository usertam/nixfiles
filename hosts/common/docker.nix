{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./nixos.nix
    "${modulesPath}/virtualisation/docker-image.nix"
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 900 "generic-docker";

  documentation.doc.enable = false;

  # Enable zram swap.
  zramSwap.enable = true;
  zramSwap.memoryMax = 1 * 1024 * 1024 * 1024;

  # Make release image; no options like tarballImage.compressImage here.
  system.build.release = config.system.build.tarball.override {
    compressCommand = "zstd";
    compressionExtension = ".zst";
    extraInputs = [ pkgs.zstd ];
  };
}
