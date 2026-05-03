{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/virtualisation/disk-image.nix"
    ./common/nixos.nix
    ../services/upgrade.nix
  ];

  # Host identity.
  networking.hostName = "tecton";

  # Boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0" ];

  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net"
  ];

  # Networking.
  networking.useNetworkd = true;
  systemd.network.enable = true;
  services.resolved.enable = true;

  # Install development packages.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  environment.systemPackages = with pkgs; [
    bubblewrap # for claude-code sandbox
    claude-code
  ];

  # Cross-arch building support with binfmt and qemu.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" "riscv64-linux" "armv7l-linux" ];
  nix.settings.extra-platforms = [ "aarch64-linux" "riscv64-linux" "armv7l-linux" ];
  nix.settings.system-features = [ "gccarch-armv7-a" ];

  # Hack to override the build to produce the extra zst image.
  image.format = "raw";
  system.build.release =
    let
      prev = config.system.build.image;
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
