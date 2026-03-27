{ inputs, system, lib, ... }:

{
  imports = [
    ./common/nixos.nix
    # ../services/lanzaboote.nix
    ../services/upgrade.nix
    inputs.proxmox-nixos.nixosModules.proxmox-ve
  ];

  nixpkgs.overlays = [
    inputs.proxmox-nixos.overlays.${system}
  ];

  # Host identity.
  networking.hostName = "zenith";

  # Boot stuff.
  boot.loader.systemd-boot.enable = true; # Handled by lanzaboote.
  boot.loader.efi.canTouchEfiVariables = true;

  # Hardware detected.
  boot.initrd.availableKernelModules = [
    "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-amd"
  ];

  # Enable ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;

  # Enable microcode updates.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

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
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };

  # Manually provision /etc/nixos on this host.
  environment.etc."nixos".enable = false;

  # Multiple NICs, want predictable names.
  networking.usePredictableInterfaceNames = true;

  # Enable NetworkManager, iwd and systemd-resolved.
  services.resolved.enable = true;
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
    dns = "systemd-resolved";
  };

  # Enable Proxmox VE.
  services.proxmox-ve = {
    enable = true;
    ipAddress = "172.16.0.1";
  };
  services.openssh.settings = {
    AcceptEnv = lib.mkForce null;
  };
}
