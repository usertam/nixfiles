{ lib, ... }:

{
  # Enable options to boot in UEFI mode.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
