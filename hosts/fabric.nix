{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./common/nixos.nix
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/virtualisation/disk-image.nix"
  ];

  # Host identity.
  networking.hostName = "fabric";

  # Boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=ttyS0" ];

  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net"
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Networking.
  networking.useNetworkd = true;
  networking.usePredictableInterfaceNames = true;
  systemd.network.enable = true;
  services.resolved.enable = false;

  # Interface naming. Pin interfaces by MAC.
  systemd.network.links."10-wan" = {
    matchConfig.MACAddress = "38:05:25:30:8f:7e";
    linkConfig.Name = "wan0";
  };
  systemd.network.links."10-lan" = {
    matchConfig.MACAddress = "38:05:25:30:8f:7d";
    linkConfig.Name = "lan0";
  };
  systemd.network.links."10-vmbr0" = {
    matchConfig.MACAddress = "bc:24:11:06:71:cb";
    linkConfig.Name = "vmbr0";
  };

  # WAN, Intel I226-V PCI passthrough.
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "wan0";
    networkConfig.DHCP = "ipv4";
    networkConfig.MACVLAN = [ "macvlan0" ];
    dhcpV4Config.RouteMetric = 0;
  };

  # Secondary WAN, create macvlan0 on wan0. Lower priority.
  systemd.network.netdevs."20-macvlan0" = {
    netdevConfig = {
      Name = "macvlan0";
      Kind = "macvlan";
      MACAddress = "38:05:25:c2:4a:04";
    };
    macvlanConfig.Mode = "bridge";
  };
  systemd.network.networks."20-macvlan0" = {
    matchConfig.Name = "macvlan0";
    networkConfig.DHCP = "ipv4";
    dhcpV4Config.RouteMetric = 10;
  };

  # LAN, Realtek RTL8125 PCI passthrough. Static + DHCP server.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "lan0";
    address = [ "192.168.1.1/24" ];
    networkConfig.DHCPServer = true;
    dhcpServerConfig = {
      PoolOffset = 100;
      PoolSize = 154;
      DefaultLeaseTimeSec = 604800; # 7 days
      EmitDNS = true;
      DNS = [ "192.168.1.1" ];
      EmitRouter = true;
      Router = [ "192.168.1.1" ];
    };
  };

  # Virtio NIC bridged to zenith.
  systemd.network.networks."10-vmbr0" = {
    matchConfig.Name = "vmbr0";
    address = [ "172.16.1.1/20" ];
  };

  # Firewall. Custom nftables ruleset, NixOS firewall disabled.
  networking.nftables.enable = true;
  networking.firewall.enable = false;

  networking.nftables.ruleset = ''
    define WAN = { "wan0", "macvlan0", "wg0" }
    define LAN = { "lan0", "vmbr0" }

    table inet filter {
      flowtable forward_offload {
        hook ingress priority filter;
        devices = { "wan0", "macvlan0", "wg0", "lan0", "vmbr0" };
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

        fib saddr . iif oif missing drop
        fib daddr . iif type != { local, broadcast, multicast } drop
        tcp flags & (fin | syn | rst | ack) == syn jump syn_flood

        icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded } accept
        icmpv6 type { echo-request, echo-reply, destination-unreachable, time-exceeded, packet-too-big } accept
        icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept

        # Allow DHCP client on wan0 and vmbr0.
        iifname { "wan0", "vmbr0" } meta nfproto ipv4 udp dport 68 accept
        iifname { "wan0", "vmbr0" } meta nfproto ipv6 udp dport 546 accept

        # LAN, allow SSH, DNS and DHCP server.
        iifname $LAN tcp dport 22 accept
        iifname $LAN udp dport 53 accept
        iifname $LAN tcp dport 53 accept
        iifname $LAN meta nfproto ipv4 udp dport 67 accept
        iifname $LAN meta nfproto ipv6 udp dport 547 accept
      }

      chain forward {
        type filter hook forward priority filter; policy drop;

        ct state invalid drop
        ct state established flow add @forward_offload
        ct state { established, related } accept

        iifname $LAN oifname $WAN accept
      }

      chain mangle_prerouting {
        type filter hook prerouting priority mangle; policy accept;
        # VPN policy marks (fwmark 0x64), populated by vpn-policy-routing service.
      }

      chain mangle_forward {
        type filter hook forward priority mangle; policy accept;
        # MSS clamping for all interfaces (covers wan0, wg0, macvlan0/1).
        tcp flags & (fin | syn | rst) == syn tcp option maxseg size set rt mtu
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

  # DNS. Unbound resolver on all LAN interfaces.
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "192.168.1.1" "172.16.1.1" "127.0.0.1" ];
        access-control = [
          "192.168.1.0/24 allow"
          "172.16.0.0/20 allow"
          "127.0.0.0/8 allow"
        ];
        local-zone = ''"home." static'';

        so-rcvbuf = "8m";
        so-sndbuf = "8m";
        msg-cache-size = "16m";
        rrset-cache-size = "32m";
        neg-cache-size = "2m";

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
    };
  };

  # VPN policy routing. Resolve domains and re-route traffic.
  systemd.services.vpn-policy-routing =
    let
      vpn-policy-routing = pkgs.writeShellApplication {
        name = "vpn-policy-routing";
        runtimeInputs = with pkgs; [ iproute2 nftables dig gnugrep ];
        text = ''
          IFACES=(wg0)
          NFT_IFACES="$(IFS=', '; echo "''${IFACES[*]}")"

          DOMAINS=(
              claude.ai
              gemini.google.com
              chatgpt.com
              tiktok.com
              www.tiktok.com
          )

          for IFACE in "''${IFACES[@]}"; do
              ip link show "$IFACE" &>/dev/null || continue
              ip route show table 100 | grep -q "default dev $IFACE" || \
                  ip route add default dev "$IFACE" table 100 2>/dev/null
          done

          ip rule list | grep -q "fwmark 0x64" || \
              ip rule add fwmark 0x64 table 100 priority 100

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

          EXISTING=$(
              nft -a list chain inet filter mangle_prerouting 2>/dev/null \
              | grep "vpn-policy-routing" \
              | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
              || true
          )

          if [[ "$(printf '%s\n' "''${IPS[@]}")" != "$EXISTING" ]]; then
              nft -a list chain inet filter mangle_prerouting 2>/dev/null \
              | grep "vpn-policy-routing" | grep -oP 'handle \K[0-9]+' \
              | while read -r H; do
                  nft delete rule inet filter mangle_prerouting handle "$H"
              done || true
              nft insert rule inet filter mangle_prerouting \
                  ip daddr "{ $SET }" meta mark set 0x64 comment "vpn-policy-routing"
              echo "mangle rule updated: { $SET }"
          else
              echo "mangle rule already up to date"
          fi

          if ! nft -a list chain inet filter forward 2>/dev/null | grep -q "vpn-policy-routing-fwd"; then
              nft insert rule inet filter forward \
                  meta mark 0x64 oifname "{ $NFT_IFACES }" accept comment "vpn-policy-routing-fwd"
          fi

          if ! nft -a list chain ip nat srcnat 2>/dev/null | grep -q "vpn-policy-routing-nat"; then
              nft insert rule ip nat srcnat \
                  oifname "{ $NFT_IFACES }" masquerade comment "vpn-policy-routing-nat"
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
