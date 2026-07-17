{ config, lib, pkgs, ... }:

{
  nix = {
    # Use lix as default nix implementation.
    # Also fix a bug about dynamic users having no HOME.
    # e.g. nix::Error: error: cannot determine user's home directory
    package = pkgs.lixPackageSets.latest.lix.overrideAttrs (prev: {
      postPatch = (prev.postPatch or "") + ''
        substituteInPlace lix/libstore/build/local-derivation-goal.cc \
          --replace-fail \
            'builder = LIX_LIBEXEC_DIR "/builtin-builder";' \
            'envStrs.emplace_back("HOME=" + homeDir); builder = LIX_LIBEXEC_DIR "/builtin-builder";'
      '';
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
      accept-flake-config = false;
      extra-sandbox-paths = lib.optionals pkgs.stdenv.isDarwin [
        "/private/etc/ssl/openssl.cnf"
      ];
      http-connections = 0;                   # Uncap parallel TCP connections.
      max-substitution-jobs = 128;            # This is 8x the default.
      extra-substituters = builtins.concatMap (x: ["${x}/" x]) [
        "https://cache.usertam.dev"           # provide nixfiles cache
        "https://nix-community.cachix.org"    # provide cuda and unfree-redistributable packages
      ];
      extra-trusted-public-keys = [
        "cache.usertam.dev-1:slGg+FqFFc/qeCXyfoxBv+uuGDsUAyEbNkgwEEfw4uE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = [ "root" ];
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      use-cgroups = true;
    };

    # Keep outputs and derivations, if automatic gc is disabled.
    extraOptions = lib.optionalString (!config.nix.gc.automatic) ''
      keep-outputs = true
      keep-derivations = true
    '';
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
