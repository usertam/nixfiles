{ config, lib, pkgs, modulesPath, ... }:

# Backport of https://github.com/NixOS/nixpkgs/pull/236110.

let
  isNotx86 = !pkgs.stdenv.hostPlatform.isx86;
  mkIfNotx86 = attr: lib.mkIf isNotx86 (lib.mkForce attr);
in
{
  imports = [
    "${modulesPath}/virtualisation/azure-image.nix"
    # Override assertions (isx86) in azure-agent.nix.
    (lib.recursiveUpdate
      ((import "${modulesPath}/virtualisation/azure-agent.nix") { inherit config lib pkgs; })
      { config.content.assertions = []; })
  ];

  # Disable original module with assertions.
  disabledModules = [ "${modulesPath}/virtualisation/azure-agent.nix" ];

  # Generate a GRUB menu ONLY when booting in BIOS.
  boot.loader.grub.device = mkIfNotx86 "nodev";

  # Enable GRUB EFI support if needed.
  boot.loader.grub.efiSupport = mkIfNotx86 true;
  boot.loader.grub.efiInstallAsRemovable = mkIfNotx86 true;

  # Mount ESP for EFI support.
  fileSystems."/boot" = mkIfNotx86 {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # Force override image creation.
  system.build.azureImage = lib.mkForce (lib.overrideDerivation (import "${modulesPath}/../lib/make-disk-image.nix" {
    name = "azure-image";
    postVM = ''
      ${pkgs.vmTools.qemu}/bin/qemu-img convert -f raw -o subformat=fixed,force_size -O vpc $diskImage \
        $out/azure.${pkgs.system}.vhd
      rm $diskImage
    '';
    format = "raw";
    partitionTableType = if isNotx86 then "efi" else "legacy";
    additionalSpace = "0M";
    inherit (config.virtualisation.azureImage) diskSize contents;
    inherit config lib pkgs;
  }) ({ buildInputs, buildCommand, ... }: {
    buildInputs = with pkgs; buildInputs ++ [ zerofree ];
    buildCommand = buildCommand + ''
      mount $rootDisk $mountPoint
      mount /dev/vda1 $mountPoint/boot
      nixos-enter --root $mountPoint -- /run/current-system/sw/bin/nix-store --gc
      nixos-enter --root $mountPoint -- /run/current-system/sw/bin/nix-store --optimise
      umount -R $mountPoint
      export PATH=$PATH:${pkgs.zerofree}/bin
      zerofree $rootDisk
    '';
  }));

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
  ];

  # Backport: Mount tmpfs on /tmp during boot.
  boot.tmp.useTmpfs = true;

  # TCP connections will timeout after 4 minutes on Azure.
  boot.kernel.sysctl."net.ipv4.tcp_keepalive_time" = 120;
  boot.kernel.sysctl."net.ipv4.tcp_keepalive_intvl" = 30;
  boot.kernel.sysctl."net.ipv4.tcp_keepalive_probes" = 8;

  # Disable reboot on system upgrades.
  system.autoUpgrade.allowReboot = false;

  # Enable zram swap.
  zramSwap.enable = true;
  zramSwap.memoryMax = 2 * 1024 * 1024 * 1024;

  # Let nix daemon use alternative TMPDIR.
  systemd.services.nix-daemon.environment.TMPDIR = "/nix/var/tmp";
  systemd.tmpfiles.rules = [
    "d /nix/var/tmp 0755 root root 1d"
  ];
}
