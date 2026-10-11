{ config, lib, pkgs, ... }:

{
  options.services.opndrive = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "drive.usertam.dev";
      description = "Domain of the nginx virtual host to serve opndrive on.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./pkgs/opndrive/package.nix { };
      description = "The opndrive package to use.";
    };
    socket = lib.mkOption {
      type = lib.types.path;
      default = "/run/opndrive/opndrive.sock";
      description = "Path of the unix socket opndrive listens on, for nginx.";
    };
  };

  config = {
    # The package has Next.js take this socket, in place of a TCP port.
    systemd.sockets.opndrive = {
      description = "Opndrive socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = config.services.opndrive.socket;
        # Only nginx gets to connect.
        SocketUser = config.services.nginx.user;
        SocketMode = "0600";
      };
    };

    # Stateless; S3 credentials live in the browser, never reach the server.
    # Started on demand by the socket.
    systemd.services.opndrive = {
      description = "Opndrive, web interface for S3-compatible storage";
      requires = [ "opndrive.socket" ];
      after = [ "opndrive.socket" ];
      # Canonical origin for metadata, sitemap and robots.txt.
      environment.SITE_URL = "https://${config.services.opndrive.domain}";
      serviceConfig = {
        ExecStart = lib.getExe config.services.opndrive.package;
        Restart = "on-failure";
        DynamicUser = true;
        # Backs the .next/cache symlink in the package.
        CacheDirectory = "opndrive";
        # Serves only the inherited socket, so no network at all.
        PrivateNetwork = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        # No MemoryDenyWriteExecute, as V8 needs to JIT.
        CapabilityBoundingSet = "";
        LockPersonality = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${config.services.opndrive.domain} = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://unix:${config.services.opndrive.socket}";
          # The app picks its CSP by X-Forwarded-Proto, so it must be passed on.
          recommendedProxySettings = true;
          # Relay streamed server component responses as they come, unbuffered.
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
