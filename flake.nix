{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "darwin";
  };

  outputs = { self, nixpkgs, darwin, ... }@inputs: {
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
        ./hosts/azure.nix
      ];
    };

    configs.docker = self.configs.base.extendModules {
      modules = [
        ./hosts/docker.nix
      ];
    };

    # Finally, we extend the configurations with the hostname.
    nixosConfigurations = nixpkgs.lib.mapAttrs (name: config: config.extendModules {
      modules = nixpkgs.lib.singleton {
        networking.hostName = nixpkgs.lib.mkOverride 900 name;
      };
    }) self.configs;

    darwinConfigurations.gale = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };
      modules = [
        ./programs/common.nix
        ./programs/nix.nix
        ./programs/nix-no-gc.nix
        ./programs/nix-lnxbld.nix
        ./programs/zsh.nix
        ./services/tailscale.nix
        ./hosts/darwin.nix
      ];
    };
  };
}
