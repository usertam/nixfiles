{ inputs, config, lib, pkgs, ... }:

{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 32;
    systems = [ "aarch64-linux" "x86_64-linux" "riscv64-linux" "armv7l-linux" ];
    config = { pkgs, ... }: {
      imports = [
        ../hosts/common.nix
        ../programs/common.nix
        ../programs/nix.nix
        ../programs/nix-no-gc.nix
        ../programs/ssh-key.nix
        ../programs/zsh.nix
      ];
      virtualisation = {
        cores = 8;
        darwin-builder.memorySize = 12 * 1024;
        qemu.options = [
          "-nic vmnet-shared,model=virtio-net-pci"
        ];
      };
      boot.binfmt.emulatedSystems = [ "riscv64-linux" "armv7l-linux" "x86_64-linux" ];
      nix.settings = {
        extra-platforms = [ "x86_64-linux" "riscv64-linux" "armv7l-linux" "x86_64-linux" ];
      };
    };
  };

  # Make the stdout and stderr available.
  launchd.daemons.linux-builder.serviceConfig = {
    StandardOutPath = config.nix.linux-builder.workingDirectory + "/stdout.log";
    StandardErrorPath = config.nix.linux-builder.workingDirectory + "/stderr.log";
  };

  # Work around the "prerequisite" of linux-builder.
  nix.settings.trusted-users = lib.mkDefault [];
}
