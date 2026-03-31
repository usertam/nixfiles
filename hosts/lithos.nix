{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./common/nixos.nix
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/virtualisation/disk-image.nix"
  ];

  # Host identity.
  networking.hostName = "lithos";

  # Boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=ttyS0" ];

  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net"
  ];

  # Enable ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "tank" ];

  # Networking.
  networking.useNetworkd = true;
  networking.usePredictableInterfaceNames = true;
  systemd.network.enable = true;
  services.resolved.enable = true;

  # Virtio NIC bridged to host.
  systemd.network.links."10-vmbr0" = {
    matchConfig.Driver = "virtio_net";
    linkConfig.Name = "vmbr0";
  };
  systemd.network.networks."10-vmbr0" = {
    matchConfig.Name = "vmbr0";
    networkConfig.DHCP = "ipv4";
    dhcpV4Config.RouteMetric = 0;
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
    package = pkgs.qbittorrent-nox.overrideAttrs (prev: {
      version = "5.2.0beta1-unstable-2026-02-23";
      src = pkgs.fetchFromGitHub {
        owner = "qbittorrent";
        repo = "qBittorrent";
        rev = "7073130332cd433ff4bf337e5a387be87fea9811"; # 5.2.0beta1-unstable-2026-02-23
        hash = "sha256-WwTNpeTpyS0OauZWN2mHZnM5qgPneHFwbC/lnnz8X2U=";
      };
    });
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

  # Make qBittorrent depends on the mount.
  systemd.services.qbittorrent.unitConfig = {
    RequiresMountsFor = "/srv/tank";
  };

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
