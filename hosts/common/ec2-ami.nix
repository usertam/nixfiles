{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./nixos.nix
    "${modulesPath}/virtualisation/amazon-image.nix"
    "${modulesPath}/../maintainers/scripts/ec2/amazon-image.nix"
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 900 "generic-ami";

  # Set up swapfile.
  swapDevices = [
    { device = "/var/lib/swapfile"; size = 2 * 1024; }
  ];

  # Hack to override the build to produce the extra zst image.
  system.build.release =
    let
      prev = config.system.build.amazonImage;
    in
      pkgs.stdenv.mkDerivation (prev.drvAttrs // {
        postVM = prev.postVM + ''
          ${lib.getExe pkgs.zstd} -T$NIX_BUILD_CORES $diskImage
          echo "file vpc ''${diskImage}.zst" >> $out/nix-support/hydra-build-products
        '';
        # Unset kvm; breaks on aarch64 runners.
        requiredSystemFeatures = [ ];
      });
}
