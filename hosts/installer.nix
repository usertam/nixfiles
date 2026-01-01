{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # We didn't pick the latest kernel because ZFS support.
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Host identity.
  networking.hostName = lib.mkOverride 900 "installer";
  system.nixos.tags = lib.mkOverride 900 [ "installer" ];

  services.getty.autologinUser = lib.mkForce "root";
  services.getty.helpLine = lib.mkForce ''

    At last! You have reached the tty of a newly booted up installer image.

    Any of the installed keys will log you in as root:
    ${pkgs.lib.concatMapStringsSep "\n" (key: "    - ${key}") config.users.users.root.openssh.authorizedKeys.keys}

    Mount your disks, maybe run `nixos-generate-config`, then `nixos-install --flake <uri>`.

    Door's open, bed's made. Welcome home.
  '';

  # Mirror this repo to installer's /etc/nixos.
  environment.etc."nixos".source = ./..;

  # Make release image.
  isoImage.compressImage = true;
  system.build.release = config.system.build.isoImage;
}
