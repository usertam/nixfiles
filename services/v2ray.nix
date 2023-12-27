{ lib, config, pkgs, ... }:

{
  services.v2ray = {
    enable = true;
    config = {
      inbounds = lib.singleton {
        port = 8080;
        protocol = "vmess";
        settings.clients = with builtins; let
          uuid = genList (x: "00000000-0000-0000-0000-000000000000") 2;
        in map (x: { id = x; }) uuid;
      };
      outbounds = lib.singleton {
        protocol = "freedom";
        settings = {};
      };
    };
  };

  networking.firewall.allowedTCPPorts = map
    (x: x.port) config.services.v2ray.config.inbounds;

  system.activationScripts."secrets.v2ray" = {
    deps = [ "etc" "agenix" "agenixInstall" ];
    text = ''
      umask 077
      SOURCE=$(readlink -f /etc/v2ray/config.json)
      rm -f /etc/v2ray/config.json
      ${pkgs.gnused}/bin/sed -f ${config.age.secrets.v2ray.path} $SOURCE > /etc/v2ray/config.json
    '';
  };
}
