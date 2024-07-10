{ lib, ... }:

{
  nix = {
    linux-builder.enable = true;
    linux-builder.ephemeral = true;
    settings.trusted-users = lib.mkDefault [];
  };
}
