{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/docker-image.nix" ];

  # Host identity.
  networking.hostName = lib.mkOverride 900 "generic-docker";
  system.nixos.tags = lib.mkOverride 900 [ "generic-docker" ];

  documentation.doc.enable = false;

  # Enable zram swap.
  zramSwap.enable = true;
  zramSwap.memoryMax = 1 * 1024 * 1024 * 1024;

  # Define the release attribute be attached to root flake's packages.
  system.build.release = pkgs.runCommand "nixos-tarball-${config.system.nixos.label}-${pkgs.system}" {
    src = config.system.build.tarball;
  } ''
    mkdir -p $out
    cp $src/tarball/*.tar.xz $out/''${name}.tar.xz
  '';
}
