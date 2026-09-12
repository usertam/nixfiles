{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/virtualisation/disk-image.nix"
    ./common/lowmem.nix
    ./common/nixos.nix
    ../services/monitoring.nix
  ];

  # Host identity.
  networking.hostName = lib.mkDefault "fabric";

  # Mission critical machine, do not switch.
  system.autoUpgrade.operation = "boot";

  # Enable auto login as root.
  services.getty.autologinUser = lib.mkDefault "root";

  # Boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0" ];

  # Needed at boot to set nf_conntrack_max.
  boot.kernelModules = [ "nf_conntrack" ];

  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net"
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.netfilter.nf_conntrack_max" = 262144;
  };

  # Networking.
  networking.useNetworkd = true;
  networking.usePredictableInterfaceNames = true;

  # List of interfaces, pinned by MAC.
  systemd.network.links = {
    "10-wan0" = {
      matchConfig.MACAddress = lib.mkDefault "00:1a:4a:ad:2a:54";
      linkConfig.Name = "wan0";
    };
    "20-lan0" = {
      matchConfig.MACAddress = lib.mkDefault "00:1a:4a:ad:2a:2c";
      linkConfig.Name = "lan0";
    };
    "30-vnet0" = {
      matchConfig.MACAddress = lib.mkDefault "00:1a:4a:ad:2a:84";
      linkConfig = { Name = "vnet0"; MTUBytes = "9000"; };
    };
    "40-peer0" = {
      matchConfig.MACAddress = lib.mkDefault "00:1a:4a:ad:2a:c7";
      linkConfig = { Name = "peer0"; MTUBytes = "9000"; };
    };
    "50-vf0" = {
      matchConfig.Path = "pci-0000:01:00.0";
      linkConfig = { Name = "vf0"; MTUBytes = "9000"; };
    };
  };

  # wan0 uses DHCP, lan0 is VIP, vnet0 and peer0 are static.
  systemd.network.networks = {
    "10-wan0" = {
      matchConfig.Name = "wan0";
      networkConfig.DHCP = "ipv4";
      tunnel = [ "he-ipv6" ];
    };
    "20-lan0" = {
      matchConfig.Name = "lan0";
    };
    "30-vnet0" = {
      matchConfig.Name = "vnet0";
      address = lib.mkDefault [ "172.16.0.11/20" ];
    };
    "40-peer0" = {
      matchConfig.Name = "peer0";
      addresses = lib.mkDefault [
        { Address = "172.16.200.1/32"; Peer = "172.16.200.2/32"; }
      ];
    };
    "60-he-ipv6" = let
      prefix = {
        fabric = "2001:470:18:527";
        velvet = "2001:470:18:55c";
      }.${config.networking.hostName};
    in {
      matchConfig.Name = "he-ipv6";
      address = [ "${prefix}::2/64" ];
      routes = lib.singleton {
        Destination = "::/0";
        Gateway = "${prefix}::1";
      };
      # HE sends no RAs; the default route above is all there is.
      networkConfig.IPv6AcceptRA = false;
    };
  };

  # 6in4 to tunnelbroker.net; IPv6 rides a sit device via wan0.
  systemd.network.netdevs."60-he-ipv6" = {
    netdevConfig = {
      Name = "he-ipv6";
      Kind = "sit";
      MTUBytes = "1480";
    };
    tunnelConfig = {
      Local = "dhcp4";
      Remote = "216.218.221.6";
      TTL = 255;
    };
  };

  # Use custom nftables ruleset, disable builtin firewall.
  networking.nftables.enable = true;
  networking.firewall.enable = false;

  networking.nftables.ruleset = ''
    define WAN = { "wan0", "wg0", "wg1", "wg2" }
    define LAN = { "lan0", "vnet0" }

    table inet filter {
      flowtable forward_offload {
        hook ingress priority filter;
        devices = { $WAN, $LAN, "peer0" };
      }

      chain syn_flood {
        limit rate 25/second burst 50 packets return
        drop
      }

      chain input {
        type filter hook input priority filter; policy drop;

        iif "lo" accept

        ct state invalid drop
        ct state { established, related } accept

        # Inter-router link. VRRP/Kea messages rides peer0 only; the VIPs are
        # on lan0 and vnet0. Kept above the reverse path checks.
        iifname "peer0" meta l4proto vrrp accept
        iifname "peer0" meta l4proto ah accept
        iifname "peer0" tcp dport 8000 accept

        fib saddr . iif oif missing drop
        fib daddr . iif type != { local, broadcast, multicast } drop
        tcp flags & (fin | syn | rst | ack) == syn jump syn_flood

        # Accept ICMP and ICMPv6.
        icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded } accept
        icmpv6 type { echo-request, echo-reply, destination-unreachable, time-exceeded, packet-too-big } accept
        icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept

        # Accept DHCP replies on DHCP interfaces.
        iifname { "wan0", "vnet0" } meta nfproto ipv4 udp dport bootpc accept
        iifname { "wan0", "vnet0" } meta nfproto ipv6 udp dport dhcpv6-client accept

        # HE 6in4. The tunnel arrives as IP protocol 41 from the PoP.
        iifname "wan0" ip saddr 216.218.221.6 ip protocol 41 accept

        # LAN. Accept SSH, DNS and DHCP requests, also iperf3.
        iifname $LAN tcp dport ssh accept
        iifname $LAN udp dport domain accept
        iifname $LAN tcp dport domain accept
        iifname $LAN meta nfproto ipv4 udp dport bootps accept
        iifname $LAN meta nfproto ipv6 udp dport dhcpv6-server accept
        iifname $LAN tcp dport 5201 accept
      }

      chain forward {
        type filter hook forward priority filter; policy drop;

        ct state invalid drop
        ct state established flow add @forward_offload
        ct state { established, related } accept

        iifname $LAN oifname $WAN accept

        # HE 6in4. Kept out of $WAN so it stays out of the flowtable;
        # tunnelled flows cannot be offloaded.
        iifname $LAN oifname "he-ipv6" accept
        iifname "lan0" oifname "vnet0" accept
      }

      chain mangle_prerouting {
        type filter hook prerouting priority mangle; policy accept;
      }

      chain mangle_forward {
        type filter hook forward priority mangle; policy accept;
        # Override MSS for outgoing traffic.
        oifname $WAN tcp flags & (fin | syn | rst) == syn tcp option maxseg size set rt mtu
        oifname "he-ipv6" tcp flags & (fin | syn | rst) == syn tcp option maxseg size set rt mtu
      }
    }

    table ip nat {
      chain srcnat {
        type nat hook postrouting priority srcnat; policy accept;
        oifname $WAN masquerade
      }
    }
  '';

  networking.nftables.preCheckRuleset = ''
    sed -i 's/devices = .*/devices = { lo };/g' ruleset.conf
    sed -i '/flow add @ft/d' ruleset.conf
  '';

  # iperf3 server. Firewall limits it to $LAN.
  services.iperf3.enable = true;

  # DHCP server. Both nodes always run kea; the HA hook decides
  # which node answers DHCP and shadows leases to the other.
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      # lan0 only has an address while this node holds the VIP, so the
      # standby runs socketless.
      interfaces-config = {
        interfaces = [ "lan0" ];
        service-sockets-max-retries = 5;
        service-sockets-retry-wait-time = 2000;
      };
      valid-lifetime = 604800;

      # HTTP control channel for the HA hook to talk to the partner kea.
      # Bound on peer0 so inter-router chat stays off every shared segment.
      control-sockets = lib.singleton {
        socket-type = "http";
        socket-address = {
          fabric = "172.16.200.1";
          velvet = "172.16.200.2";
        }.${config.networking.hostName};
        socket-port = 8000;
      };

      # HA hook, hot-standby.
      # lease_cmds is required so HA can call lease4-get-page during sync.
      hooks-libraries = [
        { library = "${pkgs.kea}/lib/kea/hooks/libdhcp_lease_cmds.so"; }
        {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_ha.so";
          parameters.high-availability = lib.singleton {
            this-server-name = config.networking.hostName;
            mode = "hot-standby";
            # Reuse the top-level control socket; don't open a second listener.
            multi-threading = {
              enable-multi-threading = true;
              http-dedicated-listener = false;
            };
            sync-leases = true;
            send-lease-updates = true;
            heartbeat-delay = 1000;
            max-response-delay = 6000;
            # Take over when heartbeat fails and client request is dropped.
            max-unacked-clients = 1;
            peers = [
              { name = "fabric"; url = "http://172.16.200.1:8000/"; role = "primary"; auto-failover = true; }
              { name = "velvet"; url = "http://172.16.200.2:8000/"; role = "standby"; auto-failover = true; }
            ];
          };
        }
      ];

      subnet4 = lib.singleton {
        id = 1;
        subnet = "192.168.1.0/24";
        pools = lib.singleton {
          pool = "192.168.1.101 - 192.168.1.253";
        };
        option-data = [
          { name = "routers"; data = "192.168.1.1"; }
          { name = "domain-name-servers"; data = "192.168.1.1"; }
        ];
      };

      loggers = [
        # Silence per-heartbeat COMMAND_RECEIVED chatter from the HA hook.
        {
          name = "kea-dhcp4.commands";
          severity = "WARN";
          output_options = lib.singleton { output = "stdout"; };
        }
        # Silence per-heartbeat spurious DHCP_RECEIVE4_UNKNOWN warnings
        # (kea#4625); errors from the socket layer still get through.
        {
          name = "kea-dhcp4.dhcp";
          severity = "ERROR";
          output_options = lib.singleton { output = "stdout"; };
        }
      ];
    };
    # Demote security errors to allow unsecured HTTP control channel.
    extraArgs = [ "-X" ];
  };

  # VRRP. Instances bundled in sync_group ROUTER so they failover together.
  services.keepalived = {
    enable = true;

    # Health check: ping the WAN gateway (whatever DHCP gave us) via wan0.
    # Detects gateway reachability failures while wan0 link stays up;
    # carrier loss is handled instantly by track_interface below.
    vrrpScripts.check_wan = {
      script = lib.getExe (pkgs.writeShellApplication {
        name = "check-wan";
        runtimeInputs = with pkgs; [ iproute2 gawk iputils ];
        text = ''
          gw=$(ip -4 route show default dev wan0 | awk '{print $3; exit}')
          [ -n "$gw" ] || exit 1
          ping -I wan0 -n -q -c 2 -W 1 "$gw" &>/dev/null
        '';
      });
      interval = 3;
      timeout = 2;
      fall = 3;
      rise = 2;
      weight = -200;
      user = "root";
      group = "root";
    };

    vrrpInstances = {
      lan0 = {
        interface = "peer0";
        state = lib.mkDefault "MASTER";
        virtualRouterId = 51;
        priority = lib.mkDefault 200;
        virtualIps = lib.singleton {
          addr = "192.168.1.1/24";
          dev = "lan0";
        };
      };
      vnet0 = {
        interface = "peer0";
        state = lib.mkDefault "MASTER";
        virtualRouterId = 52;
        priority = lib.mkDefault 200;
        virtualIps = lib.singleton {
          addr = "172.16.0.10/20";
          dev = "vnet0";
        };
      };
    };

    extraConfig = ''
      global_defs {
        enable_script_security
        script_user root
      }
      vrrp_sync_group ROUTER {
        group { lan0 vnet0 }
        track_interface { lan0 wan0 }
        track_script { check_wan }
        notify_master "${pkgs.systemd}/bin/systemctl restart kea-dhcp4-server"
        notify_fault  "${pkgs.systemd}/bin/systemctl stop kea-dhcp4-server"
      }
    '';
  };

  # DNS. Unbound resolver bound to the LAN-side VIPs (claimed by keepalived).
  services.unbound = {
    enable = true;
    settings = {
      server = {
        # respip module is required for rpz blocks to take effect.
        module-config = ''"respip validator iterator"'';

        # ip-freebind lets unbound start before VRRP claims the VIPs (BACKUP state).
        ip-freebind = "yes";

        interface = [
          "192.168.1.1"
          "172.16.0.10"
          "127.0.0.1"
        ];
        access-control = [
          "0.0.0.0/0 allow"
          "::/0 allow"
        ];
        local-zone = ''"home." static'';

        do-ip6 = true;

        so-rcvbuf = "8m";
        so-sndbuf = "8m";
        msg-cache-size = "16m";
        rrset-cache-size = "32m";
        neg-cache-size = "2m";
        edns-buffer-size = 1232;

        harden-large-queries = true;
        harden-glue = true;
        harden-algo-downgrade = true;
        harden-unknown-additional = true;
        use-caps-for-id = true;
        unwanted-reply-threshold = 10000000;

        prefetch = true;
        prefetch-key = true;
      };
      remote-control.control-enable = true;
      rpz = {
        name = "rpz.hagezi-ultimate";
        zonefile = "hagezi-ultimate.zone";
        url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/rpz/ultimate.txt";
        rpz-action-override = "nxdomain";
      };
    };
  };

  # VPN policy routing. Resolve domains and re-route traffic.
  systemd.services.vpn-policy-routing =
    let
      vpn-policy-routing = pkgs.writeShellApplication {
        name = "vpn-policy-routing";
        runtimeInputs = with pkgs; [ iproute2 nftables dig gnugrep ];
        text = ''
          ip link show wg0 >/dev/null 2>&1 || \
              ip link add wg0 type wireguard
          ip link show wg1 >/dev/null 2>&1 || \
              ip link add wg1 type wireguard

          ip route show table 100 | grep -q "^default" || \
              ip route add default table 100 \
                  nexthop dev wg0 weight 1 \
                  nexthop dev wg1 weight 1

          ip route show table 100 | grep -q "blackhole" || \
              ip route add blackhole default metric 100 table 100

          ip rule list | grep -q "fwmark 0x64" || \
              ip rule add fwmark 0x64 table 100 priority 100

          DOMAINS=(
              claude.ai
              anthropic.com
              chatgpt.com
              openai.com
              auth.openai.com
              tiktok.com
              www.tiktok.com
          )

          mapfile -t IPS < <(
              for D in "''${DOMAINS[@]}"; do dig +short A "$D"; done \
              | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
              | sort -u -t. -k1,1n -k2,2n -k3,3n -k4,4n
          )

          if (( ''${#IPS[@]} == 0 )); then
              echo "no IPs resolved, skipping nft rules" >&2
              exit 1
          fi

          SET="$(IFS=', '; echo "''${IPS[*]}")"

          nft add set inet filter vpn_targets '{ type ipv4_addr; flags interval; }'
          nft -a list chain inet filter mangle_prerouting 2>/dev/null | grep -q "vpn-policy-routing" \
              || nft add rule inet filter mangle_prerouting \
                  ip daddr @vpn_targets meta mark set 0x64 comment "vpn-policy-routing"

          # Atomically refresh the vpn_targets set.
          printf 'flush set inet filter vpn_targets\nadd element inet filter vpn_targets { %s }\n' "$SET" | nft -f -
          echo "vpn_targets updated: { $SET }"

          if ! nft -a list chain inet filter forward 2>/dev/null | grep -q "vpn-policy-routing-fwd"; then
              nft insert rule inet filter forward \
                  meta mark 0x64 oifname "{ wg0, wg1 }" accept comment "vpn-policy-routing-fwd"
          fi

          if ! nft -a list chain ip nat srcnat 2>/dev/null | grep -q "vpn-policy-routing-nat"; then
              nft insert rule ip nat srcnat \
                  oifname "{ wg0, wg1 }" masquerade comment "vpn-policy-routing-nat"
          fi
        '';
      };
    in
    {
      description = "VPN policy routing for selected domains";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe vpn-policy-routing;
      };
    };

  systemd.timers.vpn-policy-routing = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
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
