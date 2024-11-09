{ lib, ... }:

{
  nix = {
    linux-builder.enable = true;
    linux-builder.ephemeral = true;
    linux-builder.config = { ... }: {
      imports = [
        ../hosts/common.nix
        ./common.nix
        ./nix-no-gc.nix
        ./nix.nix
        ./zsh.nix
      ];
      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
      ];
    };
    settings.trusted-users = lib.mkDefault [];
  };
}
