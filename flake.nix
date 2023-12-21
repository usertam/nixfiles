{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
  };

  outputs = { self, nixpkgs }: let
    specialArgs.lock = nixpkgs.lib.importJSON ./flake.lock;
  in {
    nixosConfigurations.base = nixpkgs.lib.nixosSystem rec {
      inherit specialArgs;
      system = "x86_64-linux";
      modules = [
        ./programs/common.nix
        ./programs/doas.nix
        ./programs/nix.nix
        ./programs/zsh.nix
        ./services/openssh.nix
        ./services/rsyncd.nix
        ./hosts/common.nix
        ./hosts/base.nix
      ];
    };
  };
}
