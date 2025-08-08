{ inputs, config, lib, pkgs, ... }:

{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 32;
    systems = [ "aarch64-linux" "x86_64-linux" "riscv64-linux" ];
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

      boot.binfmt.emulatedSystems = [ "riscv64-linux" ];

      boot.binfmt.registrations.rosetta = {
        interpreter = "${inputs.rosetta.packages.${pkgs.system}.default}/bin/rosetta";

        # The required flags for binfmt are documented by Apple:
        # https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta
        magicOrExtension = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'';
        mask = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
        fixBinary = true;
        matchCredentials = true;
        preserveArgvZero = false;

        # Remove the shell wrapper and call the runtime directly
        wrapInterpreterInShell = false;
      };

      nix.settings = {
        extra-platforms = [ "x86_64-linux" "riscv64-linux" ];
        extra-sandbox-paths = [
          "/run/binfmt"
          "${inputs.rosetta.packages.${pkgs.system}.default}/bin"
        ];
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
