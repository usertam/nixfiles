{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.niks3.nixosModules.niks3
  ];

  services.niks3 = {
    enable = true;

    serverPackage = inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.niks3-server.overrideAttrs {
      postPatch = ''
        cp ${./niks3_index.html} server/landing_page.html
      '';
    };

    cacheUrl = "https://cache.usertam.dev";
    serverUrl = "https://niks3.usertam.dev";

    s3 = {
      endpoint = "98c7fa0ff64c0acb3bcafb1cfd60e43f.r2.cloudflarestorage.com";
      bucket = "niks3";
      region = "auto";
      accessKeyFile = "/var/lib/niks3/s3-access-key";
      secretKeyFile = "/var/lib/niks3/s3-secret-key";
    };

    apiTokenFile = "/var/lib/niks3/api-token";
    signKeyFiles = [ "/var/lib/niks3/nix-sign-key" ];

    oidc.providers = {
      github = {
        issuer = "https://token.actions.githubusercontent.com";
        audience = "https://niks3.usertam.dev";
        boundClaims = {
          repository = [
            "usertam/nixfiles"
            "usertam/nixfiles-home"
          ];
        };
      };
    };

    nginx = {
      enable = true;
      domain = "niks3.usertam.dev";
      enableACME = true;
      forceSSL = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "infra@usertam.dev";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  systemd.services.niks3 = {
    path = [
      pkgs.coreutils
      config.nix.package
    ];
    preStart = ''
      set -eu
      umask 077

      if [ ! -s /var/lib/niks3/api-token ]; then
        LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 72 | fold -w8 | paste -sd- - > /var/lib/niks3/api-token
        echo "generated /var/lib/niks3/api-token"
      fi

      if [ ! -s /var/lib/niks3/nix-sign-key ]; then
        nix key generate-secret --key-name cache.usertam.dev-1 > /var/lib/niks3/nix-sign-key
        echo "generated /var/lib/niks3/nix-sign-key"
      fi
    '';
    unitConfig = {
      ConditionPathExists = [
        "/var/lib/niks3/s3-access-key"
        "/var/lib/niks3/s3-secret-key"
      ];
    };
  };
}
