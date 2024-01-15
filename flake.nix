{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    systems.url = "github:nix-systems/default";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs: with self.nixosConfigurations; {
    nixosConfigurations.base = let
      common = system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./programs/common.nix
          ./programs/doas.nix
          ./programs/nix.nix
          ./programs/zsh.nix
          ./services/openssh.nix
          ./services/rsyncd.nix
          ./hosts/common.nix
        ];
      };
      base = nixpkgs.lib.genAttrs (import inputs.systems) common;
      mkExtend = base: base // {
        extendModules = args:
          mkExtend (builtins.mapAttrs (_: v: v.extendModules args) base);
      };
    in mkExtend base;

    nixosConfigurations.azure = base.extendModules {
      modules = [
        ./hosts/azure-base.nix
      ];
    };

    nixosConfigurations.srv01 = azure.x86_64-linux.extendModules {
      modules = [
        { networking.hostName = "srv01"; }
        ./secrets/catalog.nix
        ./services/unbound.nix
      ];
    };

    nixosConfigurations.srv02 = azure.aarch64-linux.extendModules {
      modules = [
        { networking.hostName = "srv02"; }
        ./secrets/catalog.nix
        ./services/v2ray.nix
      ];
    };
  };
}
