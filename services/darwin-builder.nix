{ lib, ... }:

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
      virtualisation.qemu.networkingOptions = [
        "-nic vmnet-shared,model=virtio-net-pci"
      ];
    };
  };

  # Don't know what this "prerequisite" hopes to achieve.
  nix.settings.trusted-users = lib.mkDefault [];
}
