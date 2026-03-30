{ inputs, system, lib, pkgs, ... }:

{
  imports = [
    ./common/nixos.nix
    # ../services/lanzaboote.nix
    ../services/upgrade.nix
    inputs.proxmox-nixos.nixosModules.proxmox-ve
  ];

  nixpkgs.overlays = [
    inputs.proxmox-nixos.overlays.${system}
  ];

  # Host identity.
  networking.hostName = "zenith";

  # Boot stuff.
  boot.loader.systemd-boot.enable = true; # Handled by lanzaboote.
  boot.loader.efi.canTouchEfiVariables = true;

  # From auto hardware detection.
  boot.initrd.availableKernelModules = [
    "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-amd"
  ];

  # Enable ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;

  # Enable microcode updates.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Configure VFIO passthrough for I226-V [8086:125c] and RTL8125 [10ec:8125].
  boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];
  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
  boot.extraModprobeConfig = "options vfio-pci ids=8086:125c,10ec:8125";

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
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };

  # Manually provision /etc/nixos on this host.
  environment.etc."nixos".enable = false;

  # Multiple NICs, want predictable names.
  networking.usePredictableInterfaceNames = true;

  # Enable systemd-networkd and systemd-resolved.
  services.resolved.enable = true;
  networking.useNetworkd = true;
  systemd.network.enable = true;

  # Create an internal network/bridge for virtual machines.
  systemd.network.netdevs."10-vmbr0" = {
    netdevConfig = {
      Name = "vmbr0";
      Kind = "bridge";
    };
  };

  # IP forwarding for bridged traffic.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Configure the bridge with a static address and DHCP server.
  systemd.network.networks."10-vmbr0" = {
    matchConfig.Name = "vmbr0";
    address = [ "172.16.0.1/20" ];
    gateway = [ "172.16.1.1" ];
    networkConfig.DHCPServer = true;
    dhcpServerConfig = rec {
      PoolOffset = 256 + 1;
      PoolSize = 16 * 256 - PoolOffset;
      DefaultLeaseTimeSec = 604800;
      EmitDNS = true;
      DNS = [ "172.16.1.1" ];
      EmitRouter = true;
      Router = [ "172.16.1.1" ];
    };
  };

  # Enable Proxmox VE.
  services.proxmox-ve = {
    enable = true;
    ipAddress = "172.16.0.1";
    bridges = [ "vmbr0" ];
  };
  services.openssh.settings = {
    AcceptEnv = lib.mkForce null;
  };
}
