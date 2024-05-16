{ ... }:

{
  nix = {
    linux-builder.enable = true;
    linux-builder.ephemeral = true;
    settings.extra-trusted-users = [ "@wheel" "@admin" ];
  };
}
