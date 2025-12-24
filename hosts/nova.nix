{ inputs, config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  # Host identity.
  networking.hostName = "nova";
  networking.hostId = "19e05df6"; # Used for ZFS.
  system.nixos.tags = [ "nova" ];

  # Boot stuff.
  boot.loader.systemd-boot.enable = false; # lanzaboote
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable secure boot with lanzaboote.
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys.enable = true;
    autoEnrollKeys.autoReboot = true;
  };

  # Enable ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;

  # Enable microcode updates.
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"
  ];

  boot.kernelModules = [
    "kvm-intel"
  ];

  fileSystems = {
    "/" = {
      device = "zroot/root";
      fsType = "zfs";
    };
    "/nix" = {
      device = "zroot/nix";
      fsType = "zfs";
    };
    "/home" = {
      device = "zroot/home";
      fsType = "zfs";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };

  # Enable NetworkManager, iwd and systemd-resolved.
  services.resolved.enable = true;
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
    dns = "systemd-resolved";
  };
}
