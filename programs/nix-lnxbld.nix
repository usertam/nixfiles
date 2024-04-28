{ ... }:

{
  nix = {
    linux-builder.enable = true;
    settings.extra-trusted-users = [ "@wheel" "@admin" ];
  };
}
