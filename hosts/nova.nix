{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./common/nixos.nix
    ../services/lanzaboote.nix
    ../services/upgrade.nix
  ];

  # Host identity.
  networking.hostName = "nova";

  # Boot stuff.
  # boot.loader.systemd-boot.enable = true; # Handled by lanzaboote.
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;
  boot.zfs.extraPools = [ "tank" ];

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

  # We manually provision /etc/nixos on this host, not image-based.
  environment.etc."nixos".enable = false;

  # Enable NetworkManager, iwd and systemd-resolved.
  services.resolved.enable = true;
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
    dns = "systemd-resolved";
  };

  # Enable NFS on tailscale.
  services.nfs.server = {
    enable = true;
    exports = ''
      /srv/tank 100.64.0.0/10(rw,no_subtree_check)
    '';
  };

  # Enable qBittorrent, limit WebUI to tailscale.
  services.qbittorrent = {
    enable = true;
    serverConfig = {
      LegalNotice.Accepted = true;
      BitTorrent.Session = {
        DefaultSavePath = "/srv/tank/multiverse";
        DisableAutoTMMTriggers.CategorySavePathChanged = false;
        DisableAutoTMMTriggers.DefaultSavePathChanged = false;
        MaxUploads = 16;
        MaxUploadsPerTorrent = 16;
        QueueingSystemEnabled = false;
        IgnoreLimitsOnLAN = true;
        uTPRateLimited = false;
      };
      Preferences = {
        WebUI = {
          AuthSubnetWhitelist = "100.64.0.0/10";
          AuthSubnetWhitelistEnabled = true;
        };
        General.Locale = "en";
      };
    };
  };
}
