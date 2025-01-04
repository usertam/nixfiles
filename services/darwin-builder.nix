{ config, lib, ... }:

{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 32;
    config = {
      imports = [
        ../hosts/common.nix
        ../programs/common.nix
        ../programs/nix.nix
        ../programs/nix-no-gc.nix
        ../programs/ssh-key.nix
        ../programs/zsh.nix
      ];
      virtualisation.cores = 8;
      virtualisation.darwin-builder.memorySize = 8 * 1024;
      virtualisation.rosetta.enable = true;
      virtualisation.qemu.networkingOptions = [
        "-nic vmnet-shared,model=virtio-net-pci"
      ];
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
