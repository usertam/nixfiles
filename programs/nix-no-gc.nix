{ ... }:

{
  # Disable garbage collection.
  nix.gc.automatic = false;

  # Keep all outputs and derivations.
  nix.extraOptions = ''
    keep-outputs = true
    keep-derivations = true
  '';
}
