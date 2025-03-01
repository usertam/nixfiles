{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/azure-image.nix" ];

  disabledModules = [ "${modulesPath}/virtualisation/disk-size-option.nix" ];

  # Support generation 2 VMs, supersede the backport.
  virtualisation.azureImage.vmGeneration = "v2";
  virtualisation.azure.acceleratedNetworking = true;

  # Use systemd-boot bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use networkd for network configuration.
  networking.useNetworkd = true;

  # Mount tmpfs on /tmp during boot.
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

  # Define the release attribute be attached to root flake's packages.
  system.build.release = pkgs.runCommand "nixos-image-${config.system.nixos.label}-${pkgs.system}" {
    src = lib.overrideDerivation config.system.build.azureImage (prev: {
      args = with lib; init prev.args ++ singleton ((last prev.args).overrideAttrs {
        # Disable virtiofsd seccomp to fix building on GitHub Actions with qemu-user.
        # Abuse checkPhase to inject replace logic.
        checkPhase = ''
          substituteInPlace $target \
            --replace-fail "bin/virtiofsd" "bin/virtiofsd --seccomp none"
        '';
      });
    });
    nativeBuildInputs = [ pkgs.pixz ];
  } ''
    mkdir -p $out
    pixz -k $src/*.vhd $out/''${name}.vhd.xz
  '';
}
