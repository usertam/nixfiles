{ config, lib, pkgs, modulesPath, ... }:

{
  # Import common modules.
  imports = [
    ../../programs/common.nix
    ../../programs/nix.nix
    ../../programs/shell.nix
    ../../services/openssh.nix
    ../../services/rsyncd.nix
    ../../services/tailscale.nix
    ../../services/upgrade.nix
  ];

  # Auto-gen host ID based on the set hostname. Used by ZFS.
  networking.hostId =
    let
      inherit (config.networking) hostName;
      isHostNameSet = hostName != "nixos";
      hash = builtins.hashString "sha256" hostName;
      hostId = builtins.substring 0 8 hash;
    in
    lib.mkIf isHostNameSet hostId;

  # Set variant ID based on hostname.
  system.nixos.variant_id =
    let
      inherit (config.networking) hostName;
      isHostNameSet = hostName != "nixos";
    in
    lib.mkIf isHostNameSet hostName;

  # Set time zone.
  time.timeZone = "Hongkong";

  # Define global user defaults.
  users.mutableUsers = false;

  # Link this repo read-only to /etc/nixos, assume image-based provisions.
  # Set environment.etc."nixos".enable = false for manual edits and switches.
  # Similar to system.copySystemConfiguration.
  environment.etc."nixos".source = ../..;

  # Raise soft file descriptors limit from 1024 to 65536. Hard limit remains same.
  # Mostly for user; not too worried about services, as systemd sets it to hard limit already.
  # You can check /proc/<pid>/limits to be sure.
  systemd.settings.Manager.DefaultLimitNOFILE = "65536:524288";
  systemd.user.settings.Manager.DefaultLimitNOFILE = "65536:524288";
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "65536"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "524288"; }
  ];

  # Assume single NIC setups.
  networking.usePredictableInterfaceNames = lib.mkDefault false;

  # Use nftables instead of iptables.
  networking.nftables.enable = true;

  # Trigger pam_lastlog2.so, print last login info.
  security.pam.services."login" = {
    updateWtmp = true;
    rules.session.lastlog.settings.silent = lib.mkForce false;
  };
  security.pam.services."sshd" = {
    updateWtmp = true;
    rules.session.lastlog.settings.silent = lib.mkForce false;
  };

  # Keep sshd reachable under system resource exhaustion (memory, PID, FD).
  # MemoryMin on the parent slice is required for the sshd reservation to propagate.
  systemd.slices.system.sliceConfig.MemoryMin = lib.mkDefault "64M";
  systemd.services.sshd = lib.mkIf config.services.openssh.enable {
    serviceConfig = {
      OOMScoreAdjust = -1000;
      MemoryMin = "16M";
      TasksMax = "infinity";
      LimitNOFILE = "65536:524288";
      IOWeight = 10000;
      CPUWeight = 10000;
    };
  };

  # Extra configurations to apply, when built as a VM.
  virtualisation.vmVariant = {
    virtualisation.diskSize = lib.mkDefault 16384; # 16 GiB
  };

  # Custom system label, and do not sort the tags.
  system.nixos.label = lib.maybeEnv "NIXOS_LABEL" (
    lib.concatStringsSep "-" (
      lib.flatten [
        "usertam"
        config.networking.hostName
        config.system.nixos.tags
        (lib.maybeEnv "NIXOS_LABEL_VERSION" config.system.nixos.version)
      ]
    )
  );

  # Track the mainline/stable kernels pinned in kernels.json, falling back where
  # out-of-tree modules (ZFS) need it, and rebuild with extra config.
  boot.kernelPackages =
    let
      inherit (lib.importJSON ./kernels.json) mainline stable;

      # Swap a nixpkgs kernel's version and source, keeping its patches and config.
      overrideKernel =
        kernel:
        { version, ... }:
        src:
        kernel.override {
          argsOverride = {
            inherit version src;
            modDirVersion = lib.versions.pad 3 version;
          };
        };

      # Fetch as upstream mainline.nix does, so sources share nixpkgs store paths.
      linux_mainline = overrideKernel pkgs.linux_testing mainline (
        pkgs.fetchzip {
          url = "https://git.kernel.org/torvalds/t/linux-${mainline.version}.tar.gz";
          inherit (mainline) hash;
        }
      );

      linux_stable = overrideKernel pkgs.linux_latest stable (
        pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v${lib.versions.major stable.version}.x/linux-${stable.version}.tar.xz";
          inherit (stable) hash;
        }
      );

      zfsSupports = kernel: !(pkgs.linuxPackagesFor kernel).zfs_unstable.meta.broken;

      base =
        # If ZFS is needed, prefer the latest stable when supported.
        if config.boot.zfs.enabled then
          if zfsSupports linux_stable then linux_stable else pkgs.linux
        # Mainline yields to stable once stable catches up to it.
        else if linux_stable.kernelAtLeast linux_mainline.baseVersion then
          linux_stable
        else
          linux_mainline;

      kernel = base.override {
        structuredExtraConfig.LIVEPATCH = lib.kernel.yes;
      };
    in
    lib.mkDefault (pkgs.linuxPackagesFor kernel);

  # Don't implicitly import zroot even if it exists.
  boot.zfs.forceImportRoot = lib.mkDefault false;

  # Lock down boot partition to root.
  fileSystems = lib.mkIf
    (config.boot.loader.systemd-boot.enable || config.boot.lanzaboote.enable or false)
    { "/boot".options = lib.mkDefault [ "fmask=0077" "dmask=0077" ]; };

  # Database compatibility defaults.
  system.stateVersion = (lib.mkOverride 900) "26.05";
}
