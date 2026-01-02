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

  # TODO: Workaround of a nix-darwin bug on auto-allocate-uids.
  # It first disables configureBuildUsers because auto-allocate-uids, which skips declaring the nixbld users/group.
  # But then it later declares knownGroups and knownUsers to include nixbld users/group.
  # What happens next is that it will try to state-manage (aka delete) the nixbld users/group, which is forbidden.
  # The proper fix will be to create users.groups.nixbld unconditional, and allow deletion of nixbld users.
  # But the hotfix for the assertions is that we just don't let nix-darwin manage/touch any users/groups.
  users.knownGroups = lib.mkForce [ ];
  users.knownUsers = lib.mkForce [ ];

  system.stateVersion = 5;
}
