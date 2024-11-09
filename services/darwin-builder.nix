{ lib, ... }:

{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 32;
    config = { ... }: {
      imports = [
        ../hosts/common.nix
        ../programs/common.nix
        ../programs/nix.nix
        ../programs/nix-no-gc.nix
        ../programs/zsh.nix
      ];
      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
      ];
      # Hack to solve conflict with xterm-kitty. Remove X-hpterm.
      environment.extraSetup = ''
        rm -rf $out/share/terminfo/x
      '';
    };
  };

  # Don't know what this "prerequisite" hopes to achieve.
  nix.settings.trusted-users = lib.mkDefault [];
}
