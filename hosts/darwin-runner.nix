{ lib, pkgs, ... }:

{
  nix.linux-builder.enable = true;
  nix.linux-builder.package = lib.makeOverridable ({ modules }: (
    pkgs.runCommand "linux-builder-with-no-hvf-for-github-actions" {
      nativeBuildInputs = [ pkgs.darwin.linux-builder ];
    } ''
      create_builder_orig="${pkgs.darwin.linux-builder.override { inherit modules; }}/bin/create-builder"
      run_nixos_vm_orig=$(grep -o '/nix/store/[a-z0-9-]*/bin/run-nixos-vm' "$create_builder_orig")
      mkdir -p $out/bin
      sed "s|,accel=hvf:tcg||g;s|smp 1|smp $(nproc)|g" "$run_nixos_vm_orig" > "$out/bin/run-nixos-vm"
      sed "s|$run_nixos_vm_orig|$out/bin/run-nixos-vm|g" "$create_builder_orig" > "$out/bin/create-builder"
      chmod +x "$out/bin/run-nixos-vm" "$out/bin/create-builder"
    ''
  ) // pkgs.darwin.linux-builder.passthru) { modules = [ ]; };

  nix.settings.trusted-users = [ "runner" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];
  nix.settings.auto-allocate-uids = true;

  services.nix-daemon.enable = true;
  system.stateVersion = 5;
}
