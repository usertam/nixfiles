{ lib, pkgs, ... }:

{
  nix.linux-builder.enable = true;
  nix.linux-builder.package = lib.makeOverridable (
    { modules }:
    let
      linux-builder' = pkgs.darwin.linux-builder.override {
        inherit modules;
      };
    in
    pkgs.runCommand "linux-builder-with-no-hvf-for-github-actions"
      {
        inherit (linux-builder') passthru;
        buildInputs = [ linux-builder' ];
      }
      ''
        createBuilder="${linux-builder'}/bin/create-builder"
        runBuilder=$(grep -o '/nix/store/[a-z0-9-]*/bin/run-builder' "$createBuilder")
        runNixosVm=$(grep -o '/nix/store/[a-z0-9-]*/bin/run-nixos-vm' "$runBuilder")

        mkdir -p $out/bin
        sed 's|,accel=hvf:tcg||g' "$runNixosVm" > "$out/bin/run-nixos-vm"
        sed "s|$runNixosVm|$out/bin/run-nixos-vm|g" "$runBuilder" > "$out/bin/run-builder"
        sed "s|$runBuilder|$out/bin/run-builder|g" "$createBuilder" > "$out/bin/create-builder"
        chmod +x $out/bin/*
      ''
  ) { modules = [ ]; };

  nix.linux-builder.config = {
    virtualisation.cores = 3;
    virtualisation.darwin-builder.memorySize = 7 * 1024;
  };

  nix.settings.trusted-users = [ "runner" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "auto-allocate-uids"
  ];
  nix.settings.auto-allocate-uids = true;

  # Override ugly, stupid default crap.
  users.knownUsers = lib.mkForce [ ];
  users.knownGroups = lib.mkForce [ "nixadm" ];

  system.stateVersion = 5;
}
