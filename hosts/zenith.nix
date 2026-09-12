{ inputs, config, system, lib, pkgs, ... }:

{
  imports = [
    inputs.proxmox-nixos.nixosModules.proxmox-ve
    ./common/nixos.nix
    ../services/monitoring.nix
    # TODO: ../services/lanzaboote.nix
  ];

  nixpkgs.overlays = [
    inputs.proxmox-nixos.overlays.${system}
  ];

  # Host identity.
  networking.hostName = "zenith";

  # Mission critical machine, do not switch.
  system.autoUpgrade.operation = "boot";

  # Enable auto login as root.
  services.getty.autologinUser = lib.mkDefault "root";

  # Boot stuff.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # From auto hardware detection.
  boot.initrd.availableKernelModules = [
    "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-amd"
  ];

  # Enable ZFS support.
  boot.supportedFilesystems.zfs = true;
  boot.zfs.forceImportRoot = true;

  # Enable microcode updates.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Configure VFIO passthrough for USB 3.1 (Type-C) [1022:15b7].
  boot.kernelParams = [ "iommu=pt" "vfio-pci.ids=1022:15b7" ];
  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];

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
    };
  };

  # Manually provision /etc/nixos on this host.
  environment.etc."nixos".enable = false;

  # Networking.
  networking.useNetworkd = true;
  networking.usePredictableInterfaceNames = lib.mkForce true;

  # Reassign physical NICs, to be enslaved by bridges.
  systemd.network.links = {
    "10-wan0" = {
      matchConfig.PermanentMACAddress = "38:05:25:30:8f:7e";
      linkConfig = {
        Name = "wan0";
        MACAddress = "00:1a:4a:0d:51:70";
      };
    };
    "20-lan0" = {
      matchConfig.PermanentMACAddress = "38:05:25:30:8f:7d";
      linkConfig = {
        Name = "lan0";
        MACAddress = "00:1a:4a:0d:51:47";
      };
    };
  };

  # Bridges.
  systemd.network.netdevs = {
    "10-wanbr0".netdevConfig = {
      Name = "wanbr0";
      Kind = "bridge";
    };
    "20-lanbr0".netdevConfig = {
      Name = "lanbr0";
      Kind = "bridge";
    };
    "30-vnet0".netdevConfig = {
      Name = "vnet0";
      Kind = "bridge";
    };
    "40-peer0".netdevConfig = {
      Name = "peer0";
      Kind = "bridge";
    };
    "50-peer1".netdevConfig = {
      Name = "peer1";
      Kind = "bridge";
    };
  };

  systemd.network.networks = {
    # WAN bridge, let router do the DHCP itself.
    "10-wanbr0" = {
      matchConfig.Name = "wanbr0";
      networkConfig = {
        LinkLocalAddressing = "no";
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    };

    # LAN bridge, delegate DHCP, DNS and gateway to router.
    "20-lanbr0" = {
      matchConfig.Name = "lanbr0";
      networkConfig = {
        LinkLocalAddressing = "no";
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    };

    # Enslave the physicals to their bridges.
    "15-wan0" = {
      matchConfig.Name = "wan0";
      networkConfig.Bridge = "wanbr0";
    };
    "25-lan0" = {
      matchConfig.Name = "lan0";
      networkConfig.Bridge = "lanbr0";
    };

    # Main network for VMs. Handle DHCP, delegate DNS and gateway to router.
    "30-vnet0" = {
      matchConfig.Name = "vnet0";
      address = [ "172.16.0.1/20" ];
      routes = lib.singleton {
        Gateway = "172.16.0.10";
        Metric = 100;
      };
      networkConfig.DHCPServer = true;
      linkConfig.RequiredForOnline = "no";
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

    # Router peer bridge, let routers do their thing.
    "40-peer0" = {
      matchConfig.Name = "peer0";
      networkConfig = {
        LinkLocalAddressing = "no";
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    };

    # VM pair peer bridge.
    "50-peer1" = {
      matchConfig.Name = "peer1";
      networkConfig = {
        LinkLocalAddressing = "no";
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  # Open port for DHCP requests.
  networking.firewall.interfaces."vnet0".allowedUDPPorts = [ 67 ];

  # Enable Proxmox VE.
  services.proxmox-ve = {
    enable = true;
    ipAddress = "172.16.0.1";
    bridges = [ "wanbr0" "lanbr0" "vnet0" "peer0" "peer1" ];
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
