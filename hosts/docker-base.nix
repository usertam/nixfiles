{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/docker-image.nix"
  ];

  disabledModules = [ "${modulesPath}/installer/cd-dvd/channel.nix" ];

  documentation.doc.enable = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
  ];

  # Enable zram swap.
  zramSwap.enable = true;
  zramSwap.memoryMax = 1 * 1024 * 1024 * 1024;
}
