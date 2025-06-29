{ config, lib, pkgs, ... }:

{
  nix = {
    # Use bleeding-edge version of nix, patched with what-the-hack.
    package = (pkgs.nixVersions.nixComponents_2_29.appendPatches [
      (pkgs.fetchpatch {
        url = "https://github.com/NixOS/nix/compare/master...usertam:nix:ad2869d.patch";
        hash = "sha256-nG403Ex/w3CnsNd7+c0HFDuwbe68OazvGuASFXYZZI8=";
      })
    ]).nix-everything.overrideAttrs (prev: {
      doCheck = false;
      doInstallCheck = false;
    });

    # Lock nixpkgs in registry.
    registry.nixpkgs = lib.mkForce {
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

    # Use these settings in nix.conf.
    settings = {
      experimental-features = [
        "nix-command" "flakes"
        "auto-allocate-uids"
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        "cgroups"
      ];
      auto-allocate-uids = true;
      max-jobs = "auto";
      sandbox = true;
      use-case-hack = false;
      warn-dirty = false;
      extra-sandbox-paths = lib.optionals pkgs.stdenv.isDarwin [
        "/private/etc/ssl/openssl.cnf"
      ];
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org/" # provide cuda and unfree-redistributable packages
      ];
      trusted-substituters = builtins.concatMap (x: ["${x}/" x]) [
        "https://context-minimals.cachix.org"
        "https://usertam-nixfiles.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "llama-cpp.cachix.org-1:H75X+w83wUKTIPSO1KWy9ADUrzThyGs8P5tmAbkWhQc="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "context-minimals.cachix.org-1:pYxyH24J/A04fznRlYbTTjWrn9EsfUQvccGMjfXMdj0="
        "usertam-nixfiles.cachix.org-1:goXLh/oLkRJhgHRJcdD3/Yn7Dl6m0UZhfQxvTCZJqBI="
      ];
      trusted-users = [ "root" "@nixadm" ];
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      use-cgroups = true;
    };
  };

  # Make sure nix is in system path.
  environment.systemPackages = [ config.nix.package ];

  # Add a user group for trusted-users.
  # $ sudo -g nixadm -s
  users.groups."nixadm".gid = 351;
}
