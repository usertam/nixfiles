{ config, pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/docker-image.nix" ];

  disabledModules = [ "${modulesPath}/installer/cd-dvd/channel.nix" ];

  system.nixos.tags = [ "docker" ];

  documentation.doc.enable = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
  ];

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
