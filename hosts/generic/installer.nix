{ config, pkgs, modulesPath, ... }:

{
  # Original installation-cd-minimal-new-kernel incompatible with old ZFS release.
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  system.nixos.tags = [ "installer" ];

  # Define the release attribute be attached to root flake's packages.
  system.build.release = pkgs.runCommand "nixos-image-${config.system.nixos.label}-${pkgs.system}" {
    src = config.system.build.isoImage;
    nativeBuildInputs = [ pkgs.pixz ];
  } ''
    mkdir -p $out
    pixz -k $src/iso/*.iso $out/''${name}.iso.xz
  '';
}
