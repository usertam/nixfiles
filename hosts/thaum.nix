{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ./common/nixos.nix
    ../services/incus.nix
    ../services/niks3.nix
  ];

  # Host identity.
  networking.hostName = "thaum";

  # Boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0" ];

  # KVM guest on an AMD EPYC host.
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net"
  ];
  boot.kernelModules = [
    "kvm-amd"
  ];

  # Enable microcode updates.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };
  };

  # Static networking.
  networking.useNetworkd = true;
  systemd.network.enable = true;
  services.resolved.enable = true;

  systemd.network.networks."10-wan0" = {
    matchConfig.Name = "eth0";
    address = [
      "45.128.220.113/24"
      "2403:2c81:2000:2123::a/64"
    ];
    routes = [
      { Gateway = "45.128.220.1"; }
      # IPv6 gateway sits outside the /64, so it must be treated as on-link.
      { Gateway = "2403:2c81:2000::1"; GatewayOnLink = true; }
    ];
    dns = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
  };
}
