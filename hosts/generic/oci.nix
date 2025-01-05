{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/oci-image.nix" ];

  documentation.doc.enable = false;

  # Enable zram swap.
  zramSwap.enable = true;
  zramSwap.memoryMax = 1 * 1024 * 1024 * 1024;

  # Define the release attribute be attached to root flake's packages.
  system.build.release = pkgs.runCommand "nixos-image-${config.system.nixos.label}-${pkgs.system}" {
    src = lib.overrideDerivation config.system.build.OCIImage (prev: {
      args = with lib; init prev.args ++ singleton ((last prev.args).overrideAttrs {
        # Disable virtiofsd seccomp to fix building on GitHub Actions with qemu-user.
        # Abuse checkPhase to inject replace logic.
        checkPhase = ''
          substituteInPlace $target \
            --replace-fail "bin/virtiofsd" "bin/virtiofsd --seccomp none"
        '';
      });
    });
    nativeBuildInputs = [ pkgs.pixz ];
  } ''
    mkdir -p $out
    img=$(find $src -name '*.qcow2')
    pixz -k $img $out/''${name}.qcow2.xz
  '';
}
