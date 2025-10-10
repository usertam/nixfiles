{ config, lib, pkgs, modulesPath, ... }:

{
  networking.hostName = "tsrvbld";
  system.nixos.tags = [ "tsrvbld" ];

  # We need vagrant to spawn TrustedServer mocks.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "vagrant" ];
  environment.systemPackages = [ pkgs.vagrant pkgs.sshpass ];

  # Enable virtualbox, docker, and KVM.
  virtualisation = {
    docker.enable = true;
    virtualbox.host.enable = true;
  };
  environment.etc."vbox/networks.conf".text = "* 0.0.0.0/0 ::/0";
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };

  # Enable options to boot in UEFI mode.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

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

  # Enable x11 server and keymap.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Enable display an desktop managers.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Enable audio.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable auto login.
  services.displayManager.autoLogin = {
    enable = true;
    user = "root";
  };

  # Enable touchpad support.
  services.libinput.enable = true;

  # Don't sleep.
  services.logind.lidSwitch = "lock";
}
