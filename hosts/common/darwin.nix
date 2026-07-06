{ config, lib, pkgs, inputs, ... }:

{
  # Import common modules, for darwin.
  imports = [
    ../../programs/common.nix
    ../../programs/nix.nix
    ../../programs/shell.nix
    ../../services/openssh.nix
    ../../services/tailscale.nix
  ];

  # Override darwin-rebuild in systemPackages.
  # Also, I want coreutils in ${system-profile}/sw/bin.
  environment.systemPackages =
    let
      darwin-rebuild' = pkgs.runCommand "darwin-rebuild" {
        src = [ inputs.darwin.packages.${pkgs.stdenv.hostPlatform.system}.darwin-rebuild ];
        meta.priority = -10;
      } ''
        cp -a $src $out
        chmod +w $out/bin $out/bin/darwin-rebuild
        sed -i 's+^flake=+flake=${config.environment.darwinConfig}+' $out/bin/darwin-rebuild
      '';
    in
    [
      darwin-rebuild'
      pkgs.coreutils
    ];

  # Override default system profiles.
  environment.profiles = lib.mkForce [
    "$HOME/.nix-profile"
    "/run/current-system/sw" # was: /nix/var/nix/profiles/system/sw
    "/nix/var/nix/profiles/default"
  ];

  # Set primary user and darwin config path.
  system.primaryUser = lib.mkDefault "samu";
  environment.darwinConfig = lib.mkDefault "${config.system.primaryUserHome}/Desktop/nixfiles";

  # Set local hostname to be same as hostname.
  networking.localHostName = lib.mkDefault config.networking.hostName;

  # Disable nix garbage collection, including old outputs and derivations.
  nix.gc.automatic = false;

  # List of macOS settings.
  system.defaults = {
    dock = {
      autohide = true;
      scroll-to-open = true;
      showAppExposeGestureEnabled = true;
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      "com.apple.trackpad.scaling" = 2.0;
    };
  };

  # For Lix: auto-allocate-uids + launchd: builtin-builder inherits daemon env (no HOME),
  # build UID has no passwd entry -> getHome() aborts. A nonexistent HOME dodges the
  # passwd lookup (ENOENT is kept; an existing unowned dir would still abort).
  launchd.daemons.nix-daemon.serviceConfig.EnvironmentVariables.HOME = "/homeless-shelter";

  # HOTFIX: https://github.com/nix-darwin/nix-darwin/pull/1818
  documentation.doc.enable = false;
  system.tools.darwin-uninstaller.enable = false;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
