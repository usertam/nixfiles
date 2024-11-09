{ config, lib, pkgs, ... }:

{
  nix = {
    # Use bleeding-edge version of nix.
    package = pkgs.nixVersions.git;

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

    # Lock systems to usertam/nix-systems.
    registry.systems = {
      from = {
        type = "indirect";
        id = "systems";
      };
      to = let
        lock = lib.importJSON ../flake.lock;
      in {
        inherit (lock.nodes.systems.locked) rev;
        type = "github";
        owner = "usertam";
        repo = "nix-systems";
      };
    };

    # Enable automatic garbage collection and optimise.
    gc.automatic = lib.mkDefault true;
    optimise.automatic = (lib.mkOverride 900) true;

    # Everyone loves experimental features!
    settings = {
      experimental-features = [
        "nix-command" "flakes"
        "auto-allocate-uids"
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        "cgroups"
      ];
      auto-allocate-uids = true;
      sandbox = lib.mkDefault true;
      max-jobs = 0;
      extra-sandbox-paths = lib.optionals pkgs.stdenv.isDarwin [
        "/private/etc/ssl/openssl.cnf"
      ];
      trusted-substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://llama-cpp.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://context-minimals.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "llama-cpp.cachix.org-1:H75X+w83wUKTIPSO1KWy9ADUrzThyGs8P5tmAbkWhQc="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "context-minimals.cachix.org-1:pYxyH24J/A04fznRlYbTTjWrn9EsfUQvccGMjfXMdj0="
      ];
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      use-cgroups = true;
    };
  };

  # Make sure nix is in system path.
  environment.systemPackages = [ config.nix.package ];
}
