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

      variant =
        # If ZFS is needed, prefer the latest stable when supported.
        if config.boot.zfs.enabled then
          if zfsSupports linux_stable then linux_stable else pkgs.linux
        # Mainline yields to stable once stable catches up to it.
        else if linux_stable.kernelAtLeast linux_mainline.baseVersion then
          linux_stable
        else
          linux_mainline;

      # Build a llvmStdenv out of clang, lld and LLVM binutils.
      llvmPkgs = pkgs.llvmPackages_latest;
      llvmStdenv = pkgs.overrideCC llvmPkgs.stdenv (
        llvmPkgs.clang.override { inherit (llvmPkgs) bintools; }
      );

      # bindgen must link the same libclang as CC: kbuild probes flags such as
      # -fms-anonymous-structs against clang and hands them to bindgen too.
      bindgen = pkgs.rust-bindgen-unwrapped.override { inherit (llvmPkgs) clang; };

      # pahole must filter by language per DWARF CU before LTO CU merging.
      pahole-lang-filter-patch = pkgs.writeText "pahole-lang-filter.patch" ''
        --- a/dwarf_loader.c
        +++ b/dwarf_loader.c
        @@ -4991,6 +4991,7 @@ static int cus__merge_and_process_cu(struct cus *cus, struct conf_load *conf,
         	struct dwarf_cu *dcu = NULL;
         	Dwarf_Off off = 0, noff;
         	struct cu *cu = NULL;
        +	bool lang_from_kept_cu = false;
         	size_t cuhl;
         
         	while (dwarf_nextcu(dw, off, &noff, &cuhl, NULL, &pointer_size,
        @@ -5114,6 +5115,12 @@ static int cus__merge_and_process_cu(struct cus *cus, struct conf_load *conf,
         				};
         
         				filtered = conf->early_cu_filter(&unmerged_cu) == NULL;
        +
        +				if (!filtered && !lang_from_kept_cu) {
        +					cu->language = unmerged_cu.language;
        +					cu->producer_clang = attr_producer_clang(cu_die);
        +					lang_from_kept_cu = true;
        +				}
         			}
         
         			if (!filtered && die__process_unit(&child, cu, conf, 0) != 0)
        --- a/pahole.c
        +++ b/pahole.c
        @@ -3724,7 +3724,7 @@ int main(int argc, char *argv[])
         
         	conf_load.steal = pahole_stealer;
         
        -	if (languages.exclude)
        +	if (languages.nr_entries)
         		conf_load.early_cu_filter = cu__filter;
         
         	// Make 'pahole --header type < file' a shorter form of 'pahole -C type --count 1 < file'
      '';

      # pahole must filter by language per DWARF CU before LTO CU merging.
      pahole = pkgs.pahole.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ pahole-lang-filter-patch ];
      });

      buildLinux = pkgs.buildLinux.override {
        inherit pahole;
        rust-bindgen-unwrapped = bindgen;
        callPackage = pkgs.newScope { inherit pahole; rust-bindgen-unwrapped = bindgen; };
      };

      # Context lines are space + tab, as in the tab-indented init/Kconfig.
      rust-btf-lto-patch = pkgs.writeText "rust-btf-lto.patch" ''
        --- a/init/Kconfig
        +++ b/init/Kconfig
        @@ -2264,3 +2264,3 @@
         	depends on !RANDSTRUCT
        -	depends on !DEBUG_INFO_BTF || (PAHOLE_HAS_LANG_EXCLUDE && !LTO)
        +	depends on !DEBUG_INFO_BTF || PAHOLE_HAS_LANG_EXCLUDE
         	depends on !CFI || HAVE_CFI_ICALL_NORMALIZE_INTEGERS_RUSTC
      '';

      kernel = variant.override (prev: {
        inherit buildLinux;
        stdenv = llvmStdenv;
        kernelPatches = (prev.kernelPatches or [ ]) ++ [
          { name = "rust-btf-lto"; patch = rust-btf-lto-patch; }
        ];
        structuredExtraConfig = with lib.kernel; {
          LIVEPATCH = yes;
          LTO_CLANG_THIN = yes;
        };
      });

      kernelPackages = (pkgs.linuxPackagesFor kernel).extend (self: super: {
        # virtualbox modules don't pass kernelModuleMakeFlags, so kbuild
        # defaults to `gcc`. Hand it the kernel's own toolchain.
        virtualbox = super.virtualbox.overrideAttrs (prev: {
          makeFlags = self.kernelModuleMakeFlags ++ prev.makeFlags;
        });
      });
    in
    lib.mkDefault kernelPackages;

  # Don't implicitly import zroot even if it exists.
  boot.zfs.forceImportRoot = lib.mkDefault false;

  # Lock down boot partition to root.
  fileSystems = lib.mkIf
    (config.boot.loader.systemd-boot.enable || config.boot.lanzaboote.enable or false)
    { "/boot".options = lib.mkDefault [ "fmask=0077" "dmask=0077" ]; };

  # Database compatibility defaults.
  system.stateVersion = (lib.mkOverride 900) "26.05";
}
