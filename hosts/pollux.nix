{ config, ... }:

{
  # For now, this is an exact mirror of castor, with a different hostname.
  imports = [
    ./castor.nix
  ];

  # Host identity.
  networking.hostName = "pollux";

  # Upgrade ahead of castor, so the DERP pair never reboots together.
  system.autoUpgrade.dates = "02:40";
}
