{ ... }:

{
  # For now, this is an exact mirror of castor, with a different hostname.
  imports = [
    ./castor.nix
  ];

  # Host identity.
  networking.hostName = "pollux";
}
