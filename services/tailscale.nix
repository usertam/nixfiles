{ pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    package = pkgs.tailscale.overrideAttrs (prev: {
      doCheck = if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then false else prev.doCheck;
    });
  };
}
