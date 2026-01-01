{ config, lib, pkgs, modulesPath, ... }:

{
  # Host identity.
  networking.hostName = "tsrvbld";
  system.nixos.tags = [ "tsrvbld" ];

  # Basic boot stuff, from nixos-generate-config.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  boot.initrd.availableKernelModules = [
    "nvme" "sd_mod" "thunderbolt" "usb_storage" "xhci_pci"
  ];

  boot.kernelModules = [ 
    "kvm-intel"
  ];

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

  # We manually provision /etc/nixos on this host, not image-based.
  environment.etc."nixos".enable = false;

  # Special options to flip for docker daemon and virtualbox kernel modules.
  virtualisation = {
    docker.enable = true;
    virtualbox.host.enable = true;
  };

  # VirtualBox needs this to allow host-only ranges.
  environment.etc."vbox/networks.conf".text = "* 0.0.0.0/0 ::/0";

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
    "vagrant"
  ];

  environment.systemPackages = with pkgs; [
    claude-code
    docker
    earthly
    gnupg
    vagrant
  ];

  # Cross-arch building support with binfmt and qemu.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" "riscv64-linux" "armv7l-linux" ];
  nix.settings.extra-platforms = [ "aarch64-linux" "riscv64-linux" "armv7l-linux" ];
  nix.settings.system-features = [ "gccarch-armv7-a" ];

  # Enable NetworkManager with iwd and systemd-resolved.
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
    dns = "systemd-resolved";
  };

  services.resolved = {
    enable = true;
    fallbackDns = [ "1.1.1.1" ];
  };

  # Enable X11 server and keymap.
  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  # Enable GNOME desktop manager.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Enable touchpad support.
  services.libinput.enable = true;

  # Enable audio stuff.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Declare a regular user and configure auto-login.
  users.groups.tam = {};
  users.users.tam = {
    isNormalUser = true;
    group = "tam";
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "tam";
  };

  # Goofy-ahh workaround for GNOME autologin
  # https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Do NOT sleep, even when the world ends.
  services.displayManager.gdm.autoSuspend = false;
  services.logind.settings.Login.HandleLidSwitch = "ignore";
  systemd.targets.suspend.enable = false;
}
