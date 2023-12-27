{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, agenix }: let
    specialArgs.lock = nixpkgs.lib.importJSON ./flake.lock;
  in {
    nixosConfigurations.x86_64-base = nixpkgs.lib.nixosSystem rec {
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
        ./hosts/azure-base.nix
      ];
    };

    nixosConfigurations.aarch64-base = nixpkgs.lib.nixosSystem rec {
      inherit specialArgs;
      system = "aarch64-linux";
      modules = [
        ./programs/common.nix
        ./programs/doas.nix
        ./programs/nix.nix
        ./programs/zsh.nix
        ./services/openssh.nix
        ./services/rsyncd.nix
        ./hosts/common.nix
        ./hosts/azure-base.nix
      ];
    };

    nixosConfigurations.srv01 = nixpkgs.lib.nixosSystem rec {
      inherit specialArgs;
      system = "x86_64-linux";
      modules = [
        { networking.hostName = "srv01"; }
        agenix.nixosModules.default
        ./secrets/catalog.nix
        ./programs/common.nix
        ./programs/doas.nix
        ./programs/nix.nix
        ./programs/zsh.nix
        ./services/openssh.nix
        ./services/rsyncd.nix
        ./hosts/common.nix
        ./hosts/azure-base.nix
      ];
    };

    nixosConfigurations.srv02 = nixpkgs.lib.nixosSystem rec {
      inherit specialArgs;
      system = "x86_64-linux";
      modules = [
        { networking.hostName = "srv02"; }
        agenix.nixosModules.default
        ./secrets/catalog.nix
        ./programs/common.nix
        ./programs/doas.nix
        ./programs/nix.nix
        ./programs/zsh.nix
        ./services/openssh.nix
        ./services/rsyncd.nix
        ./services/v2ray.nix
        ./hosts/common.nix
        ./hosts/azure-base.nix
      ];
    };
  };
}
