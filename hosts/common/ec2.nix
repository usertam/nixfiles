{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./nixos.nix
    "${modulesPath}/virtualisation/amazon-image.nix"
    "${modulesPath}/../maintainers/scripts/ec2/amazon-image.nix"
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 900 "ec2";

  # Remove the out-of-tree ENA driver.
  boot.extraModulePackages = lib.mkOverride 90 [ ];

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

  # Resolve the limine biosDevice conflict with qemu-vm in the vm variant.
  virtualisation.vmVariant = { config, ... }: {
    boot.loader.limine.biosDevice = lib.mkForce config.virtualisation.bootLoaderDevice;
  };

  # Extend the image build to produce the extra zst image.
  system.build.release = config.system.build.amazonImage.overrideAttrs (prev: {
    postInstall = (prev.postInstall or "") + ''
      ${lib.getExe pkgs.zstd} -T$NIX_BUILD_CORES $out/${config.image.filePath}
      echo "file vpc $out/${config.image.filePath}.zst" >> $out/nix-support/hydra-build-products
    '';
  });
}
