{ modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64-new-kernel.nix"
  ];

  # Host identity.
  networking.hostName = "slate";
  system.nixos.tags = [ "slate" ];
}
