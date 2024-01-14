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
      eachSystem = nixpkgs.lib.genAttrs (import inputs.systems);
      attrs = eachSystem (system: common system);
      extendModules = args: builtins.mapAttrs
        (_: v: v.extendModules args) attrs // { inherit extendModules; };
    in attrs // { inherit extendModules; };

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
