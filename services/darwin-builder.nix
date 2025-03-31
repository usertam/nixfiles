{ inputs, config, lib, pkgs, ... }:

{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 32;
    systems = [ "aarch64-linux" "x86_64-linux" ];
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
        rosetta.enable = true;
        qemu.options = [
          "-nic vmnet-shared,model=virtio-net-pci"
        ];
      };
      systemd.services."install-rosetta" = {
        description = "Install rosetta to /run/rosetta";
        before = [ "systemd-binfmt.service" ];
        wantedBy = [ "sysinit.target" ];
        serviceConfig.RemainAfterExit = true;
        serviceConfig.Type = "oneshot";
        script = ''
          install -Dm755 -t /run/rosetta \
            ${inputs.rosetta.packages.${pkgs.system}.default}/bin/*
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
