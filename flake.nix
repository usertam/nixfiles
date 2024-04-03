{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    systems.url = "github:nix-systems/default";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    configs.base = let
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
      sysBase = nixpkgs.lib.genAttrs (import inputs.systems) common;
      extendSysBase = base: base // {
        extendModules = args:
          extendSysBase (builtins.mapAttrs (_: v: v.extendModules args) base);
      };
    in extendSysBase sysBase;

    configs.azure = self.configs.base.extendModules {
      modules = [
        ./hosts/azure-base.nix
      ];
    };

    configs.az01 = self.configs.azure.aarch64-linux.extendModules {
      modules = [
        ./secrets/catalog.nix
        ./services/v2ray.nix
      ];
    };

    # Finally, we extend the configurations with the hostname.
    nixosConfigurations = nixpkgs.lib.mapAttrs (name: config: config.extendModules {
      modules = nixpkgs.lib.singleton {
        networking.hostName = nixpkgs.lib.mkOverride 900 name;
      };
    }) self.configs;
  };
}
