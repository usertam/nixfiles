{ inputs, config, system, lib, pkgs, ... }:

{
  imports = [
    inputs.proxmox-nixos.nixosModules.proxmox-ve
    ./common/nixos.nix
    # TODO: ../services/lanzaboote.nix
    ../services/upgrade.nix
  ];

  nixpkgs.overlays = [
    inputs.proxmox-nixos.overlays.${system}
  ];

  # Host identity.
  networking.hostName = "zenith";

  # Mission critical machine, do not switch.
  system.autoUpgrade.operation = "boot";

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

  # Configure VFIO passthrough for USB 3.1 (Type-C) [1022:15b7].
  boot.kernelParams = [ "amd_iommu=on" "iommu=pt" "vfio-pci.ids=1022:15b7" ];
  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
  boot.extraModprobeConfig = "options vfio-pci ids=1022:15b7";

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
      # Guess what? You can silently race /dev/disk/by-label/ESP!
      device = "/dev/disk/by-partuuid/ef6784fc-e176-4dbc-a623-389eab2f76be";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };

  # Manually provision /etc/nixos on this host.
  environment.etc."nixos".enable = false;

  # Networking.
  networking.useNetworkd = true;
  networking.usePredictableInterfaceNames = lib.mkForce true;
  systemd.network.enable = true;
  services.resolved.enable = true;

  # Reassign physical NICs, to be enslaved by bridges.
  systemd.network.links = {
    "10-wan0" = {
      matchConfig.PermanentMACAddress = "38:05:25:30:8f:7e";
      linkConfig = {
        Name = "wan0";
        MACAddress = "00:1a:4a:0d:51:70";
      };
    };
    "10-lan0" = {
      matchConfig.PermanentMACAddress = "38:05:25:30:8f:7d";
      linkConfig = {
        Name = "lan0";
        MACAddress = "00:1a:4a:0d:51:47";
      };
    };
  };

  # Bridges.
  systemd.network.netdevs = {
    "15-vm-br0".netdevConfig = {
      Name = "vm-br0";
      Kind = "bridge";
    };
    "15-vm-br1".netdevConfig = {
      Name = "vm-br1";
      Kind = "bridge";
    };
    "15-wan-br0".netdevConfig = {
      Name = "wan-br0";
      Kind = "bridge";
    };
    "15-lan-br0".netdevConfig = {
      Name = "lan-br0";
      Kind = "bridge";
    };
  };

  # IP forwarding for bridged traffic.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # WAN bridge. Pure L2, no IP on zenith — fabric is the WAN-facing host.
  systemd.network.networks."20-wan-br0" = {
    matchConfig.Name = "wan-br0";
    networkConfig = {
      LinkLocalAddressing = "no";
      IPv6AcceptRA = false;
      ConfigureWithoutCarrier = true;
    };
    linkConfig.RequiredForOnline = "no";
  };

  # Bridges for LAN.
  systemd.network.networks."20-lan-br0" = {
    matchConfig.Name = "lan-br0";
    networkConfig = {
      LinkLocalAddressing = "no";
      IPv6AcceptRA = false;
      ConfigureWithoutCarrier = true;
    };
    linkConfig.RequiredForOnline = "no";
  };

  # Bridge for VM 0. Configure static IP, DHCP server, default gateway.
  systemd.network.networks."20-vm-br0" = {
    matchConfig.Name = "vm-br0";
    address = [ "172.16.0.1/20" ];
    routes = lib.singleton {
      Gateway = "172.16.0.10";
      Metric = 100;
    };
    networkConfig.DHCPServer = true;
    dhcpServerConfig = rec {
      # Reserve up to 172.16.0.10.
      PoolOffset = 11;
      # Exclude broadcast address.
      PoolSize = 16 * 256 - PoolOffset - 1;
      DefaultLeaseTimeSec = 604800;
      EmitDNS = true;
      DNS = [ "172.16.0.10" ];
      EmitRouter = true;
      Router = [ "172.16.0.10" ];
    };
  };

  # Bridge for VM 1. Configure higher metric gateway.
  systemd.network.networks."20-vm-br1" = {
    matchConfig.Name = "vm-br1";
    address = [ "172.16.16.1/20" ];
    routes = lib.singleton {
      Gateway = "172.16.16.10";
      Metric = 200;
    };
    networkConfig.DHCPServer = true;
    dhcpServerConfig = rec {
      # Reserve up to 172.16.16.10.
      PoolOffset = 11;
      # Exclude broadcast address.
      PoolSize = 16 * 256 - PoolOffset - 1;
      DefaultLeaseTimeSec = 604800;
      EmitDNS = true;
      DNS = [ "172.16.16.10" ];
      EmitRouter = true;
      Router = [ "172.16.16.10" ];
    };
  };

  # Enslave the physicals to their bridges.
  systemd.network.networks = {
    "25-wan0" = {
      matchConfig.Name = "wan0";
      networkConfig = {
        Bridge = "wan-br0";
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
    "25-lan0" = {
      matchConfig.Name = "lan0";
      networkConfig = {
        Bridge = "lan-br0";
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  # Open port for DHCP requests.
  networking.firewall.interfaces = {
    "vm-br0".allowedUDPPorts = [ 67 ];
    "vm-br1".allowedUDPPorts = [ 67 ];
  };

  # Enable Proxmox VE.
  services.proxmox-ve = {
    enable = true;
    ipAddress = "172.16.0.1";
    bridges = [ "vm-br0" "vm-br1" "wan-br0" "lan-br0" ];
  };
  services.openssh.settings = {
    AcceptEnv = lib.mkForce null;
  };

  # Break pvedaemon's dependency on network-online.target.
  systemd.services.corosync.after = lib.mkForce [ ];

  # Fill in the missing ZFS paths for autostart.
  # https://github.com/SaumonNet/proxmox-nixos/issues/122
  systemd.services.pvedaemon = {
    path = [ config.boot.zfs.package ];
  };
  systemd.services.pve-guests = {
    path = [ config.boot.zfs.package ];
    after = [ "zfs-import.target" "zfs.target" ];
    wants = [ "zfs-import.target" ];
  };

  # The proxmox-ve package ships util-linux's login(1), which uses the "remote"
  # PAM service (via -h flag) for remote logins. Tailscale SSH invokes login -h,
  # and without /etc/pam.d/remote the account phase falls through to pam_deny.
  security.pam =
    let
      pkgs' = inputs.proxmox-nixos.inputs.nixpkgs-stable.legacyPackages.${system};
    in
    {
      package = pkgs'.pam;
      services."remote" = {
        unixAuth = true;
        updateWtmp = true;
        rules.session.lastlog = {
          modulePath = lib.mkForce "${pkgs'.util-linux.lastlog}/lib/security/pam_lastlog2.so";
          settings.silent = lib.mkForce false;
        };
      };
    };

  # Fallback password for web portal login.
  users.users.root.hashedPassword = "$y$j9T$OJuNmMHbAjNdSc4NzVylD1$8TXgt2z07V6V12M1uPk0DylMqJMW7vpqLXHofxzHjy8";
}
