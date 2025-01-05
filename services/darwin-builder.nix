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
      virtualisation = {
        cores = 8;
        darwin-builder.memorySize = 8 * 1024;
        rosetta.enable = true;
        qemu.options = [
          "-nic vmnet-shared,model=virtio-net-pci"
          "-virtfs local,path=/Library/Apple/usr/libexec/oah/RosettaLinux,security_model=passthrough,mount_tag=rosetta"
        ];
      };
      systemd.services.rosetta = {
        description = "Mount rosetta to /run/rosetta";
        before = [ "systemd-binfmt.service" "sysinit.target" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig.DefaultDependencies = false;
        unitConfig.RequiresMountsFor = [ "/nix/store" ];
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /run/rosetta
          mount -t 9p -o trans=virtio rosetta /run/rosetta
        '';
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
