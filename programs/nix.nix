{ lib, pkgs, ... }:

{
  nix = {
    package =
      let
        src = pkgs.fetchFromGitHub {
          owner = "DeterminateSystems";
          repo = "nix-src";
          tag = "v3.15.1";
          hash = "sha256-GsC52VFF9Gi2pgP/haQyPdQoF5Qe2myk1tsPcuJZI28=";
        };
        patch = pkgs.fetchpatch {
          url = "https://github.com/usertam/nix/commit/1de8514b4949255f7d9a33f4606ed27ac0282ecc.patch";
          hash = "sha256-/d1m8ayMPBkih5cnAfM6BmV8yUFUoWtfi9ZUTwzQ8bs=";
        };
        nixComponents' = (pkgs.nixVersions.nixComponents_git.override {
          inherit src;
          version = "2.33.0";
        }).appendPatches [ patch ];
      in
      nixComponents'.nix-everything.overrideAttrs (prev: {
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
      http-connections = 0;                   # Uncap parallel TCP connections.
      max-substitution-jobs = 128;            # This is 8x the default.
      download-buffer-size = 536870912;       # 512 MiB.
      eval-cores = 0;                         # For detsys nix only; enable parallel evaluation.
      lazy-trees = true;                      # For detsys nix only.
      trusted-substituters = builtins.concatMap (x: ["${x}/" x]) [
        "https://nix-community.cachix.org"    # provide cuda and unfree-redistributable packages
        "https://cache.ztier.in"              # provide riscv64-linux packages
        "https://usertam-nixfiles.cachix.org" # provide github runner populated cache
        "https://context-minimals.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "llama-cpp.cachix.org-1:H75X+w83wUKTIPSO1KWy9ADUrzThyGs8P5tmAbkWhQc="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "context-minimals.cachix.org-1:pYxyH24J/A04fznRlYbTTjWrn9EsfUQvccGMjfXMdj0="
        "usertam-nixfiles.cachix.org-1:goXLh/oLkRJhgHRJcdD3/Yn7Dl6m0UZhfQxvTCZJqBI="
        "cache.ztier.link-1:3P5j2ZB9dNgFFFVkCQWT3mh0E+S3rIWtZvoql64UaXM="
      ];
      trusted-users = [ "root" ];
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      use-cgroups = true;
    };
  };

  # TODO: Workaround of a nix-darwin bug on auto-allocate-uids.
  # It first disables configureBuildUsers because auto-allocate-uids, which skips declaring the nixbld users/group.
  # But then it later declares knownGroups and knownUsers to include nixbld users/group.
  # What happens next is that it will try to state-manage (aka delete) the nixbld users/group, which is forbidden.
  # The proper fix will be to create users.groups.nixbld unconditional, and allow deletion of nixbld users.
  # But the hotfix for the assertions is that we just don't let nix-darwin manage/touch any users/groups.
  users = lib.optionalAttrs pkgs.stdenv.isDarwin {
    knownGroups = lib.mkForce [ ];
    knownUsers = lib.mkForce [ ];
  };
}
