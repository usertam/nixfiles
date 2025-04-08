{ lib, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # Kernel modules available to initrd before rootfs mount.
  boot.initrd.availableKernelModules = lib.mkDefault [
    "nvme"
    "sd_mod"
    "thunderbolt"
    "usb_storage"
    "xhci_pci"
  ];

  # Kernel modules loaded in second stage of boot.
  boot.kernelModules = lib.mkDefault [
    "kvm-intel"
  ];
}
