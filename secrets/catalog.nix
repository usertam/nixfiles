{ lib, config, inputs, ... }:

{
  imports = [ inputs.agenix.nixosModules.default ];

  options.secrets = with lib; mkOption {
    type = types.attrsOf (types.submodule ({ config, ... }: {
      options.enable = mkEnableOption "including secret in configuration";
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

  config.age.secrets = with builtins; listToAttrs (
    map (x: lib.optionalAttrs config.secrets.${x}.enable {
      name = x;
      value = {
        inherit (config.secrets.${x}) owner group;
        file = ./. + "/${x}";
      };
    }) (attrNames config.secrets));
}
