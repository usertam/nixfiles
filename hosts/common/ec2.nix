{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./nixos.nix
    "${modulesPath}/virtualisation/amazon-image.nix"
    "${modulesPath}/../maintainers/scripts/ec2/amazon-image.nix"
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 900 "ec2";

  # Override the default filesystems.
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "ext4";
      autoResize = true;
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  # Hack to override the build to produce the extra zst image.
  system.build.release =
    let
      prev = config.system.build.amazonImage;
    in
      pkgs.stdenv.mkDerivation ((lib.filterAttrs (k: _: k != "QEMU_OPTS") prev.drvAttrs) // {
        postVM = prev.postVM + ''
          ${lib.getExe pkgs.zstd} -T$NIX_BUILD_CORES $diskImage
          echo "file vpc ''${diskImage}.zst" >> $out/nix-support/hydra-build-products
        '';
        # Unset kvm; breaks on aarch64 runners.
        requiredSystemFeatures = [ ];
      });
}
