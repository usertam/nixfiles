{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/virtualisation/disk-image.nix"
    ./common/nixos.nix
    ../services/upgrade.nix
  ];

  # Host identity.
  networking.hostName = "lithos";

  # Boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0" ];

  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net"
  ];

  # Enable ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "tank" ];

  # Networking.
  networking.useNetworkd = true;
  systemd.network.enable = true;
  services.resolved.enable = true;

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
    profileDir = "/srv/tank/services/torrent/profile/";
    serverConfig = {
      LegalNotice.Accepted = true;
      BitTorrent.Session = {
        DefaultSavePath = "/srv/tank/services/torrent/complete";
        TempPathEnabled = true;
        TempPath = "/srv/tank/services/torrent/incomplete";
        TorrentExportDirectory = "/srv/tank/services/torrent/origin";
        MaxUploads = 16;
        MaxUploadsPerTorrent = 16;
        QueueingSystemEnabled = false;
        IgnoreLimitsOnLAN = true;
        uTPRateLimited = false;
      };
      Preferences = {
        WebUI = {
          AuthSubnetWhitelist = "100.64.0.0/10,127.0.0.1/32";
          AuthSubnetWhitelistEnabled = true;
        };
        General.Locale = "en";
      };
    };
  };

  # Make qBittorrent depends on the ZFS mount.
  systemd.services.qbittorrent.unitConfig = {
    BindsTo = [ "srv-tank.mount" ];
    After = [ "srv-tank.mount" ];
  };

  # Set UID and GID: 800 + sha256sum("qbittorrent") % 100.
  users.users.qbittorrent.uid = 872;
  users.groups.qbittorrent.gid = 872;

  # Enable radarr.
  services.radarr = {
    enable = true;
    dataDir = "/srv/tank/services/radarr/profile";
  };

  # Set UID and GID: 800 + sha256sum("radarr") % 100.
  users.users.radarr.uid = lib.mkForce 819;
  users.groups.radarr.gid = lib.mkForce 819;
  users.users.radarr.isSystemUser = true;

  # Open firewall on tailscale0 for NFS.
  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ 111 2049 7878 8080 20048 ];
    allowedUDPPorts = [ 111 2049 7878 8080 20048 ];
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
