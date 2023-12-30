{ lib, config, ... }:

{
  options.secrets = with lib; mkOption {
    type = types.attrsOf (types.submodule ({ config, ... }: {
      options.require = mkEnableOption "including secret in configuration";
    }));
    default = {};
    description = "Attrset of secrets.";
  };

  config.age.secrets = with builtins; foldl' (x: y: x // y) {} (
    map (x: lib.optionalAttrs config.secrets.${x}.require { ${x}.file = ./. + x; })
      (attrNames config.secrets));
}
