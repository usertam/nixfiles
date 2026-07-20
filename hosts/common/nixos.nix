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

  # Use the mainline or latest kernel when possible, subject to modules needed.
  # Rebuild the selected kernel with structuredExtraConfig.
  boot.kernelPackages =
    with pkgs;
    let
      base =
        if !config.boot.zfs.enabled then
          linuxPackages_testing
        else if !linuxPackages_latest.zfs_unstable.meta.broken then
          linuxPackages_latest
        else
          linuxPackages;
      kernel = base.kernel.override {
        structuredExtraConfig = with lib.kernel; {
          LIVEPATCH = yes;
        };
      };
    in
    lib.mkDefault ((linuxPackagesFor kernel).extend (_: prev: {
      # virtualbox-modules' vboxnetadp calls strncpy(), which Linux 7.2 removed
      # from <linux/string.h>. Swap the three call sites for strscpy().
      virtualbox = prev.virtualbox.overrideAttrs (old: lib.optionalAttrs (lib.hasPrefix "7.2-rc" prev.kernel.version) {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace vboxnetadp/VBoxNetAdp.c \
            --replace-fail \
              'strncpy(pThis->szName, pcszName, sizeof(pThis->szName) - 1);' \
              'strscpy(pThis->szName, pcszName, sizeof(pThis->szName));'
          substituteInPlace vboxnetadp/linux/VBoxNetAdp-linux.c \
            --replace-fail \
              'strncpy(pThis->szName, pNetDev->name, sizeof(pThis->szName));' \
              'strscpy(pThis->szName, pNetDev->name, sizeof(pThis->szName));' \
            --replace-fail \
              'strncpy(Req.szName, pAdp->szName, sizeof(Req.szName) - 1);' \
              'strscpy(Req.szName, pAdp->szName, sizeof(Req.szName));'
        '';
      });

      # ena on ec2 hosts: Linux 7.2 changed page_pool_get_stats() to return void,
      # so ena_ethtool.c's bool-style check no longer compiles. Call it
      # unconditionally once the page pool is known non-NULL.
      ena = prev.ena.overrideAttrs (old: lib.optionalAttrs (lib.hasPrefix "7.2-rc" prev.kernel.version) {
        postPatch = ''
          substituteInPlace kernel/linux/ena/ena_ethtool.c \
            --replace-fail \
              $'if (!pool || !page_pool_get_stats(pool, &stats))\n\t\t\tcontinue;' \
              $'if (!pool)\n\t\t\tcontinue;\n\t\tpage_pool_get_stats(pool, &stats);'
        '' + (old.postPatch or "");
      });
    }));

  # Don't implicitly import zroot even if it exists.
  boot.zfs.forceImportRoot = lib.mkDefault false;

  # Lock down boot partition to root.
  fileSystems = lib.mkIf
    (config.boot.loader.systemd-boot.enable || config.boot.lanzaboote.enable or false)
    { "/boot".options = lib.mkDefault [ "fmask=0077" "dmask=0077" ]; };

  # Database compatibility defaults.
  system.stateVersion = (lib.mkOverride 900) "26.05";
}
