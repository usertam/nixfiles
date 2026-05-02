{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/virtualisation/disk-image.nix"
    ./common/nixos.nix
    ../services/upgrade.nix
  ];

  # Host identity.
  networking.hostName = "fabric";

  # Mission critical machine, do not switch.
  system.autoUpgrade.operation = "boot";

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
  networking.usePredictableInterfaceNames = lib.mkForce true;
  systemd.network.enable = true;
  services.resolved.enable = false;

  # List of interfaces, pinned by MAC.
  systemd.network.links = {
    "10-wan0" = {
      matchConfig.MACAddress = "00:1a:4a:ad:2a:54";
      linkConfig.Name = "wan0";
    };
    "10-lan0" = {
      matchConfig.MACAddress = "00:1a:4a:ad:2a:2c";
      linkConfig.Name = "lan0";
    };
    "10-vm0" = {
      matchConfig.MACAddress = "00:1a:4a:ad:2a:84";
      linkConfig.Name = "vm0";
    };
    "10-vm1" = {
      matchConfig.MACAddress = "00:1a:4a:ad:2a:c7";
      linkConfig.Name = "vm1";
    };
  };

  # WAN. Dynamic config from ISP.
  systemd.network.networks."10-wan0" = {
    matchConfig.Name = "wan0";
    networkConfig.DHCP = "ipv4";
  };

  # LAN. Configure static IP and DHCP server.
  systemd.network.networks."10-lan0" = {
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

  # VM 0. Host handles the DHCP, but we are gateway.
  systemd.network.networks."10-vm0" = {
    matchConfig.Name = "vm0";
    address = [ "172.16.0.10/20" ];
  };

  # VM 1.
  systemd.network.networks."10-vm1" = {
    matchConfig.Name = "vm1";
    address = [ "172.16.16.10/20" ];
  };

  # Firewall. Custom nftables ruleset, NixOS firewall disabled.
  networking.nftables.enable = true;
  networking.firewall.enable = false;

  networking.nftables.ruleset = ''
    define WAN = { "wan0", "wg0", "wg1" }
    define LAN = { "lan0", "vm0", "vm1" }

    table inet filter {
      flowtable forward_offload {
        hook ingress priority filter;
        devices = { "wan0", "wg0", "wg1", "lan0", "vm0", "vm1" };
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

        # Allow DHCP client on wan0, vm0 and vm1.
        iifname { "wan0", "vm0", "vm1" } meta nfproto ipv4 udp dport 68 accept
        iifname { "wan0", "vm0", "vm1" } meta nfproto ipv6 udp dport 546 accept

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
        iifname "lan0" oifname { "vm0", "vm1" } accept
      }

      chain mangle_prerouting {
        type filter hook prerouting priority mangle; policy accept;
      }

      chain mangle_forward {
        type filter hook forward priority mangle; policy accept;
        # MSS clamping for all outgoing interfaces.
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
          "172.16.16.0/20 allow"
          "127.0.0.0/8 allow"
        ];
        local-zone = ''"home." static'';

        # Until we have working IPv6.
        do-ip6 = false;

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

          ip link set wg0 up
          ip link set wg1 up

          ip route show table 100 | grep -q "default dev wg0" || \
              ip route append default dev wg0 table 100

          ip route show table 100 | grep -q "default dev wg1" || \
              ip route append default dev wg1 table 100

          ip route show table 100 | grep -q "blackhole" || \
              ip route add blackhole default metric 100 table 100

          ip rule list | grep -q "fwmark 0x64" || \
              ip rule add fwmark 0x64 table 100 priority 100

          DOMAINS=(
              claude.ai
              gemini.google.com
              chatgpt.com
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
