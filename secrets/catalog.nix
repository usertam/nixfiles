{ lib, config, inputs, ... }:

{
  imports = [ inputs.agenix.nixosModules.default ];

  options.secrets = with lib; mkOption {
    type = with types; attrsOf (submodule ({ config, name, ... }: {
      options.enable = mkEnableOption "including secret in configuration";
      options.path = mkOption {
        type = types.path;
        default = "/run/secrets/" + name;
        description = "Path where the decrypted secret is installed.";
      };
      options.owner = mkOption {
        type = types.str;
        default = "root";
        description = "Owner of secret file.";
      };
      options.group = mkOption {
        type = types.str;
        default = "root";
        description = "Group of secret file.";
      };
    }));
    default = {};
    description = "Attrset of secrets.";
  };

  config.age.secretsDir = "/run/secrets";
  config.age.secretsMountPoint = config.age.secretsDir + ".d";
  config.age.secrets = with builtins; listToAttrs (
    map (x: lib.optionalAttrs config.secrets.${x}.enable {
      name = x;
      value = {
        inherit (config.secrets.${x}) owner group path;
        file = ./. + "/${x}";
      };
    }) (attrNames config.secrets));
}
