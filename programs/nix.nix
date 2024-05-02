{ lib, pkgs, ... }:

{
  nix = {
    # Use unstable version of nix.
    package = pkgs.nixVersions.latest;

    # Lock nixpkgs in registry.
    registry.nixpkgs = {
      from = {
        type = "indirect";
        id = "nixpkgs";
      };
      to = let
        lock = lib.importJSON ../flake.lock;
      in {
        inherit (lock.nodes.nixpkgs.locked) rev;
        type = "github";
        owner = "nixos";
        repo = "nixpkgs";
      };
    };

    # Enable automatic garbage collection.
    gc.automatic = lib.mkDefault true;

    # Everyone loves experimental features!
    settings = {
      experimental-features = [
        "nix-command" "flakes"
        "auto-allocate-uids" "ca-derivations" "configurable-impure-env"
        "dynamic-derivations" "fetch-closure" "fetch-tree" "git-hashing"
        "impure-derivations" "recursive-nix" "repl-flake" "verified-fetches"
      ] ++ lib.optional pkgs.stdenv.isLinux "cgroups";
      auto-allocate-uids = true;
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      use-cgroups = true;
    };
  };
}
