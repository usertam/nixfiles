{ config, pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal-new-kernel.nix" ];

  system.nixos.tags = [ "installer" ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
  ];

  # Define the release attribute be attached to root flake's packages.
  system.build.release = pkgs.runCommand "nixos-image-${config.system.nixos.label}-${pkgs.system}" {
    src = config.system.build.isoImage;
    nativeBuildInputs = [ pkgs.pixz ];
  } ''
    mkdir -p $out
    pixz -k $src/iso/*.iso $out/''${name}.iso.xz
  '';
}
