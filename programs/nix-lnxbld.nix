{ lib, ... }:

{
  nix = {
    linux-builder.enable = true;
    linux-builder.ephemeral = true;
    linux-builder.config.virtualisation.cores = 4;
    linux-builder.config.nix.extraOptions = "keep-failed = true";
    settings.trusted-users = lib.mkDefault [];
  };
}
