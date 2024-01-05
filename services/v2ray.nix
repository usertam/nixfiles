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

  secrets."v2ray".enable = true;

  # Secrets management is a lot messier when DynamicUser is involved.
  # Add wrapper before ExecStart to make daemon wait for secrets.
  # Can't use before/after, the user "v2ray" only exists during exec.
  services.v2ray.package = let
    wrapper = pkgs.writeScript "v2ray-wrapper" ''
      #!${pkgs.runtimeShell} -e
      echo "Waiting for config to be decrypted..."
      until [ -r /etc/v2ray/config.json ]; do
        sleep 1
      done
      exec "$@"
    '';
  in pkgs.runCommand "v2ray" {
    buildInputs = [ pkgs.v2ray ];
  } ''
    mkdir -p $out/lib/systemd/system
    cp -a ${pkgs.v2ray}/* $out
    substituteInPlace $out/lib/systemd/system/v2ray.service \
      --replace "ExecStart=" "ExecStart=${wrapper} "
  '';

  # Decrypt secrets and write to /etc/v2ray/config.json; wanted by v2ray.
  systemd.services."secrets.v2ray" = {
    wantedBy = [ "multi-user.target" "v2ray.service" ];
    serviceConfig = let
      configJSON = with builtins;
        toFile "config.json" (toJSON config.services.v2ray.config);
    in {
      Type = "oneshot";
      UMask = 0077;
      ExecStart = pkgs.writeScript "secrets.v2ray" ''
        #!${pkgs.runtimeShell} -e
        rm -f /etc/v2ray/config.json
        ${pkgs.gnused}/bin/sed -f ${config.age.secrets.v2ray.path} \
          ${configJSON} > /etc/v2ray/config.json
        chown v2ray:v2ray /etc/v2ray/config.json
      '';
    };
  };
}
